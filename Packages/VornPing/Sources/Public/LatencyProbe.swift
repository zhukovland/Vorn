import Foundation
// @preconcurrency: типы Network framework не помечены Sendable; хэлпер снимает
// диагностику для них, наш код остаётся под проверкой Swift 6.
@preconcurrency import Network

/// Измерение задержки до сервера. Абстракция ради тестируемости модели:
/// прод меряет TCP-хендшейк, тесты подставляют стаб.
public protocol LatencyMeasuring: Sendable {
    /// RTT в миллисекундах или nil, если сервер не ответил за таймаут.
    func measure(host: String, port: Int) async -> Int?
}

/// Пинг по времени TCP-хендшейка (SYN→SYN-ACK). Не требует поднятого туннеля —
/// так меряют «пинг» в списке большинство клиентов; Reality-сервер слушает
/// свой порт, поэтому connect проходит. Берём минимум из нескольких попыток.
public struct TCPLatencyProbe: LatencyMeasuring {
    private let timeout: TimeInterval
    private let attempts: Int

    // NWConnection.start(queue:) требует dispatch-очередь — это требование API
    // Network framework, обойти нельзя; единственное место с GCD в проекте.
    private static let queue = DispatchQueue(label: "com.bigboys.Vorn.ping", attributes: .concurrent)

    public init(timeout: TimeInterval = 3, attempts: Int = 2) {
        self.timeout = timeout
        self.attempts = max(1, attempts)
    }

    public func measure(host: String, port: Int) async -> Int? {
        guard (1...65535).contains(port), let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return nil
        }
        var best: Int?
        for _ in 0..<attempts {
            if let ms = await connectOnce(host: host, port: nwPort) {
                best = min(best ?? ms, ms)
            }
        }
        return best
    }

    private func connectOnce(host: String, port: NWEndpoint.Port) async -> Int? {
        // connectionTimeout у самого TCP: зависший хендшейк перейдёт в .failed
        // через timeout секунд. Отдельная таймаут-задача не нужна.
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = Int(timeout.rounded(.up))
        let connection = NWConnection(
            host: NWEndpoint.Host(host), port: port,
            using: NWParameters(tls: nil, tcp: tcp)
        )
        let startNanos = DispatchTime.now().uptimeNanoseconds
        let once = ResumeOnce()

        let ms: Int? = await withCheckedContinuation { continuation in
            once.attach(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = DispatchTime.now().uptimeNanoseconds - startNanos
                    once.fire(Int(elapsed / 1_000_000))
                case .failed, .waiting, .cancelled:
                    once.fire(nil)
                default:
                    break
                }
            }
            connection.start(queue: Self.queue)
        }
        connection.cancel()
        return ms
    }
}

/// Резолвит континуацию ровно один раз: NWConnection может прислать .ready,
/// затем .cancelled, плюс гонка с таймаутом — всё из разных потоков.
private final class ResumeOnce: @unchecked Sendable {
    // @unchecked Sendable: изменяемое состояние под NSLock (обоснование —
    // разовый резолв continuation из очереди Network и таймаут-таска).
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int?, Never>?
    private var done = false

    func attach(_ continuation: CheckedContinuation<Int?, Never>) {
        lock.lock(); defer { lock.unlock() }
        self.continuation = continuation
    }

    func fire(_ value: Int?) {
        lock.lock()
        guard !done else { lock.unlock(); return }
        done = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }
}
