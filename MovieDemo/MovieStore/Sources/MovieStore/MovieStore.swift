import Models

/// On-device record of which collections each movie belongs to.
public protocol MovieStore: Sendable {

  /// Movies in `collection`, newest addition first.
  func movies(in collection: MovieCollection) async throws -> [StoredMovie]

  /// Every collection that contains `movieID`.
  func collections(containing movieID: Int) async throws -> Set<MovieCollection>

  /// Files `movie` under `collection`. Idempotent and quiet: adding a movie
  /// that is already there keeps its original date, saves nothing and emits nothing.
  func add(_ movie: Movie, to collection: MovieCollection) async throws

  /// Removes `movieID` from `collection`. Quiet no-op when it is not there.
  func remove(movieID: Int, from collection: MovieCollection) async throws

  /// A fresh stream of changes for one consumer. It ends, and the store forgets
  /// it, when the consuming task is cancelled.
  func changes() async -> AsyncStream<MovieStoreChange>
}

/// Where the snapshot lives. The store owns the logic; this only loads and saves.
public protocol MovieStorePersistence: Sendable {
  func load() async throws -> MovieStoreSnapshot
  func save(_ snapshot: MovieStoreSnapshot) async throws
}
