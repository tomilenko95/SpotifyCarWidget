# Подключение Spotify

## Предварительные условия

Нужны Spotify Premium у владельца приложения, доступ к [Developer Dashboard](https://developer.spotify.com/dashboard), свой HTTPS-домен (или поддомен хостинга, которым вы управляете), подпись Apple с App Groups / Associated Domains и два bundle IDs. Разработка поддерживается для личного использования; Development Mode не требует extended quota для используемых player endpoints. Доступ конкретной учётной записи проверяется только настоящим запросом, 403 не обходится.

1. Создайте приложение **CarWidget** в Dashboard. Скопируйте **Client ID**. Client Secret не нужен и не должен попадать в репозиторий, IPA или CI environment.
2. В разделе пользователей добавьте свой аккаунт в allowlist. Максимум пять пользователей; владельцу нужен Premium. Команды воспроизведения также требуют Premium у пользователя.
3. Зарегистрируйте **точно** `https://login.your-domain.com/spotify/callback`. Никакой произвольной custom URL scheme или `localhost` в проекте не используется. Loopback Spotify допускает для других сценариев, но здесь iPhone не поднимает HTTP-сервер.
4. Скопируйте `Config/Local.xcconfig.example` в `Config/Local.xcconfig`, замените все идентификаторы. Файл исключён из Git. Для CI используйте environment group из инструкции сборки.
5. Убедитесь, что `APP_GROUP` зарегистрирован и разрешён **обоим** targets; `KEYCHAIN_GROUP` вычисляется из AppIdentifierPrefix и основного bundle ID и одинаков в обоих targets. Для перенесённых приложений prefix может отличаться от Team ID — используйте значение из действующих profiles.

## HTTPS callback и AASA

Применяется `ASWebAuthenticationSession(url:callback:.https(host:path:))` — нативный HTTPS callback Apple. Это не редирект с HTTPS на custom scheme. Приложение удерживает сессию до callback; OS доставляет URL прямо completion handler, затем приложение проверяет origin, path, state и обменивает code вместе с verifier. Если процесс завершён, нужно начать вход заново; verifier и code не сохраняются.

В entitlement приложения настроены:

```text
webcredentials:login.your-domain.com
applinks:login.your-domain.com
```

Для HTTPS-сессии существенно `webcredentials`. `applinks` подготовлен для ассоциации адреса, но отдельный универсальный URL вне активной OAuth-сессии не принимается как авторизация. Ручного ввода code и небезопасного обхода state нет.

Разместите на том же хосте файл `/.well-known/apple-app-site-association` **без расширения** из `OAuthHosting/`. Замените `TEAMID.com.yourname.SpotifyCarWidget` на настоящий application identifier основного приложения. В `webcredentials.apps` и `applinks.details.appIDs` должен быть один и тот же ID. Расширение не выполняет вход и не нуждается в Associated Domains.

Хост должен отдавать JSON по HTTPS с доверенным сертификатом, HTTP 200, `Content-Type: application/json`, без переадресаций. Подойдёт статический HTTPS-хостинг с поддержкой `.well-known`; отдельный backend, client secret и хранение токенов на сервере не нужны. AASA и callback должны быть на **том хосте**, который зарегистрирован в Dashboard; путь и завершающий слеш также должны совпадать.

Статическая страница `OAuthHosting/spotify/callback/index.html` — только безопасная запасная страница, если сессия закрыта. Она ничего не обменивает и не выводит code. Не включайте аналитику, внешние скрипты и логирование query string на callback-хосте. ОС должна перехватить redirect до загрузки страницы. Изменение AASA может потребовать времени на CDN Apple и переустановки приложения.

Проверка с Windows:

```powershell
curl.exe -i https://login.your-domain.com/.well-known/apple-app-site-association
```

При ошибке входа проверьте host/path, подпись Associated Domains в **фактическом** IPA, bundle ID, application identifier, AASA и точный Redirect URI. Переименование bundle ID при повторной подписи делает прежний AASA несовместимым.

## Scopes и endpoints

Запрашиваются только `user-read-playback-state` и `user-modify-playback-state`.

| Метод и путь от `https://api.spotify.com/v1` | Назначение | Scope | Development Mode |
|---|---|---|---|
| GET `/me/player` | трек, устройство, progress, duration, actions | user-read-playback-state | перечислен как доступный |
| PUT `/me/player/play` | продолжить на активном устройстве | user-modify-playback-state | перечислен как доступный |
| PUT `/me/player/pause` | пауза | user-modify-playback-state | перечислен как доступный |
| POST `/me/player/next` | следующий | user-modify-playback-state | перечислен как доступный |
| POST `/me/player/previous` | предыдущий | user-modify-playback-state | перечислен как доступный |

Все пять подтверждены списком Spotify **Endpoints still available → Player** в [changelog февраля 2026](https://developer.spotify.com/documentation/web-api/references/changes/february-2026), просмотренным 05.11.2026. GET `/me/player/currently-playing` тоже перечислен, но дополнительный запрос не нужен: используется один GET `/me/player`. Устаревшие поля popularity, markets, profile.product не требуются. Обложка загружается непосредственно с `*.scdn.co` по HTTPS, выбран размер около 300 px.

Также проверены changelog [марта](https://developer.spotify.com/documentation/web-api/references/changes/march-2026), [мая](https://developer.spotify.com/documentation/web-api/references/changes/may-2026) и [июля 2026](https://developer.spotify.com/documentation/web-api/references/changes/july-2026). Июль увеличил число Client IDs с 1 до **25 на разработчика** и перенёс подсчёт квот Development Mode на уровень developer account: разные Client IDs делят квоту. Старое февральское ограничение «один Client ID» больше нельзя считать актуальным. Данный проект использует один Client ID и не пытается распределять нагрузку по нескольким приложениям.

OAuth endpoints: `https://accounts.spotify.com/authorize` и POST `https://accounts.spotify.com/api/token`, `application/x-www-form-urlencoded`, PKCE S256. При refresh отсутствующий новый refresh_token сохраняет старый. 401 API вызывает один refresh и один повтор. Ошибка refresh grant требует нового входа. Не выводите response body токенов в логи.

## Проверка после сборки

Откройте приложение, отключите демо или выполните вход (успешный вход автоматически включает Spotify), начните трек в Spotify и нажмите «Обновить состояние». Затем добавьте три виджета. Перед первой поездкой разблокируйте iPhone после перезагрузки; Keychain и файловый кеш используют доступность после первого разблокирования.

Выход удаляет общий Keychain item, снимок Spotify и кеш обложек и запрашивает перезагрузку виджетов. Это локальный logout, не удаление разрешения на стороне Spotify. Для отзыва grant откройте страницу управления приложениями в своём Spotify Account.

Источники: [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), [Redirect URI](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri), [Quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes), [HTTPS callback Apple](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/callback/https(host:path:)), [Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).
