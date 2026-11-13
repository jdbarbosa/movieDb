import APIClient
import Models
import MovieStore

protocol MovieDetailRepository: Sendable {
  func movieDetails(id: Int) async throws -> Movie
  func collections(containing movieID: Int) async throws -> Set<MovieCollection>
  func add(_ movie: Movie, to collection: MovieCollection) async throws
  func remove(movieID: Int, from collection: MovieCollection) async throws
  func changes() async -> AsyncStream<MovieStoreChange>
}

final class MovieDetailRepositoryImpl: MovieDetailRepository {

  private let apiClient: any APIClient
  private let store: any MovieStore

  init(apiClient: any APIClient, store: any MovieStore) {
    self.apiClient = apiClient
    self.store = store
  }

  func movieDetails(id: Int) async throws -> Movie {
    try await apiClient.send(MovieDetailRequest(id: id))
  }

  func collections(containing movieID: Int) async throws -> Set<MovieCollection> {
    try await store.collections(containing: movieID)
  }

  func add(_ movie: Movie, to collection: MovieCollection) async throws {
    try await store.add(movie, to: collection)
  }

  func remove(movieID: Int, from collection: MovieCollection) async throws {
    try await store.remove(movieID: movieID, from: collection)
  }

  func changes() async -> AsyncStream<MovieStoreChange> {
    await store.changes()
  }
}
