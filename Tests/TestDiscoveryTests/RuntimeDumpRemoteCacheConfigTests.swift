import Foundation
import Models
import ModelsTestHelpers
import PathLib
import RequestSender
import TestDiscovery
import TestHelpers
import XCTest

final class RuntimeDumpRemoteCacheConfigTests: XCTestCase {
    func test___decoding_full_json() throws {
        let json = """
            {
                "credentials": {
                    "username": "username",
                    "password": "password"
                },
                "storeHttpMethod": "put",
                "obtainHttpMethod": "get",
                "relativePathToRemoteStorage": "remote_cache_path/",
                "socketAddress": "example.com:1337"
            }
        """.data(using: .utf8)!

        let config = assertDoesNotThrow {
            try JSONDecoder().decode(RuntimeDumpRemoteCacheConfig.self, from: json)
        }

        XCTAssertEqual(
            config,
            RuntimeDumpRemoteCacheConfig(
                credentials: Credentials(username: "username", password: "password"),
                storeHttpMethod: .put,
                obtainHttpMethod: .get,
                relativePathToRemoteStorage: RelativePath("remote_cache_path/"),
                socketAddress: SocketAddress(host: "example.com", port: 1337)
            )
        )
    }
}

