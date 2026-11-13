import Foundation
import os
import MovieStore

/// Keeps the snapshot in memory and records every save, so tests can assert
/// what the store wrote and how often.
public final class InMemoryMovieStorePersistence: MovieStorePersistence, Sendable {

  private struct State {
    var initial: MovieStoreSnapshot
    var saved: [MovieStoreSnapshot] = []
  }

  private let state: OSAllocatedUnfairLock<State>

  public init(initial: MovieStoreSnapshot = .empty) {
    state = OSAllocatedUnfairLock(initialState: State(initial: initial))
  }

  /// Every snapshot passed to `save`, in order.
  public var saved: [MovieStoreSnapshot] {
    state.withLock { $0.saved }
  }

  public func load() async throws -> MovieStoreSnapshot {
    state.withLock { $0.initial }
  }

  public func save(_ snapshot: MovieStoreSnapshot) async throws {
    state.withLock { $0.saved.append(snapshot) }
  }
}

public extension LocalMovieStore {

  /// A store that never touches disk.
  static func inMemory(initial: MovieStoreSnapshot = .empty, now: @escaping @Sendable () -> Date = Date.init) -> LocalMovieStore {
    LocalMovieStore(persistence: InMemoryMovieStorePersistence(initial: initial), now: now)
  }
}
