import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: PlaybackViewModel
    var body: some View {
        TabView {
            Tab("Главная", systemImage: "play.square") { NavigationStack { PlayerScreen() } }
            Tab("Мои виджеты", systemImage: "square.grid.2x2") { NavigationStack { WidgetGalleryScreen() } }
            Tab("Настройки", systemImage: "slider.horizontal.3") { NavigationStack { SettingsScreen() } }
        }
        .alert("Spotify CarWidget", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("Понятно", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

struct PlayerScreen: View {
    @EnvironmentObject private var model: PlaybackViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    if !model.demo { SpotifyBadge(demo: false) }
                    Label(model.demo ? "Демонстрация" : model.loggedIn ? "Spotify подключён" : "Нет авторизации",
                          systemImage: model.demo ? "sparkles" : "checkmark.shield")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if model.busy { ProgressView() }
                }
                AlbumArtwork(snapshot: model.snapshot).frame(maxWidth: 330)
                    .shadow(color: .black.opacity(0.15), radius: 25, y: 12)
                VStack(spacing: 7) {
                    Text(model.snapshot.title).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(model.snapshot.artist).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if !model.demo, let url = model.snapshot.spotifyURL {
                        Link("Открыть в Spotify", destination: url).font(.caption)
                    }
                }
                TimelineView(.periodic(from: .now, by: model.demo && model.snapshot.isPlaying ? 1 : 60)) { context in
                    VStack(spacing: 6) {
                        ProgressView(value: Double(model.snapshot.progress(at: context.date)), total: Double(max(1, model.snapshot.durationMS)))
                        HStack {
                            Text(ControlsCard.time(model.snapshot.progress(at: context.date)))
                            Spacer()
                            Text(model.demo ? "Демо-прогресс" : "Последнее известное значение")
                            Spacer()
                            Text(ControlsCard.time(model.snapshot.durationMS))
                        }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 32) {
                    control("backward.end.fill", command: .previous, label: "Предыдущий")
                    control(model.snapshot.isPlaying ? "pause.fill" : "play.fill", command: .toggle, label: "Воспроизведение / пауза", prominent: true)
                    control("forward.end.fill", command: .next, label: "Следующий")
                }
                VStack(spacing: 8) {
                    Label(model.snapshot.status.title, systemImage: model.snapshot.status == .ready ? "antenna.radiowaves.left.and.right" : "info.circle")
                        .font(.subheadline)
                    if let message = model.snapshot.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                    if model.snapshot.observedAt != .distantPast {
                        Text("Обновлено: \(model.snapshot.observedAt.formatted(date: .omitted, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.multilineTextAlignment(.center)
                Button { model.refresh() } label: { Label("Обновить состояние", systemImage: "arrow.clockwise") }
                    .buttonStyle(.glass).disabled(model.busy)
                if !model.loggedIn && !model.demo {
                    Button("Войти в Spotify") { model.login() }.buttonStyle(.glassProminent)
                        .disabled(!AppConfiguration.current.canAuthenticate)
                }
            }.padding(24)
        }
        .navigationTitle("В пути")
        .background(LinearGradient(colors: [.green.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
        .refreshable { model.refresh() }
    }
    private func control(_ symbol: String, command: PlaybackCommand, label: String, prominent: Bool = false) -> some View {
        Button { model.command(command) } label: {
            Image(systemName: symbol).font(.system(size: prominent ? 28 : 22, weight: .semibold))
                .frame(width: prominent ? 76 : 48, height: prominent ? 76 : 48)
                .background(prominent ? Color.green.opacity(0.15) : .clear, in: Circle())
        }.buttonStyle(.plain).disabled(model.busy || !model.snapshot.permits(command)).accessibilityLabel(label)
    }
}

struct WidgetGalleryScreen: View {
    @EnvironmentObject private var model: PlaybackViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Три способа видеть музыку").font(.title2.bold())
                Text("Превью используют вымышленный трек. Реальные виджеты берут общее состояние из приложения.")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 14) {
                    sample("Compact") { CompactCard(snapshot: DemoLibrary.snapshot(index: 0)) }
                    sample("Controls") { ControlsCard(snapshot: DemoLibrary.snapshot(index: 1)) }
                }
                sample("Cover Focus") { CoverFocusCard(snapshot: DemoLibrary.snapshot(index: 2)) }
                VStack(alignment: .leading, spacing: 12) {
                    Label("В автомобиле", systemImage: "car.side").font(.headline)
                    Text("На iPhone откройте Настройки → Основные → CarPlay → ваш автомобиль → Виджеты. Добавьте Compact, Controls или Cover Focus.")
                    Text("Нужны iOS 26+ и подключённый CarPlay. Управление доступно на сенсорных экранах. Частоту обновления определяет iOS.")
                    Text("На iPhone: удерживайте домашний экран → Изменить → Добавить виджет → CarWidget. Для StandBy добавьте виджет в стопку режима ожидания.")
                }.font(.subheadline).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                Button("Попробовать интерактивное демо") { model.setDemo(true) }.buttonStyle(.glassProminent)
            }.padding()
        }.navigationTitle("Мои виджеты")
    }
    private func sample<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content().padding(12).frame(width: 152, height: 164)
                .background(Color(red: 0.055, green: 0.065, blue: 0.08), in: RoundedRectangle(cornerRadius: 22))
                .environment(\.colorScheme, .dark).allowsHitTesting(false).accessibilityElement(children: .combine)
            Text(title).font(.subheadline.weight(.semibold))
        }
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var model: PlaybackViewModel
    @AppStorage("appearance") private var appearance = "system"
    @State private var scenario: DemoScenario = .normal
    var body: some View {
        Form {
            Section("Spotify") {
                LabeledContent("Авторизация", value: model.loggedIn ? "Выполнена" : "Нет")
                if model.loggedIn { Button("Выйти и удалить локальные данные", role: .destructive) { model.logout() } }
                else { Button("Войти в Spotify") { model.login() }.disabled(!AppConfiguration.current.canAuthenticate || model.busy) }
                if !AppConfiguration.current.canAuthenticate {
                    Text(AppConfiguration.personalDemo ? "Personal: только автономное демо, хранилища приложения и расширения независимы." : "Для входа настройте Client ID и свой HTTPS callback в Config/Local.xcconfig, затем пересоберите приложение.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Оформление") {
                Picker("Тема", selection: $appearance) {
                    Text("Системная").tag("system"); Text("Светлая").tag("light"); Text("Тёмная").tag("dark")
                }
            }
            if AppConfiguration.personalSpotify {
                Section("Связь с виджетами") {
                    Text("Сборка Spotify Personal использует общий Keychain. Доступ зависит от фактической подписи приложения и расширения.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Проверить общий доступ") { model.checkWidgetConnection() }.disabled(model.busy)
                    Button("Показать результат проверки") { model.refreshWidgetConnection() }
                    Text(model.widgetConnection).font(.caption)
                    Text("Добавьте любой виджет CarWidget на домашний экран, нажмите проверку и вернитесь к виджету. После его обновления откройте здесь результат.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Демонстрация") {
                Toggle("Демо без интернета", isOn: Binding(get: { model.demo }, set: { model.setDemo($0) }))
                    .disabled(AppConfiguration.personalDemo || model.busy)
                if model.demo {
                    Picker("Сценарий", selection: $scenario) { ForEach(DemoScenario.allCases) { Text($0.rawValue).tag($0) } }
                        .onChange(of: scenario) { _, value in model.setDemo(true, scenario: value) }
                    Text("Все треки и обложки вымышлены. Управление не обращается к Spotify.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Обновление и диагностика") {
                Button("Проверить соединение и обновить виджеты") { model.refresh() }.disabled(model.busy)
                LabeledContent("Источник", value: model.snapshot.source.rawValue)
                LabeledContent("Состояние", value: model.snapshot.status.title)
                LabeledContent("Активное устройство", value: model.snapshot.deviceActive ? "Да" : "Нет")
                if let until = model.snapshot.retryAfter { LabeledContent("Повтор не ранее", value: until.formatted()) }
                if let message = model.snapshot.message { Text(message).font(.caption) }
                Text("WidgetKit распределяет бюджет обновлений. Приложение обновляет состояние при открытии, по кнопке и после команды. Постоянного фонового опроса нет.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("О приложении") {
                LabeledContent("Версия", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                Text("Личный неофициальный проект. Не является приложением Spotify. Аудио воспроизводит Spotify на активном устройстве.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Настройки")
    }
}
