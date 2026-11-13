public protocol APIClient: Sendable {
  /// Performs the request and decodes its response. Throws `APIError`, or
  /// `CancellationError` when the surrounding task was cancelled.
  func send<T: APIRequest>(_ request: T) async throws -> T.Response
}
