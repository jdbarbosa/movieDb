import Foundation
import os
import Testing
import Models
import MovieStoreTesting
@testable import MovieStore

@Suite("LocalMovieStore")
struct LocalMovieStoreTests {

  private let movie = Movie(id: 1, title: "One")
  private let other = Movie(id: 2, title: "Two")

  /// A clock that returns successive seconds so order is deterministic.
  private final class Clock: Sendable {
    private let tick = OSAllocatedUnfairLock(initialState: 0)
    func now() -> Date {
      let n = tick.withLock { $0 += 1; return $0 }
      return Date(timeIntervalSince1970: TimeInterval(n))
    }
  }

  private func makeStore(initial: MovieStoreSnapshot = .empty) -> (LocalMovieStore, InMemoryMovieStorePersistence, Clock) {
    let persistence = InMemoryMovieStorePersistence(initial: initial)
    let clock = Clock()
    return (LocalMovieStore(persistence: persistence, now: clock.now), persistence, clock)
  }

  @Test func addMakesMovieVisibleInCollectionAndMembership() async throws {
    let (store, _, _) = makeStore()
    try await store.add(movie, to: .watchlist)
    #expect(try await store.movies(in: .watchlist).map(\.movie) == [movie])
    #expect(try await store.collections(containing: 1) == [.watchlist])
    #expect(try await store.movies(in: .seen).isEmpty)
  }

  @Test func moviesAreNewestFirst() async throws {
    let (store, _, _) = makeStore()
    try await store.add(movie, to: .favourites)
    try await store.add(other, to: .favourites)
    #expect(try await store.movies(in: .favourites).map(\.id) == [2, 1])
  }

  @Test func secondAddIsQuietAndKeepsOriginalDate() async throws {
    let (store, persistence, _) = makeStore()
    try await store.add(movie, to: .watchlist)
    let first = try await store.movies(in: .watchlist)[0].addedAt
    let stream = await store.changes()
    try await store.add(movie, to: .watchlist)
    #expect(persistence.saved.count == 1)
    #expect(try await store.movies(in: .watchlist)[0].addedAt == first)
    try await store.add(other, to: .seen)   // sentinel: the next change we see must be this one
    var iterator = stream.makeAsyncIterator()
    #expect(await iterator.next() == MovieStoreChange(movieID: 2, collection: .seen, kind: .added))
  }

  @Test func removeEmitsAndSavesRemoveAbsentIsQuiet() async throws {
    let (store, persistence, _) = makeStore()
    try await store.add(movie, to: .seen)
    let stream = await store.changes()
    try await store.remove(movieID: 1, from: .seen)
    #expect(try await store.movies(in: .seen).isEmpty)
    #expect(persistence.saved.count == 2)
    try await store.remove(movieID: 1, from: .seen)
    #expect(persistence.saved.count == 2)
    var iterator = stream.makeAsyncIterator()
    #expect(await iterator.next() == MovieStoreChange(movieID: 1, collection: .seen, kind: .removed))
  }

  @Test func flagsAreIndependent() async throws {
    let (store, _, _) = makeStore()
    try await store.add(movie, to: .watchlist)
    try await store.add(movie, to: .seen)
    try await store.remove(movieID: 1, from: .seen)
    #expect(try await store.collections(containing: 1) == [.watchlist])
  }

  @Test func savedSnapshotMatchesState() async throws {
    let (store, persistence, _) = makeStore()
    try await store.add(movie, to: .watchlist)
    try await store.add(other, to: .watchlist)
    let expected = try await store.movies(in: .watchlist)
    #expect(persistence.saved.last?.entries[.watchlist]?.sorted { $0.addedAt > $1.addedAt } == expected)
  }

  @Test func loadsInitialSnapshotLazily() async throws {
    let stored = StoredMovie(movie: movie, addedAt: Date(timeIntervalSince1970: 10))
    let (store, _, _) = makeStore(initial: MovieStoreSnapshot(entries: [.favourites: [stored]]))
    #expect(try await store.movies(in: .favourites) == [stored])
  }

  @Test func changesReachEverySubscriber() async throws {
    let (store, _, _) = makeStore()
    let a = await store.changes()
    let b = await store.changes()
    try await store.add(movie, to: .watchlist)
    var ia = a.makeAsyncIterator()
    var ib = b.makeAsyncIterator()
    let change = MovieStoreChange(movieID: 1, collection: .watchlist, kind: .added)
    #expect(await ia.next() == change)
    #expect(await ib.next() == change)
  }

  @Test func cancellingSubscriberRemovesItsContinuation() async throws {
    let (store, _, _) = makeStore()
    let stream = await store.changes()
    #expect(await store.subscriberCount == 1)
    let consumer = Task { for await _ in stream {} }
    consumer.cancel()
    _ = await consumer.value
    // onTermination hops back into the actor; give it one turn.
    var attempts = 0
    while await store.subscriberCount != 0, attempts < 50 { attempts += 1; await Task.yield() }
    #expect(await store.subscriberCount == 0)
  }

  /// Save takes longer for a one-entry snapshot than for a two-entry one, so an
  /// unserialised store would land the first save last and leave disk behind memory.
  @Test func overlappingMutationsReachDiskInMemoryOrder() async throws {
    final class SlowPersistence: MovieStorePersistence, Sendable {
      let inner = InMemoryMovieStorePersistence()
      func load() async throws -> MovieStoreSnapshot { try await inner.load() }
      func save(_ snapshot: MovieStoreSnapshot) async throws {
        let entries = snapshot.entries.values.reduce(0) { $0 + $1.count }
        try await Task.sleep(for: .milliseconds(entries == 1 ? 60 : 1))
        try await inner.save(snapshot)
      }
    }
    let persistence = SlowPersistence()
    let store = LocalMovieStore(persistence: persistence)

    async let first: Void = store.add(movie, to: .watchlist)
    async let second: Void = store.add(other, to: .watchlist)
    _ = try await (first, second)

    let final = try await store.movies(in: .watchlist)
    #expect(persistence.inner.saved.count == 2)
    #expect(persistence.inner.saved.last?.entries[.watchlist]?.sorted { $0.addedAt > $1.addedAt } == final)
    #expect(final.count == 2)
  }
}
