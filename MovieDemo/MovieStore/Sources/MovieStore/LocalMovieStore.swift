import Foundation
import Models

/// The one place collection state is read or written. Being an actor, every
/// method body runs serially, so the in-memory snapshot needs no locks.
public actor LocalMovieStore: MovieStore {

  private let persistence: any MovieStorePersistence
  private let now: @Sendable () -> Date

  private var snapshot: MovieStoreSnapshot?
  private var continuations: [UUID: AsyncStream<MovieStoreChange>.Continuation] = [:]
  private var lastSave: Task<Void, any Error>?

  public init(persistence: any MovieStorePersistence, now: @escaping @Sendable () -> Date = Date.init) {
    self.persistence = persistence
    self.now = now
  }

  /// Live subscriptions. Exposed so tests can prove that a cancelled consumer is forgotten.
  public var subscriberCount: Int { continuations.count }

  // MARK: - MovieStore

  public func movies(in collection: MovieCollection) async throws -> [StoredMovie] {
    try await loadIfNeeded().entries[collection, default: []].sorted { $0.addedAt > $1.addedAt }
  }

  public func collections(containing movieID: Int) async throws -> Set<MovieCollection> {
    let entries = try await loadIfNeeded().entries
    return Set(entries.filter { $0.value.contains { $0.id == movieID } }.keys)
  }

  public func add(_ movie: Movie, to collection: MovieCollection) async throws {
    var current = try await loadIfNeeded()
    guard !current.entries[collection, default: []].contains(where: { $0.id == movie.id }) else { return }
    let stored = StoredMovie(movie: movie, addedAt: now())
    current.entries[collection, default: []].append(stored)
    snapshot = current
    do {
      try await persist(current)
    } catch {
      // The actor was free during the save, so other mutations may have landed since.
      // Undo exactly this entry rather than restoring the whole pre-save snapshot.
      snapshot?.entries[collection]?.removeAll { $0.id == movie.id }
      throw error
    }
    broadcast(MovieStoreChange(movieID: movie.id, collection: collection, kind: .added))
  }

  public func remove(movieID: Int, from collection: MovieCollection) async throws {
    var current = try await loadIfNeeded()
    guard let index = current.entries[collection, default: []].firstIndex(where: { $0.id == movieID }) else { return }
    let removed = current.entries[collection, default: []].remove(at: index)
    snapshot = current
    do {
      try await persist(current)
    } catch {
      snapshot?.entries[collection, default: []].append(removed)
      throw error
    }
    broadcast(MovieStoreChange(movieID: movieID, collection: collection, kind: .removed))
  }

  public func changes() async -> AsyncStream<MovieStoreChange> {
    let id = UUID()
    return AsyncStream { continuation in
      // This closure runs synchronously, inside the actor, so storing the
      // continuation here needs no hop.
      continuations[id] = continuation
      continuation.onTermination = { _ in
        // Termination is reported from the consumer's context; hop back in.
        Task { await self.removeSubscriber(id) }
      }
    }
  }

  // MARK: - Private

  private func loadIfNeeded() async throws -> MovieStoreSnapshot {
    if let snapshot { return snapshot }
    let loaded = try await persistence.load()
    // Another caller may have loaded while we awaited; keep the first result.
    if let snapshot { return snapshot }
    snapshot = loaded
    return loaded
  }

  /// Saves run strictly one after another, in the order mutations happened.
  ///
  /// `persistence.save` is nonisolated, so while one save is awaited the actor is
  /// free and a second mutation can start its own save. Two writes racing to the
  /// same file could land out of order and leave disk behind memory. Chaining
  /// each save on the previous one keeps disk order equal to memory order.
  private func persist(_ snapshot: MovieStoreSnapshot) async throws {
    let previous = lastSave
    let persistence = persistence
    let save = Task {
      _ = try? await previous?.value
      try await persistence.save(snapshot)
    }
    lastSave = save
    try await save.value
  }

  private func broadcast(_ change: MovieStoreChange) {
    for continuation in continuations.values {
      continuation.yield(change)
    }
  }

  private func removeSubscriber(_ id: UUID) {
    continuations[id] = nil
  }
}
