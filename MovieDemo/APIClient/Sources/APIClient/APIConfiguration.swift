import Foundation

public struct APIConfiguration: Sendable {
  public let baseUrl: URL
  public let apiKey: String

  public init(baseUrl: URL, apiKey: String) {
    self.baseUrl = baseUrl
    self.apiKey = apiKey
  }

  /// TMDB v3 configuration.
  public static func movieDatabase(apiKey: String) -> APIConfiguration {
    APIConfiguration(baseUrl: URL(string: "https://api.themoviedb.org/3")!, apiKey: apiKey)
  }
}
