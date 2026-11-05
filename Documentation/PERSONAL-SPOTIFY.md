# Spotify Personal: проверка бесплатного подключения

## Подтверждено и что ещё проверяется

05.11.2026 в Spotify Dashboard пользователя создано приложение CarWidget в Development Mode. Зарегистрированный `com.tomilenko95.carwidget://spotify/callback` сохранён в карточке приложения. Это фактическая проверка конкретного redirect URI, а не предположение, что Spotify примет любую custom scheme. Client ID публичен и включён в `Config/PersonalSpotify.xcconfig`; Client Secret не используется.

[Официальный Spotify iOS Auth](https://github.com/spotify/ios-auth#setup) описывает custom schemes как вариант B, при этом общая страница Web API Redirect URI формулирует требования через HTTPS и loopback. Поэтому этот режим включён только для подтверждённого адреса. На телефоне ещё необходимо проверить выдачу grant, обмен code + PKCE и реальные player endpoints. HTTPS-конфигурация исходного Full-варианта сохранена.

## Отличие от Personal demo

`Personal` остаётся автономным демо без дополнительных entitlements. Новая конфигурация **PersonalSpotify** разрешает настоящий PKCE-вход через ASWebAuthenticationSession с зарегистрированным callback scheme. Её нельзя считать полноценно проверенной до входа пользователя и проверки общего Keychain на физическом iPhone.

App Groups в этом варианте не нужны. Токены и небольшой JSON состояния хранятся в общей Keychain access group `<AppIdentifierPrefix>.com.carwidget.shared`, одинаковой у app и extension. Обложки остаются в ограниченных локальных кешах каждого процесса и при необходимости догружаются отдельно. Никаких tokens в UserDefaults или публичном backend нет.

Фактический signing prefix определяется через Keychain Services из группы собственного probe-item, который сразу удаляется. Prefix не угадывается по bundle ID, потому что Sideloadly может изменить bundle IDs. Ошибка общего доступа показывается пользователю, а не заменяется скрытым отдельным приватным хранилищем.

Apple описывает профили как allowlist entitlements. Если profile разрешает `PREFIX.*` для Keychain, конкретная группа с этим prefix может быть заявлена в подписи обоих targets. См. [TN3125](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles). Наличие такой возможности в документации не подтверждает, что конкретная переподпись Sideloadly сохранит группу: это проверяется на устройстве.

## Сборка и переподпись

GitHub Actions → Build CarWidget → Run workflow:

- `device_ipa`: true;
- `personal_spotify`: true;
- `keychain_team_id`: 10-символьный публичный AppIdentifierPrefix выбранного Apple profile. Это **не пароль, token или private key**.

Перед упаковкой CI добавляет в app и extension локальную ad-hoc code signature с конкретной общей Keychain group. Это лишь способ сохранить entitlements для последующей переподписи. **Это не Apple Ad Hoc distribution и не устанавливаемая подпись.** IPA по-прежнему требует подписи Sideloadly с пользовательским Apple Account / provisioning profile.

Не удаляйте вложенный `.appex`: должно быть **Dropping 0 of 1 plug-ins**. После установки откройте приложение → Настройки → Связь с виджетами → Проверить общий доступ. Добавьте любой CarWidget на домашний экран, дождитесь его обновления и вернитесь к результату проверки. Успешный ответ extension доказывает доступ обоих процессов к одному item; один лишь успешный вход в app этого не доказывает.

Если появится ошибка доступа Keychain, сначала проверьте entitlements реально переподписанного app и extension и allowlist в profiles. Не включайте неподдерживаемые entitlements и не обходите проверку подписи.

## Согласованность между процессами

Все операции общего playback используют Keychain lease с атомарным SecItemAdd и уникальным owner в kSecAttrGeneric. При освобождении/удалении истёкшей lease query включает owner, поэтому запоздавшая операция не удаляет новую lease. Lease живёт 120 секунд, ожидание ограничено 6 секундами. Сетевые операции имеют более короткие resource timeouts; после завершения lease удаляется. Если ОС завершит extension, просроченная lease восстанавливается по TTL.

Этот вариант не меняет правила обновления WidgetKit: continuous polling и ежесекундные CarPlay updates не обещаются. Для использования реального Spotify требуются Premium, необходимые scopes, разрешённый пользователь и активное playback-устройство.
