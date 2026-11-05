# Spotify CarWidget / CarWidget

Нативное iOS 26+ приложение на SwiftUI с тремя отдельными WidgetKit-виджетами: **Compact**, **Controls**, **Cover Focus**. Каждый поддерживает `systemSmall` для iPhone, StandBy и CarPlay; Controls также имеет `systemMedium` для iPhone. В приложении: проигрыватель, галерея, настройки темы, диагностика и автономное демо.

**Статус:** исходники и конфигурации созданы на Windows. Настоящая сборка Xcode и XCTest здесь не запускались; работоспособность бинарного файла ещё должна подтвердить macOS CI. Нет опубликованного IPA и результата проверки на автомобиле. Не считайте локальную статическую проверку подтверждением компиляции.

## Начать с Windows

1. Установите Git и Node.js 22+; Xcode на Windows не требуется.
2. В PowerShell в этой папке выполните `node CI/validate.cjs` или `./CI/validate.ps1`.
3. Создайте репозиторий GitHub и загрузите файлы по [инструкции сборки](Documentation/BUILD-WINDOWS.md).
4. В Codemagic выберите workflow `simulator-tests`. Он создаёт `.xcodeproj` через XcodeGen, запускает XCTest на iOS Simulator и проверяет Personal-конфигурацию.
5. Для автономной device-сборки выберите `unsigned-device`. Полученный файл **UNSIGNED-requires-signing.ipa не устанавливается без дополнительной подписи**.
6. Для настоящего Spotify настройте [OAuth и подпись](Documentation/SPOTIFY-SETUP.md), затем `signed-device` и [установку на iPhone](Documentation/INSTALL-IPHONE.md).

Полноценные синхронизированные Spotify-виджеты требуют доступных App Groups, общего Keychain и Associated Domains. По актуальной таблице Apple App Groups и Keychain Sharing доступны также бесплатному Apple Developer, **Associated Domains — нет**. В поставляемом полном пути нужны Apple Developer Program и соответствующие profiles обоих targets именно из-за HTTPS OAuth и подписи. Предусмотрен отдельный `Personal` **только демо** без дополнительных entitlements для максимально переносимой переподписи: приложение и расширение имеют независимые локальные состояния. Три виджета внутри одного расширения делят его локальное состояние. Бесплатная установка полного Spotify-варианта с Windows без Mac не подтверждена. [Таблица Apple](https://developer.apple.com/help/account/reference/supported-capabilities-ios/).

## Что реализовано

- Authorization Code + PKCE S256: случайные verifier/state, проверка точного HTTPS callback, ASWebAuthenticationSession, без client secret.
- Access/refresh tokens только в Keychain (`AfterFirstUnlockThisDeviceOnly`), обновление и повтор одного API-запроса после 401, выход с очисткой данных.
- GET playback, PUT play/pause, POST next/previous; обработка 204, 401, 403, 404, 429, недоступного устройства и запрещённых команд.
- Нормализованный `PlaybackSnapshot`, атомарный JSON-кеш, общий App Group, межпроцессная блокировка, объединение одновременных refresh.
- Ограниченные повторы GET с exponential backoff, сохранение Retry-After; команды переключения не повторяются автоматически после сетевых/5xx ошибок.
- Обложки до 480 px, потоковая загрузка до 4 MB, файловый кеш до 12 MB / 40 изображений.
- App Intents для кнопок, корректные container backgrounds, адаптация к удалённому фону CarPlay, VoiceOver labels, статическая декоративная волна.
- Демо без Client ID и интернета: вымышленные обложки, переключение, пауза, прогресс, длинный текст, отсутствие обложки/воспроизведения и ошибка.
- XCTest с mock networking, previews, Codemagic и дополнительный GitHub Actions workflow.

## Структура

```text
App/                 SwiftUI entry point
Features/            MVVM, проигрыватель, галерея, настройки
Authentication/      PKCE, ASWebAuthenticationSession, Keychain
SpotifyAPI/          URLSession transport, HTTP errors/retries, token refresh
Playback/            единый SpotifyPlaybackService и DemoLibrary
Models/              PlaybackSnapshot и DTO Spotify
Storage/             App Group, flock, атомарные файлы, кеш обложек
Services/            конфигурация и граница Personal demo
Widgets/             WidgetBundle, TimelineProvider, три дизайна
AppIntents/          toggle / previous / next
Assets/              оригинальные демо-обложки, app icon, атрибуция Spotify
Config/              xcconfig, Info.plist, entitlements
Tests/               XCTest
CI/                  проверки, генерация ресурсов и облачная сборка
Documentation/       настройка, ограничения, установка, тестирование
```

`project.yml` — исходное определение проекта. Сгенерированный `.xcodeproj` не хранится в Git. Зависимостей Swift Package / CocoaPods нет. XcodeGen нужен только на macOS во время генерации проекта.

## Важные ограничения

Приложение управляет **существующим активным устройством Spotify** через Web API; оно не передаёт аудио и не превращает Widget Extension в аудиоплеер. Сначала начните воспроизведение в Spotify. Отдельное CarPlay-приложение и CarPlay entitlement не заявлены.

WidgetKit сам выбирает фактическое время обновлений. Запрос новой timeline — примерно через 15 минут или позже при 429. Возврат в приложение, явное обновление и команда вызывают reload. Непрерывное отслеживание смены песен при закрытом приложении не обещается. Прогресс реального трека — последнее подтверждённое значение, демо-прогресс имитируется только локально. Иконка часов обозначает устаревший снимок.

Проверка документации выполнена **5 ноября 2026 года**. [Подтверждённые ограничения и источники](Documentation/LIMITATIONS.md), [архитектура](Documentation/ARCHITECTURE.md), [проверки](Documentation/TESTING.md).

Для реального контента Cover Focus сохраняет обложку целиком, а подписи размещает отдельно: Spotify запрещает перекрывать обложку градиентом или текстом. Полный художественный вариант с наложением доступен для вымышленных демо-обложек. В Spotify Dashboard используйте имя **CarWidget** или **CarWidget for Spotify**, а не название, подразумевающее принадлежность Spotify. [Правила оформления](https://developer.spotify.com/documentation/design).
