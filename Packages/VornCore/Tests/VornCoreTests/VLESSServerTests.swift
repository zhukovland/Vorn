import Foundation
import Testing
@testable import VornCore

struct VLESSServerTests {
    @Test func roundTripsThroughCodable() throws {
        let server = VLESSServer(name: "Test", address: "example.com", port: 443, userID: "uuid")
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(VLESSServer.self, from: data)
        #expect(decoded == server)
    }
}
