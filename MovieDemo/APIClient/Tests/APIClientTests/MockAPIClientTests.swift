import Foundation
import Testing
import APIClient
import APIClientTesting

private struct Payload: Decodable, Sendable, Equatable {
  let value: Int
}

private struct ItemRequest: APIRequest {
  typealias Response = Payload
  let page: Int
  var path: String { "/items" }
  var queryItems: [URLQueryItem]? { [URLQueryItem(name: "page", value: "\(page)")] }
}

@Suite("MockAPIClient")
struct MockAPIClientTests {

  @Test func returnsStubbedResultAndRecordsRequest() async throws {
    let mock = MockAPIClient()
    mock.stub(path: "/items", result: .success(Payload(value: 1)))
    let payload = try await mock.send(ItemRequest(page: 3))
    #expect(payload == Payload(value: 1))
    #expect(mock.receivedRequests == [
      RecordedRequest(path: "/items", queryItems: [URLQueryItem(name: "page", value: "3")], method: .get)
    ])
  }

  @Test func fifoConsumesThenRepeatsLast() async throws {
    let mock = MockAPIClient()
    mock.stub(path: "/items", result: .success(Payload(value: 1)))
    mock.stub(path: "/items", result: .success(Payload(value: 2)))
    let a = try await mock.send(ItemRequest(page: 1))
    let b = try await mock.send(ItemRequest(page: 2))
    let c = try await mock.send(ItemRequest(page: 3))
    let values: [Int] = [a.value, b.value, c.value]
    #expect(values == [1, 2, 2])
  }

  @Test func unstubbedThrowsClient() async {
    let mock = MockAPIClient()
    await #expect(throws: APIError.client) { try await mock.send(ItemRequest(page: 1)) }
    #expect(mock.receivedRequests.count == 1)
  }

  @Test func handlerSeesQueryItems() async throws {
    let mock = MockAPIClient()
    mock.stub(path: "/items") { request in
      let page = request.queryItems.first { $0.name == "page" }?.value.flatMap(Int.init) ?? -1
      return Payload(value: page)
    }
    let payload = try await mock.send(ItemRequest(page: 9))
    #expect(payload.value == 9)
  }

  @Test func delayIsCancellable() async {
    let mock = MockAPIClient()
    mock.stub(path: "/items", result: .success(Payload(value: 1)), delay: .seconds(10))
    let task = Task { try await mock.send(ItemRequest(page: 1)) }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
  }
}
