import Foundation

public final class MovieDatabaseAPIClient: APIClient {

  private let configuration: APIConfiguration
  private let session: URLSession
  private let decoder: JSONDecoder

  public init(configuration: APIConfiguration, session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
    self.configuration = configuration
    self.session = session
    self.decoder = decoder
  }

  public func send<T: APIRequest>(_ request: T) async throws -> T.Response {
    guard let urlRequest = request.buildRequest(baseUrl: configuration.baseUrl, apiKey: configuration.apiKey) else {
      throw APIError.client
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: urlRequest)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as URLError where error.code == .cancelled {
      throw CancellationError()
    } catch let error as URLError where error.code == .notConnectedToInternet {
      throw APIError.unreachable
    } catch {
      throw APIError.network(nil)
    }

    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw http.statusCode == 401 ? APIError.notAuthenticated : APIError.network(http.statusCode)
    }

    do {
      return try decoder.decode(T.Response.self, from: data)
    } catch {
      throw APIError.decoding
    }
  }
}
