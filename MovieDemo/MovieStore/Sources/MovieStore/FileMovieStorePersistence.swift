import Foundation

/// Saves the snapshot as one JSON file. A missing or unreadable file loads as
/// empty, so a corrupt file never blocks launch.
public struct FileMovieStorePersistence: MovieStorePersistence {

  public let fileURL: URL

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// `…/Application Support/MovieDemo/movie-store.json`. The directory is created on first save.
  public static func applicationSupport() -> FileMovieStorePersistence {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return FileMovieStorePersistence(fileURL: base.appendingPathComponent("MovieDemo", isDirectory: true).appendingPathComponent("movie-store.json"))
  }

  public func load() async throws -> MovieStoreSnapshot {
    guard let data = try? Data(contentsOf: fileURL) else { return .empty }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode(MovieStoreSnapshot.self, from: data)) ?? .empty
  }

  public func save(_ snapshot: MovieStoreSnapshot) async throws {
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
  }
}
