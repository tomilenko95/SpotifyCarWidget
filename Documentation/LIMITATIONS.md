# Подтверждения и ограничения на 5 ноября 2026

Этот файл разделяет официальные возможности платформ и то, что ещё требует проверки именно данной реализации. Изменение документации сервисов после этой даты может потребовать изменений проекта.

## Apple

- iOS 26 CarPlay поддерживает WidgetKit `systemSmall`; наличие отдельного CarPlay app не обязательно. Поэтому проект не включает CarPlay entitlement и не притворяется audio-template приложением. CarPlay добавление выполняется пользователем через настройки автомобиля на iPhone. [Apple WWDC25](https://developer.apple.com/videos/play/wwdc2025/216/), [статья WidgetKit](https://developer.apple.com/documentation/widgetkit/adding-standby-and-carplay-support-to-your-widget).
- Интерактивность CarPlay поддерживается на сенсорных экранах. На иных дисплеях нужно принимать информационный вариант; открытие обычного приложения на автомобильном экране не обещается. Семейство medium здесь только для домашнего экрана iPhone. [Apple WWDC25](https://developer.apple.com/videos/play/wwdc2025/216/).
- В CarPlay/StandBy фон может удаляться. Реализован `containerBackground(for: .widget)` с removable background, обложка и метаданные остаются частью content. [Apple о фоне](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background).
- Частоту timeline определяет WidgetKit. 15 минут в коде — нижняя граница запрошенного следующего обновления, не SLA; команды и reload могут также откладываться. [Apple о timeline](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).
- В текущей таблице Apple **App Groups и Keychain Sharing имеют отметки ADP, ADEP и бесплатного Apple Developer**. У **Associated Domains** отметка бесплатного Apple Developer отсутствует. Поэтому препятствие полного пути в этом проекте — HTTPS OAuth / Associated Domains и неподтверждённое облачное Personal provisioning, не общий запрет App Groups. Personal-вариант намеренно использует самостоятельное демо без дополнительных entitlements для переносимости. [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), [supported capabilities iOS](https://developer.apple.com/help/account/reference/supported-capabilities-ios/). Отметки проверены по исходному HTML официальной таблицы, поскольку текстовая выдача скрывает значки.
- Бесплатное provisioning Apple описывает через Xcode, с 7-дневными profiles и ограничениями App IDs/devices/apps. Не подтверждено, что Codemagic может выполнить такой Personal Team процесс и выдать устанавливаемый полный IPA без Mac. [Apple Account](https://developer.apple.com/help/account/basics/about-your-developer-account).

## Spotify

- GET playback и четыре команды входят в официальный список player endpoints, оставшихся доступными после изменений новых Development Mode apps. Наличие endpoint в документации не отменяет Premium, scopes, allowlist, device restrictions или право Spotify отказать конкретному приложению. [Changelog февраля 2026](https://developer.spotify.com/documentation/web-api/references/changes/february-2026).
- Development Mode: Premium у владельца, максимум пять allowlisted пользователей. С июля 2026 разрешено до **25 Client IDs на developer account**, вместо прежнего одного; квота API теперь общая на developer account. Это соответствует личному проекту, но не даёт права масштабировать сервис. [Quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes), [июльский changelog](https://developer.spotify.com/documentation/web-api/references/changes/july-2026). При проверке учитывались также мартовский и майский changelog, а не только исходное объявление февраля.
- Команды управления требуют Premium и активного Spotify Connect устройства. Приложение не воспроизводит Spotify audio, не запускает гарантированно Spotify при заблокированном iPhone и не переносит playback автоматически. [Start/Resume](https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback).
- Используются HTTPS redirect и PKCE. Произвольная custom scheme не предполагается допустимой; loopback архитектура здесь не реализована. Нужен управляемый HTTPS host с AASA и Associated Domains. [Spotify redirect requirements](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri), [Apple HTTPS callback](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/callback/https(host:path:)).
- Spotify не предоставляет приложению аудиосигнал для waveform. Волна чисто декоративная и статичная. Cover Focus для реальной обложки отличается от художественного демо: наложение текстов/градиентов запрещено правилами сервиса. [Design guidelines](https://developer.spotify.com/documentation/design).

## Что ещё не подтверждено испытанием

1. Работа всех previews и визуальных режимов виджетов. Компиляция Xcode, 35 XCTest и запуск Personal demo в симуляторе уже подтверждены [успешным CI](https://github.com/tomilenko95/SpotifyCarWidget/actions/runs/42077207345); это не заменяет проверку виджетов в CarPlay.
2. Реальная OAuth с пользовательским Client ID / доменом / подписью, работа Keychain group после переустановки и refresh token rotation конкретного Spotify account.
3. Фактическая отзывчивость интерактивных кнопок WidgetKit при закрытом приложении на iOS 26 и в автомобиле пользователя.
4. Поведение до/после lock, CarPlay margins, Dynamic Type, night mode/StandBy и геометрия на разных головных устройствах.
5. Бесплатная переподпись Personal demo сторонними инструментами Windows с сохранённым `.appex`; наличие extensions само по себе не гарантирует App Groups.
6. Доступность бесплатных macOS minutes в аккаунте Codemagic. Бесплатная разработка исходников не означает бесплатную подпись Apple Developer Program.

Unsigned IPA намеренно имеет предупреждающее имя. Он не выдаётся за устанавливаемый артефакт. Конфигурации cloud signing подготовлены, но сертификаты, profiles, домен, Spotify Client ID и авторизацию аккаунтов должен предоставить владелец.
