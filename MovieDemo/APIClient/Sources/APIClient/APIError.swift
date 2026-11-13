import Foundation

public enum APIError: Error, Equatable, Sendable {
  /// The request could not be built.
  case client
  /// Transport failure or non-2xx status (status attached when known).
  case network(Int?)
  /// The body could not be decoded into the expected type.
  case decoding
  /// No internet connection.
  case unreachable
  /// HTTP 401: the API key is missing or invalid.
  case notAuthenticated
}

extension APIError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .client:
      return "Could not build the request."
    case .network(let status?):
      return "Network error (status \(status))."
    case .network(nil):
      return "Network error."
    case .decoding:
      return "Could not read the server response."
    case .unreachable:
      return "No internet connection."
    case .notAuthenticated:
      return "Invalid API key."
    }
  }
}
