# Результаты проверки — 05.11.2026

Разработка: Windows, PowerShell, Node.js 24, bundled Python 3.12. Сборка: стандартный macOS-раннер GitHub Actions в публичном репозитории.

## Подтверждённая сборка и запуск

[Workflow 42077207345](https://github.com/tomilenko95/SpotifyCarWidget/actions/runs/42077207345) для исходного commit `84005be` завершился **success** 05.11.2026.

- XcodeGen сгенерировал настоящий Xcode project.
- `xcodebuild test`: **35 тестов, 0 failures**, `TEST SUCCEEDED`.
- Сборка Personal для iPhone Simulator: `BUILD SUCCEEDED`.
- `simctl install` и `simctl launch`: приложение установлено и запущено в симуляторе.
- Снимок `CarWidget-iPhone-Simulator.png` просмотрен: главный экран, демо-обложка, метаданные, прогресс и кнопки отображаются.
- Device-сборка Personal: `BUILD SUCCEEDED`; создан `UNSIGNED-requires-signing.ipa`.
- IPA проверен через zip/plist: платформа `iphoneos`, minimum iOS 26.0, приложение `com.example.SpotifyCarWidget`, вложенное расширение `com.example.SpotifyCarWidget.widgets`, extension point `com.apple.widgetkit-extension`.

Artifacts: `Tests.xcresult`, `Simulator.app.zip`, `CarWidget-iPhone-Simulator.png`, `UNSIGNED-requires-signing.ipa`. GitHub хранит их 3 дня по настройке workflow; для дальнейшего использования скачайте локально или повторите сборку.

Это подтверждает компиляцию и запуск демо в симуляторе. IPA пока **не подписан**; установленным на физический iPhone его считать нельзя.

## Локальные проверки Windows

Выполнено успешно:

- `node CI/validate.cjs`: структура, JSON ресурсов, три systemSmall configurations, container backgrounds, проверка на заглушки и секреты, размеры demo PNG.
- `node --check CI/generate-assets.cjs` и `node --check CI/validate.cjs`: синтаксис Node-скриптов.
- `py_compile` трёх Python-скриптов; Pillow verify для шести PNG, размер и отсутствие alpha у AppIcon.
- `CI/parse-sources.py`: грамматика **25 Swift-файлов** через tree-sitter-swift; разбор project.yml, codemagic.yaml, GitHub workflow, plist/entitlements и AASA; существование source paths XcodeGen.
- Генерация трёх demo PNG 480×480 и непрозрачной иконки приложения 1024×1024.
- Ручной просмотр кода, в том числе PKCE/state, token refresh, ограничения команд и файловый доступ; сверка официальных источников Spotify/Apple/Codemagic.
- В исходном HTML официальной таблицы capabilities проверены отметки: App Groups и Keychain Sharing доступны также бесплатному Apple Developer; Associated Domains — только ADP/ADEP.

В проекте **35 XCTest-методов**. Они выполнены на macOS CI, а не на Windows. Грамматический парсер использовался только как предварительная проверка; результат Xcode и XCTest подтверждён отдельно.

Не выполнено:

- интерактивная проверка всех Xcode previews и CarPlay Simulator;
- подпись IPA, загрузка в App Store Connect;
- реальная Spotify OAuth/API с аккаунтом пользователя;
- установка на iPhone 15 Pro и проверка сенсорного CarPlay;
- проверка бесплатной альтернативной переподписи с сохранением Widget Extension.

GitHub подключён и cloud build работает. Сейчас готовится бесплатная установка Personal demo через Sideloadly на Windows; компоненты iTunes, Apple Mobile Device Support и iCloud установлены. Фактическое обнаружение iPhone в Sideloadly, подпись и запуск на телефоне пока не подтверждены. Для Full Spotify-варианта по-прежнему нужны пользовательский Client ID, HTTPS host и соответствующие capabilities подписи.
