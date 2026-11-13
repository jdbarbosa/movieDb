import Foundation

/// Builds TMDB image URLs from the relative paths the API returns.
public enum TMDBImage {

  public enum Size: String, Sendable {
    case w185
    case w500
  }

  private static let base = "https://image.tmdb.org/t/p/"

  public static func url(path: String?, size: Size) -> URL? {
    guard let path, !path.isEmpty else { return nil }
    return URL(string: base + size.rawValue + path)
  }
}
