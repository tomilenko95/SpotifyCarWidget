# Проверка проекта

## Что можно запустить на Windows

`node CI/validate.cjs` проверяет наличие основных конфигураций, JSON каталога ресурсов, три systemSmall configurations, containerBackground, отсутствие заглушек/client secret в Swift, ожидаемые размеры offline обложек. Это **не** компилятор Swift, не unit tests и не визуальная проверка iOS.

`CI/generate-assets.cjs` воспроизводимо создаёт только оригинальные обложки и иконку приложения. Он не меняет сторонний значок Spotify. При изменении генератора повторите запуск и сравните PNG.

Дополнительно можно установить Python 3.12+ и временные validation-пакеты: `python -m pip install --target build/validation --only-binary=:all: -r CI/validation-requirements.txt`, затем `python CI/parse-sources.py`. Это парсер грамматики Swift и конфигураций, не type checker. Пакеты находятся в игнорируемой build-папке и не входят в iOS-приложение.

## XCTest на macOS CI

`bash CI/test.sh` генерирует проект и запускает XCTest на установленном iPhone Simulator iOS 26+, затем отдельно собирает Personal. `.xcresult` сохраняется в artifacts.

Проверяются:

- RFC 7636 S256 challenge, безопасный verifier, state, mismatch origin/path/scheme, duplicate state, denied callback, form encoding и OAuth exchange;
- refresh до истечения срока, 401 с одним повтором, остановка повторного 401, сохранение/ротация refresh token;
- декодирование playback без deprecated полей, null item, неподдерживаемый episode, inactive device, 204, 403, 404;
- 429 и Retry-After seconds/HTTP-date, ограниченные 5xx GET retries, отсутствие повторного next при 5xx, методы PUT play/pause;
- roundtrip PlaybackSnapshot, неизменный real progress, clamped demo progress;
- демо-команды без сетевого запроса, выполнение всех трёх App Intents с внедрённым сервисом;
- общий store двух service instances, dedup одновременных refresh, сохранение 429 cooldown, logout;
- одна timeline entry и расчёт следующего refresh с длинным Retry-After;
- отказ cache path traversal.

MockTransport передаётся через HTTPClient. Тесты не обращаются к Spotify и не требуют Client ID. MemoryTokens заменяет Keychain. Временные хранилища изолированы и удаляются тестом. Реальные capabilities профиля и Spotify доступность mock tests подтвердить не могут.

## Previews и ручные сценарии

В Xcode откройте каждый Widget source: #Preview для Compact small, Controls small/medium, Cover Focus small, длинных названий, отсутствующей обложки и ошибок. В Shared/WidgetCards.swift есть previews тем. Настройте canvas для fullColor и vibrant/StandBy, проверки контраста после удаления фона. Для отдельного host app есть галерея и переключение system/light/dark.

| Сценарий | Ожидается |
|---|---|
| Первый запуск без ID и сети | рабочее демо, три preview, play/pause и next/previous |
| Длинное название / крупный шрифт | максимум две строки названия, controls доступны, нет выхода за края |
| Missing artwork | нейтральный fallback, без сетевого ожидания в widget view |
| Нет playback / 204 | понятное состояние, controls disabled |
| Нет активного Spotify устройства | инструкция открыть Spotify, нет попытки переноса на случайное устройство |
| Denied OAuth / неверный state | вход не выполняется, повтор начинается с новым state/verifier |
| Истёкший access token | один refresh и повтор API; при невосстановимом grant новый вход |
| 403 | диагностика Premium/allowlist/scopes, отсутствие цикла запросов |
| 429 | дата retry сохранена, другой widget не делает немедленный повтор |
| Background → foreground | повторное обновление и reload WidgetKit без бесконечного polling |
| Команда из реального виджета | свежий GET, одна команда, одно follow-up чтение; проверить с закрытым app |
| Command timeout | нет автоматического второго next/previous; сверить состояние вручную |
| Logout | tokens и cached artwork удалены, widgets переходят в signed-out после reload |
| Demo → Spotify → Demo | источники не смешиваются, demo не управляет Spotify |
| Lock после первого unlock | чтение cache и допустимые intents; проверить на iPhone |
| Reboot до unlock | ограниченный доступ, нет обхода защиты данных |
| Personal app vs widgets | независимое демо, shared Spotify не заявлен |

На macOS установите CarPlay Simulator из Apple Developer tools и добавьте виджеты. Затем повторите на iPhone 15 Pro с реальным сенсорным CarPlay, припарковав автомобиль. Проверьте все три выбора отдельно, фон/ночной режим, короткие и длинные названия, нажатия и недоступную сеть. Устройство с несенсорным экраном должно оставаться полезным в информационном режиме.

## Отчёт текущей сессии

См. `VALIDATION.md`: в нём перечислены фактически выполненные проверки. Успешный CI build, device test или OAuth login нельзя считать выполненными до появления соответствующего результата. При первой облачной сборке сохраняйте xcodebuild output и `.xcresult`; исправляйте ошибки сборки до выдачи IPA пользователю.
