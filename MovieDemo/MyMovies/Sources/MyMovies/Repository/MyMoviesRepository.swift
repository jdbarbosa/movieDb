import Models
import MovieStore

protocol MyMoviesRepository: Sendable {
  func movies(in collection: MovieCollection) async throws -> [StoredMovie]
  func remove(movieID: Int, from collection: MovieCollection) async throws
  func changes() async -> AsyncStream<MovieStoreChange>
}

final class MyMoviesRepositoryImpl: MyMoviesRepository {

  private let store: any MovieStore

  init(store: any MovieStore) {
    self.store = store
  }

  func movies(in collection: MovieCollection) async throws -> [StoredMovie] {
    try await store.movies(in: collection)
  }

  func remove(movieID: Int, from collection: MovieCollection) async throws {
    try await store.remove(movieID: movieID, from: collection)
  }

  func changes() async -> AsyncStream<MovieStoreChange> {
    await store.changes()
  }
}
