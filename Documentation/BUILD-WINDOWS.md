# Сборка из Windows через macOS CI

## GitHub

Создайте пустой репозиторий в своём аккаунте GitHub. В текущей папке Git пока не инициализирован; ниже команды, которые нужно выполнить после создания remote. Перед коммитом убедитесь, что `Config/Local.xcconfig`, сертификаты и profiles не включены. Код не содержит Client Secret.

```powershell
git init -b main
git add .
git commit -m "Create native CarWidget app and WidgetKit extension"
git remote add origin https://github.com/YOUR_ACCOUNT/SpotifyCarWidget.git
git push -u origin main
```

Репозиторий не был создан или опубликован автоматически: в сессии нет настроенного remote и доступа к вашему CI. Все дальнейшие сборки запускаются после подключения аккаунта.

Дополнительный `.github/workflows/ios.yml` запускает unsigned simulator tests на `macos-26`. Для public repositories стандартные GitHub-hosted runners могут использоваться бесплатно в рамках действующих условий; для private расходуется квота аккаунта. Проверьте [условия раннеров](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). Codemagic остаётся основным маршрутом ниже.

Для выбранного полностью бесплатного маршрута используйте GitHub Actions → **Build CarWidget** → **Run workflow**. Параметр `device_ipa` включён по умолчанию: после XCTest и сборки симулятора будет создан также unsigned Personal demo IPA для iPhone. В artifacts `ios-results` попадут `.xcresult`, `Simulator.app.zip` и `UNSIGNED-requires-signing.ipa`; срок хранения — 3 дня. Повторный запуск той же ветки отменяет предыдущий. В целях соблюдения бесплатного маршрута workflow программно пропускает macOS job в закрытом репозитории. Codemagic для этого варианта не нужен.

После сборки Personal приложение также устанавливается и запускается в iPhone Simulator. Снимок `CarWidget-iPhone-Simulator.png` сохраняется в artifacts. Успешная команда запуска и снимок — проверка запуска на симуляторе; они не подтверждают установку на физический iPhone или работу CarPlay.

## Codemagic: первый запуск

