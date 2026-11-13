import Foundation
import os
import APIClient

/// What the mock saw for one `send` call.
public struct RecordedRequest: Equatable, Sendable {
  public let path: String
  public let queryItems: [URLQueryItem]
  public let method: HTTPRequestMethod

  public init(path: String, queryItems: [URLQueryItem], method: HTTPRequestMethod) {
    self.path = path
    self.queryItems = queryItems
    self.method = method
  }
}

/// An `APIClient` that answers from scripted stubs and records every request.
///
/// Stubs are queued per path: each call consumes the next stub, and the last
/// one repeats, so pagination tests can script page 1 then page 2.
public final class MockAPIClient: APIClient, Sendable {

  private typealias Handler = @Sendable (RecordedRequest) async throws -> any Sendable

  private struct State {
    var handlers: [String: [Handler]] = [:]
    var received: [RecordedRequest] = []
  }

  private let state = OSAllocatedUnfairLock(initialState: State())

  public init() {}

  public func stub<R: Decodable & Sendable>(path: String, result: Result<R, APIError>, delay: Duration? = nil) {
    enqueue(path: path) { _ in
      if let delay {
        try await Task.sleep(for: delay)
      }
      return try result.get()
    }
  }

  public func stub<R: Decodable & Sendable>(path: String, handler: @escaping @Sendable (RecordedRequest) async throws -> R) {
    enqueue(path: path) { try await handler($0) }
  }

  public var receivedRequests: [RecordedRequest] {
    state.withLock { $0.received }
  }

  public func send<T: APIRequest>(_ request: T) async throws -> T.Response {
    let recorded = RecordedRequest(path: request.path, queryItems: request.queryItems ?? [], method: request.httpRequestMethod)
    let handler: Handler? = state.withLock { state in
      state.received.append(recorded)
      guard var queue = state.handlers[request.path], let next = queue.first else { return nil }
      if queue.count > 1 {
        queue.removeFirst()
        state.handlers[request.path] = queue
      }
      return next
    }
    guard let handler else { throw APIError.client }
    let value = try await handler(recorded)
    guard let typed = value as? T.Response else { throw APIError.decoding }
    return typed
  }

  private func enqueue(path: String, _ handler: @escaping Handler) {
    state.withLock { $0.handlers[path, default: []].append(handler) }
  }
}
