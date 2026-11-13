import Foundation

public enum HTTPRequestMethod: String, Sendable {
  case delete, get, patch, post, put
}

/// Describes one remote resource. Features declare their own request types
/// (for example `PopularMoviesRequest`) so the client stays endpoint-agnostic.
public protocol APIRequest: Sendable {
  /// The type the response body decodes into.
  associatedtype Response: Decodable & Sendable

  var path: String { get }
  var queryItems: [URLQueryItem]? { get }
  var httpRequestMethod: HTTPRequestMethod { get }
  var additionalHeaders: [String: String]? { get }
  var httpBody: Data? { get }
}

public extension APIRequest {
  var httpRequestMethod: HTTPRequestMethod { .get }
  var additionalHeaders: [String: String]? { nil }
  var httpBody: Data? { nil }
}

extension APIRequest {

  /// Builds the URLRequest for this resource against `baseUrl`, appending `api_key`.
  func buildRequest(baseUrl: URL, apiKey: String) -> URLRequest? {
    guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true) else {
      return nil
    }
    components.path = baseUrl.path.appending(path)
    components.queryItems = (queryItems ?? []) + [URLQueryItem(name: "api_key", value: apiKey)]
    guard let url = components.url else { return nil }

    var request = URLRequest(url: url)
    request.httpMethod = httpRequestMethod.rawValue.uppercased()
    request.httpBody = httpBody
    additionalHeaders?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    return request
  }
}
