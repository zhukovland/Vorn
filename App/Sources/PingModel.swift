import Foundation
import Observation
import VornCore
import VornPing

/// Измеряет пинг серверов параллельно (с ограничением одновременных проб) и
/// хранит результат по id сервера. Карточки читают отсюда.
@Observable
@MainActor
final class PingModel {
    /// serverID → RTT в мс. Отсутствие ключа = ещё не измерен / не ответил.
    private(set) var pings: [String: Int] = [:]
    /// serverID, которые меряются прямо сейчас — карточки показывают спиннер.
    private(set) var measuring: Set<String> = []

    @ObservationIgnored private let probe: LatencyMeasuring

    init(probe: LatencyMeasuring = TCPLatencyProbe()) {
        self.probe = probe
    }

    /// Меряет переданные серверы, пропуская те, что уже в замере. Прогоны не
    /// глушат друг друга (одиночный пинг не обрывает массовый): каждый владеет
    /// своими id и снимает их сам по мере готовности.
    func measure(_ servers: [VLESSServer]) {
        let pending = servers.filter { !measuring.contains($0.id) }
        guard !pending.isEmpty else { return }
        measuring.formUnion(pending.map(\.id))
        let probe = self.probe
        Task { [weak self] in
            await withTaskGroup(of: (String, Int?).self) { group in
                let maxConcurrent = 12
                var iterator = pending.makeIterator()
                var running = 0
                while running < maxConcurrent, let server = iterator.next() {
                    group.addTask { (server.id, await probe.measure(host: server.address, port: server.port)) }
                    running += 1
                }
                for await (id, ms) in group {
                    self?.measuring.remove(id)
                    if let ms { self?.pings[id] = ms }
                    if let server = iterator.next() {
                        group.addTask { (server.id, await probe.measure(host: server.address, port: server.port)) }
                    }
                }
            }
        }
    }
}
