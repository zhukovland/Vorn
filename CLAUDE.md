# Vorn

VLESS-клиент (только VLESS + Reality; транспорты RAW/tcp с Vision и XHTTP) для iOS 17+ / macOS 14+ (app-таргет использует Observation; пакеты держат пол iOS 15 / macOS 13), один SwiftUI-код на обе платформы. tvOS 17+ — в планах: сейчас не собираем, но весь код вне app-таргета пишем платформенно-нейтрально. Импорт серверов — по подписочному URL (панель Remnawave): сервер отдаёт base64-текст со списком `vless://` ссылок.

## Рабочий цикл

Проект генерируется **Tuist** — `Vorn.xcodeproj`/`Vorn.xcworkspace` в git не входят.

```sh
tuist generate --no-open   # после любой правки Project.swift / Package.swift
xcodebuild -workspace Vorn.xcworkspace -scheme Vorn -destination 'platform=macOS,arch=arm64' build -quiet
xcodebuild -workspace Vorn.xcworkspace -scheme Vorn -destination 'generic/platform=iOS Simulator' build -quiet
swift test --package-path Packages/VornCore
swift test --package-path Packages/VornStorage
```

После каждого шага проверять: тесты пакетов + сборка macOS и iOS Simulator.

## Структура

```
Project.swift, Tuist.swift   — манифесты Tuist (bundle id com.bigboys.Vorn, team GRFP8RCXX9)
App/Sources, App/Resources   — app-таргет Vorn (iPhone/iPad/Mac). UI живёт здесь, отдельного UI-модуля нет
Packages/VornCore            — модели (VLESSServer), парсинг подписок/ссылок, генерация Xray-конфига
Packages/VornStorage         — Keychain (access group) + обмен с extension через App Group; зависит от VornCore
Packages/VornSubscription    — загрузка подписки по URL (URLSession) + разбор заголовков; зависит от VornCore
PacketTunnel/Sources         — Network Extension (packet tunnel provider), единственный владелец SwiftyXrayKit
```

### Конвенция пакетов

Каждый локальный SPM-пакет: `Sources/Public/` (публичное API) и `Sources/Internal/` (реализация), у таргета `path: "Sources"` — без промежуточной папки с именем модуля. `platforms` включают `.tvOS(.v17)`. Тесты — Swift Testing (`import Testing`).

### Язык и конкурентность

Исключительно **Swift 6 language mode** (tools-version 6.0 в пакетах, `SWIFT_VERSION 6.0` в таргетах) и **Swift Concurrency**: async/await, актеры, `Sendable`-типы. Никакого GCD (`DispatchQueue`), никаких `@unchecked Sendable` без письменного обоснования. App-таргет использует `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; пакеты остаются с nonisolated-дефолтом.

## Архитектура (не пересматривать без причины)

1. **Ядро туннеля: SwiftyXrayKit 2.0+** (github.com/dima-u/SwiftyXrayKit) — обёртка над libXray-apple: пакеты идут из `NEPacketTunnelFlow` напрямую в TUN-inbound Xray через socketpair, **без tun2socks и без локального SOCKS-порта**. SwiftyXrayCore не использовать — deprecated.
2. **Изоляция ядра**: весь API SwiftyXrayKit — только внутри extension-таргета (PacketTunnelProvider). В UI, VornCore, VornStorage — никаких импортов SwiftyXrayKit. Причина — план Б: если SwiftyXrayKit умрёт, заменяем на LibXray (XTLS) + hev-socks5-tunnel, не трогая остальной код.
3. Граф зависимостей: App → VornCore, VornStorage; PacketTunnel → VornCore, VornStorage, SwiftyXrayKit. VornCore ни от чего не зависит.

## Безопасность (обязательно, причина — известные уязвимости VLESS-клиентов)

- **Никаких слушающих локальных портов.** Архитектура SwiftyXrayKit это обеспечивает — не ломать.
- В финальном Xray-конфиге **принудительно вырезать блоки `api`, `metrics`, `stats`** через configTransform-хук SwiftyXrayKit, даже если они пришли из подписки.
- Ключи и подписочные URL — **только Keychain** (access group на App Group), не UserDefaults.
- В логах extension не светить UUID ключей и адреса серверов; `loglevel: warning`.

## Стиль работы с владельцем проекта

Сначала предложить план и дождаться одобрения. После одобрения — выполнять автономно, не останавливаясь на мелких под-решениях; изменения поэтапно, после каждого шага — проверка сборки/тестов и отчёт по факту.
