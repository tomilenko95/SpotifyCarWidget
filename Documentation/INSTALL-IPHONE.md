# Установка на iPhone 15 Pro

## Полноценная версия с Spotify

Поддерживаемый путь проекта: Apple Developer Program → два действующих Ad Hoc profiles → signed-device в Codemagic → подписанный device IPA. До сборки зарегистрируйте UDID именно своего iPhone и включите его в profiles. После добавления устройства profiles нужно пересоздать. Одного сертификата без соответствующих entitlements и profiles недостаточно. [Apple: registered devices](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).

На Windows используйте средство установки уже подписанного Ad Hoc IPA с поддержкой iOS app bundles, например режим **normal install** в [Sideloadly](https://sideloadly.io/). Подключите iPhone кабелем, подтвердите доверие компьютеру, выберите подписанный IPA и обычную установку. **Не включайте переподпись другой командой или изменение bundle ID**: это изменяет entitlements, App Group и привязку AASA. Поддержка конкретного режима установки утилитой требует проверки на текущей версии; готовый IPA не проверен на устройстве в этой сессии.

Если утилита умеет только переподписывать и не сохраняет нужные capabilities, не используйте её для Full-варианта. Альтернатива с более однозначным пользовательским путём — подписанная App Store сборка и установка через TestFlight после настройки App Store Connect. Для development-подписи на iPhone может понадобиться Настройки → Конфиденциальность и безопасность → Режим разработчика, перезагрузка и подтверждение доверия. Не отключайте защиту системы ради установки.

После установки:

1. Откройте CarWidget, выполните Spotify-вход; проверьте, что демо выключено.
2. Откройте Spotify и начните воспроизведение. Вернитесь в CarWidget, нажмите обновление, проверьте обложку и кнопки.
3. На домашнем экране добавьте каждый виджет отдельно. Controls medium предназначен для iPhone.
4. Подключите CarPlay. На iPhone: Настройки → Основные → CarPlay → автомобиль → Виджеты. Добавьте Compact, Controls и Cover Focus.
5. Проверяйте в припаркованной машине. На несенсорном дисплее ожидается информационное отображение без обязательной работы кнопок. После перезагрузки телефона сначала разблокируйте его.

## Бесплатный Apple Account / Personal Team

Apple официально описывает бесплатное тестирование через Personal Team **в Xcode**: до 10 App IDs, до 3 устройств, до 3 приложений на устройство, срок profiles 7 дней. Это не механизм выпуска distribution IPA на облачном CI. [Apple Developer account](https://developer.apple.com/help/account/basics/about-your-developer-account).

В актуальной [таблице Apple](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) App Groups и Keychain Sharing отмечены для всех трёх категорий, включая бесплатный Apple Developer. **Associated Domains отмечен только для ADP/ADEP**, поэтому используемый проектом HTTPS callback остаётся препятствием для полной бесплатной конфигурации. Доступность capability в таблице также не доказывает её сохранение конкретной Windows-утилитой переподписи. См. [регистрацию App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups). Не обещается синхронизация Spotify после удаления общих entitlements.

Для доступного исследования дизайнов создана схема **SpotifyCarWidgetPersonal**:

- настоящие app + Widget Extension без App Groups, Keychain Sharing и Associated Domains;
- вход Spotify программно отключён;
- приложение полностью автономно, виджеты тоже имеют автономное демо;
- все три виджета делят локальные данные **расширения**, но не приложения;
- переключение демо-сценария в приложении не меняет демо расширения;
- подпись и сама возможность установки на iOS 26 всё равно должны быть проверены выбранным инструментом.

Это функционально ограниченный вариант, а не способ бесплатной установки полноценного Spotify-проекта.

## Альтернативная установка с Windows

**AltStore Classic + AltServer Windows.** Официальная [инструкция Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) описывает необходимые iTunes/iCloud, подключение iPhone и доверие компьютеру. Затем в AltStore можно выбрать IPA. Не удаляйте app extensions, если нужны виджеты. AltStore документирует дополнительные App IDs для extensions, [лимит 10 IDs](https://faq.altstore.io/altstore-classic/app-ids), [7-дневный срок и 3 приложения](https://faq.altstore.io/altstore-classic/your-altstore). Наличие поддержки extensions не означает, что нужные App Group / Associated Domains будут предоставлены бесплатным профилем.

**Sideloadly Windows.** Официальный сайт описывает подпись бесплатным/платным Apple Account, различные режимы установки и отдельную возможность удаления extensions. При установке Personal demo сохраните `SpotifyWidgets.appex`; удаление PlugIns оставит только приложение. Точное сохранение WidgetKit, entitlements и отображение CarPlay на iOS 26 данным проектом ещё не проверено. [Сайт разработчика](https://sideloadly.io/).

Перед альтернативной установкой Personal demo скачайте **device** `UNSIGNED-requires-signing.ipa` из unsigned-device. Утилита должна подписать и главное приложение, и вложенное расширение. Simulator.app.zip не подходит. Если инструмент изменяет bundle IDs, Full OAuth/AASA перестаёт совпадать, а общие группы могут исчезнуть. Нет гарантии полностью бесплатного полного пути Windows → Spotify CarPlay widgets без Mac и без Developer Program.

Не загружайте Apple Account, пароль и IPA с токенами на случайные сервисы подписи. В поставляемом исходном проекте токенов нет; после первого запуска они остаются только в Keychain устройства.
