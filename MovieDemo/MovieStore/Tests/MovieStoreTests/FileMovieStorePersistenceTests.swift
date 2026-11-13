import Foundation
import Testing
import Models
@testable import MovieStore

@Suite("FileMovieStorePersistence")
struct FileMovieStorePersistenceTests {

  private func temporaryFile() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .appendingPathComponent("movie-store.json")
  }

  @Test func saveThenLoadRoundTrips() async throws {
    let url = temporaryFile()
    let persistence = FileMovieStorePersistence(fileURL: url)
    let stored = StoredMovie(movie: Movie(id: 7, title: "Seven", posterPath: "/p.jpg"), addedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let snapshot = MovieStoreSnapshot(entries: [.watchlist: [stored], .seen: []])
    try await persistence.save(snapshot)
    #expect(try await persistence.load() == snapshot)
  }

  @Test func loadOfMissingFileIsEmpty() async throws {
    let persistence = FileMovieStorePersistence(fileURL: temporaryFile())
    #expect(try await persistence.load() == .empty)
  }

  @Test func loadOfGarbageFileIsEmpty() async throws {
    let url = temporaryFile()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: url)
    let persistence = FileMovieStorePersistence(fileURL: url)
    #expect(try await persistence.load() == .empty)
  }

  @Test func applicationSupportPathIsUnderMovieDemo() {
    let url = FileMovieStorePersistence.applicationSupport().fileURL
    #expect(url.lastPathComponent == "movie-store.json")
    #expect(url.deletingLastPathComponent().lastPathComponent == "MovieDemo")
  }
}