1. Войдите на [Codemagic](https://codemagic.io/), подключите GitHub и разрешите доступ к нужному репозиторию.
2. Add application → ваш repository → проект с YAML-конфигурацией. Файл `codemagic.yaml` лежит в корне.
3. Выберите branch `main`, workflow **simulator-tests**, Start new build.
4. Нужен Xcode с SDK iOS 26+ и установленным iOS 26+ Simulator runtime. YAML использует `xcode: latest`; если образ меняется, выберите доступную совместимую версию в Codemagic. Скрипт выбирает первый доступный iPhone runtime версии 26 или выше. Минимальная версия приложения — 26.0, Swift language mode — 5.
5. В логе сначала должны пройти static checks, затем генерация XcodeGen, затем `xcodebuild test`, затем сборка конфигурации Personal. Ошибка любого шага останавливает workflow.
6. На странице завершённой сборки скачайте **Artifacts**: `Simulator.app.zip` и `Tests.xcresult`. Результат тестов доступен после выполнения, не заранее. `.xcresult` удобно просматривать на macOS; логи ошибок доступны и в браузере Windows.

Проверьте текущие лимиты бесплатного плана в своём аккаунте Codemagic. Конфигурация не гарантирует бесплатные macOS-минуты, не включает платные задачи по расписанию и не публикует приложение в App Store.

## Типы результатов

| Результат | Для чего | Установка на iPhone |
|---|---|---|
| `Simulator.app.zip` | бинарный bundle под iOS Simulator на Mac | нет, это другой SDK/платформа даже при ARM64 |
| `UNSIGNED-requires-signing.ipa` | ARM64 device bundle, упакованный как Payload | нет, сначала подпись приложения **и** `.appex` |
| Signed development IPA | зарегистрированные устройства и development profiles | да при выполнении требований подписи и Developer Mode |
| Signed Ad Hoc IPA | зарегистрированные UDID и Ad Hoc profiles | да, только устройства, включённые в profiles |
| App Store IPA | загрузка в App Store Connect/TestFlight | не произвольная USB-установка; распространение через Apple |

Workflow **unsigned-device** собирает **Personal demo**; переменная `PERSONAL_DEMO=1`. В расширении три настоящих виджета, но без обмена данными с приложением. Для unsigned полной версии измените эту переменную на `0`; это не предоставит нужные entitlements при последующей бесплатной переподписи.

## Signed Ad Hoc без собственного Mac

Нужны Apple Developer Program, зарегистрированный iPhone UDID, основной App ID (`com.yourname.SpotifyCarWidget`), extension App ID (`com.yourname.SpotifyCarWidget.widgets`), App Group и действующие права на общий Keychain. Для основного App ID включите Associated Domains. Для каждого App ID подготовьте **свой** Ad Hoc provisioning profile, разрешающий App Group и нужную keychain group. Профили должны соответствовать одному distribution certificate и включать iPhone.

Сертификат с private key и profiles можно подготовить через Developer Portal / App Store Connect API и средства Codemagic в рамках платного membership. Personal Team не предоставляет этот облачный distribution-процесс. Подробности получения сертификата без Mac зависят от доступных функций аккаунта; в Codemagic есть создание сертификатов через API key. Не используйте чужие сертификаты или сервисы, предлагающие обход capabilities.

В Codemagic Team settings → Code signing identities загрузите/получите:

- certificate reference **carwidget_distribution** (Apple Distribution с private key);
- provisioning profile reference **carwidget_app_adhoc**;
- provisioning profile reference **carwidget_widgets_adhoc**.

Reference names должны точно совпасть с YAML. `.p12`, пароль, `.p8` и profiles храните в хранилище Codemagic, не в репозитории. App Store Connect API key, если нужен для создания signing assets, также хранится в настройках интеграции.

Создайте environment group **spotify_public_config** с переменными:

```text
APP_BUNDLE_ID=com.yourname.SpotifyCarWidget
APP_GROUP=group.com.yourname.SpotifyCarWidget
OAUTH_HOST=login.your-domain.com
SPOTIFY_CLIENT_ID=<32 символа Client ID>
DEVELOPMENT_TEAM=<ваш Team ID>
```

Это публичные идентификаторы, не токены Spotify. Скрипт `CI/configure.py` создаёт исключённый из Git Local.xcconfig. `KEYCHAIN_GROUP` вычисляется автоматически с `AppIdentifierPrefix`.

Запустите **signed-device**. Скрипт импортирует сертификаты, назначает profiles обоим targets через `xcode-project use-profiles`, архивирует и экспортирует IPA. Результаты — `build/ipa/*.ipa`, `.xcarchive` и логи. Если profile не разрешает фактические entitlements, исправьте profile, а не удаляйте entitlements из полной конфигурации. [Инструкция Codemagic](https://docs.codemagic.io/yaml-code-signing/signing-ios/), [CLI](https://docs.codemagic.io/knowledge-codemagic/codemagic-cli-tools/).

Для TestFlight нужен отдельный App Store distribution profile каждого target и изменение signing references; загрузка здесь не автоматизирована намеренно. Сначала добейтесь прохождения simulator tests и Ad Hoc на своём iPhone.

## Если временно доступен Mac

```bash
brew install xcodegen
xcodegen generate
open SpotifyCarWidget.xcodeproj
# Либо полная проверка:
bash CI/test.sh
```

Для бесплатного Xcode provisioning выбирайте схему `SpotifyCarWidgetPersonal`, конфигурацию `Personal`, свою Personal Team. Эта переносимая конфигурация намеренно не включает Spotify OAuth и общие хранилища; это выбор проекта, а не утверждение о запрете App Groups для всех бесплатных профилей. Для полной версии с Associated Domains — схема `SpotifyCarWidget` с корректной Developer Program подписью. Не запускайте Xcode на Windows.
