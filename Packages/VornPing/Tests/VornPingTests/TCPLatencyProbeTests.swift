import Testing
@testable import VornPing

struct TCPLatencyProbeTests {
    @Test func rejectsInvalidPort() async {
        let probe = TCPLatencyProbe(timeout: 0.1, attempts: 1)
        #expect(await probe.measure(host: "127.0.0.1", port: 0) == nil)
        #expect(await probe.measure(host: "127.0.0.1", port: 70000) == nil)
    }
}
