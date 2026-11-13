import Foundation
import os
import Testing
import Locator
@testable import APIClient

private struct Pong: Decodable, Sendable, Equatable {
  let value: String
}

private struct PingRequest: APIRequest {
  typealias Response = Pong
  var path: String { "/ping" }
  var queryItems: [URLQueryItem]? { [URLQueryItem(name: "page", value: "2")] }
}

@Suite("MovieDatabaseAPIClient", .serialized)
struct MovieDatabaseAPIClientTests {

  private let configuration = APIConfiguration.movieDatabase(apiKey: "KEY")

  private func makeClient() -> MovieDatabaseAPIClient {
    MovieDatabaseAPIClient(configuration: configuration, session: StubURLProtocol.makeSession())
  }

  private func respond(_ status: Int, body: String) {
    StubURLProtocol.install { request in
      let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      return (response, Data(body.utf8))
    }
  }

  @Test func buildsURLWithPathQueryAndAPIKey() async throws {
    let captured = OSAllocatedUnfairLockBox<URL?>(nil)
    StubURLProtocol.install { request in
      captured.set(request.url)
      let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (response, Data(#"{"value":"ok"}"#.utf8))
    }
    _ = try await makeClient().send(PingRequest())
    let url = try #require(captured.get())
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "https")
    #expect(components.host == "api.themoviedb.org")
    #expect(components.path == "/3/ping")
    #expect(Set(components.queryItems ?? []) == [URLQueryItem(name: "page", value: "2"), URLQueryItem(name: "api_key", value: "KEY")])
  }

  @Test func decodesSuccessfulResponse() async throws {
    respond(200, body: #"{"value":"ok"}"#)
    let pong = try await makeClient().send(PingRequest())
    #expect(pong == Pong(value: "ok"))
  }

  @Test func unauthorizedMapsToNotAuthenticated() async {
    respond(401, body: "{}")
    await #expect(throws: APIError.notAuthenticated) { try await makeClient().send(PingRequest()) }
  }

  @Test func serverErrorMapsToNetworkStatus() async {
    respond(500, body: "")
    await #expect(throws: APIError.network(500)) { try await makeClient().send(PingRequest()) }
  }

  @Test func badJSONMapsToDecoding() async {
    respond(200, body: "nope")
    await #expect(throws: APIError.decoding) { try await makeClient().send(PingRequest()) }
  }

  @Test func offlineMapsToUnreachable() async {
    StubURLProtocol.install { _ in throw URLError(.notConnectedToInternet) }
    await #expect(throws: APIError.unreachable) { try await makeClient().send(PingRequest()) }
  }

  @Test func cancelledURLErrorMapsToCancellation() async {
    StubURLProtocol.install { _ in throw URLError(.cancelled) }
    await #expect(throws: CancellationError.self) { try await makeClient().send(PingRequest()) }
  }

  @Test @MainActor func moduleRegistersClient() {
    let locator = Locator()
    APIClientModule.registerServices(in: locator, configuration: configuration)
    #expect(locator.isRegistered(.apiClient))
    #expect(APIClientModule.requiredKinds.isEmpty)
    #expect(locator.resolve(.apiClient) is MovieDatabaseAPIClient)
  }
}

/// Tiny Sendable box for capturing values inside @Sendable closures in tests.
final class OSAllocatedUnfairLockBox<Value: Sendable>: Sendable {
  private let lock: OSAllocatedUnfairLock<Value>
  init(_ value: Value) { lock = OSAllocatedUnfairLock(initialState: value) }
  func set(_ value: Value) { lock.withLock { $0 = value } }
  func get() -> Value { lock.withLock { $0 } }
}
