# Результаты проверки — 05.11.2026

Среда: Windows, PowerShell, Node.js 24; bundled Python 3.12. Swift compiler, Apple SDK, Xcode и подключённый macOS CI в этой сессии отсутствуют.

Выполнено успешно:

- `node CI/validate.cjs`: структура, JSON ресурсов, три systemSmall configurations, container backgrounds, проверка на заглушки и секреты, размеры demo PNG.
- `node --check CI/generate-assets.cjs` и `node --check CI/validate.cjs`: синтаксис Node-скриптов.
- `py_compile` трёх Python-скриптов; Pillow verify для шести PNG, размер и отсутствие alpha у AppIcon.
- `CI/parse-sources.py`: грамматика **25 Swift-файлов** через tree-sitter-swift; разбор project.yml, codemagic.yaml, GitHub workflow, plist/entitlements и AASA; существование source paths XcodeGen.
- Генерация трёх demo PNG 480×480 и непрозрачной иконки приложения 1024×1024.
- Ручной просмотр кода, в том числе PKCE/state, token refresh, ограничения команд и файловый доступ; сверка официальных источников Spotify/Apple/Codemagic.
- В исходном HTML официальной таблицы capabilities проверены отметки: App Groups и Keychain Sharing доступны также бесплатному Apple Developer; Associated Domains — только ADP/ADEP.

В проекте **35 XCTest-методов**. Их исходники созданы; они **не выполнялись** на Windows. Отсутствие ошибок грамматического парсера не проверяет типы Swift, AppIntent metadata extraction, SwiftUI generic inference, linking, signing, SDK availability или runtime.

Не выполнено:

- генерация проекта реальным XcodeGen на macOS и `xcodebuild`;
- simulator XCTest / previews / проверка в CarPlay Simulator;
- сборка и подпись IPA, загрузка в App Store Connect;
- реальная Spotify OAuth/API с аккаунтом пользователя;
- установка на iPhone 15 Pro и проверка сенсорного CarPlay;
- проверка бесплатной альтернативной переподписи с сохранением Widget Extension.

Причина: отсутствуют GitHub remote, подключённый Codemagic, macOS runner, пользовательский Client ID/HTTPS host и signing assets. Для следующего шага выполните Documentation/BUILD-WINDOWS.md и сначала запустите simulator-tests. До успешного xcodebuild проект нельзя объявлять скомпилированным, а unsigned IPA — устанавливаемым.
