import Foundation
import Models
import RESTMethods
import RESTServer
import XCTest

class PayloadSignatureVerifyingRESTEndpointTests: XCTestCase {
    let expectedPayloadSignature = PayloadSignature(value: "expected")
    let unexpectedPayloadSignature = PayloadSignature(value: "unexpected")

    func test___expected_request_signature_allows_execution_of_handler() {
        let endpoint = FakeVerifyingEndpoint(
            expectedPayloadSignature: expectedPayloadSignature,
            response: "good"
        )
        let payload = FakeSignedPayload(
            payloadSignature: expectedPayloadSignature
        )
        XCTAssertEqual(
            try endpoint.handle(decodedPayload: payload),
            "good"
        )
    }

    func test___mismatching_request_signature_prevents_execution_of_handler() {
        let endpoint = FakeVerifyingEndpoint(
            expectedPayloadSignature: expectedPayloadSignature,
            response: "good"
        )
        let payload = FakeSignedPayload(
            payloadSignature: unexpectedPayloadSignature
        )
        XCTAssertThrowsError(
            try endpoint.handle(decodedPayload: payload)
        )
    }
}

class FakeSignedPayload: SignedPayload, Codable {
    let payloadSignature: PayloadSignature

    init(payloadSignature: PayloadSignature) {
        self.payloadSignature = payloadSignature
    }
}

class FakeVerifyingEndpoint: PayloadSignatureVerifyingRESTEndpoint {
    typealias DecodedObjectType = FakeSignedPayload
    typealias ResponseType = String

    let expectedPayloadSignature: PayloadSignature
    let response: String

    init(expectedPayloadSignature: PayloadSignature, response: String) {
        self.expectedPayloadSignature = expectedPayloadSignature
        self.response = response
    }

    func handle(verifiedPayload: FakeSignedPayload) throws -> String {
        return response
    }
}
