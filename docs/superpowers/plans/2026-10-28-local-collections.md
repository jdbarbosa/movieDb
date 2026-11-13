# Local Collections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user mark movies as Watchlist, Seen or Favourite from the detail screen, store that on device, and list each collection under My Movies with live updates.

**Architecture:** A `MovieStore` leaf package exposes a `MovieStore` protocol and an `actor` that persists a Codable JSON snapshot through a `MovieStorePersistence` strategy and broadcasts `MovieStoreChange`s over `AsyncStream`s. A `MovieUI` package holds the shared `MovieCell` and collection display attributes. `MovieDetail` gains three toggles; `MyMovies` gains a per-collection list screen. View models observe the store with one owned `for await` task.

**Tech Stack:** Swift 6 strict concurrency, actors, `AsyncStream`, `withObservationTracking`, SwiftPM local packages, XcodeGen, Swift Testing, UIKit hosting SwiftUI.

**Spec:** `docs/superpowers/specs/2026-10-28-local-collections-design.md`

## Global Constraints

- `$ROOT` = `/Users/v.joao.diasbarbosa/Documents/Glazed/iOS/claude_generated`. Run every command from `$ROOT` unless a step says otherwise.
- `TEST` = `xcodebuild test -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'`; add `-only-testing:<Target>` where a step says so. Pass = `** TEST SUCCEEDED **`. `MovieStore` tests also run with `swift test` from `$ROOT/MovieDemo/MovieStore`.
- Edit `project.yml`, then `xcodegen generate`. Never edit `.xcodeproj`.
- New `Package.swift` files: `// swift-tools-version: 6.0`; `MovieStore` platforms `[.iOS(.v17), .macOS(.v14)]`; `MovieUI` platforms `[.iOS(.v17)]`.
- 2-space indentation; before each commit `grep -c $'^\t' <files>` must print `0` for every new or edited Swift file. `MovieDetailViewModel.swift` is currently tab-indented in the repo; convert it to two spaces in the task that edits it (`perl -pi -e 's/^(\t+)/"  " x length($1)/e; s/^[ \t]+$//' <file>`).
- Do not touch the hard-coded `apiKey` line in `MovieDemo/AppRouter.swift`.
- Never `git add -A`; add files by name. Commit after each task, message ending `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Exact copy: collection titles `Watchlist`, `Seen`, `Favourites`; symbols `bookmark`, `checkmark.circle`, `heart` and filled `bookmark.fill`, `checkmark.circle.fill`, `heart.fill`; empty messages `Nothing in your watchlist yet`, `Nothing marked as seen yet`, `No favourites yet`; locator key id `MovieStore`; file `Application Support/MovieDemo/movie-store.json`.
- Analytics names exactly: `movie_collection_toggled` (`movie_id`, `collection`, `action` = `added`|`removed`), `movie_collection_viewed` (`collection`), `movie_collection_removed` (`movie_id`, `collection`), `movie_selected` (`movie_id`), `my_movies_section_tapped` (`section`), `error_shown` (`screen`, `message`). `collection`/`section` values are `MovieCollection.rawValue`.

## Review Focus

1. A corrupt or missing JSON file must load as empty, never crash launch. Test in Task 2 (`loadOfGarbageFileIsEmpty`, `loadOfMissingFileIsEmpty`).
2. A view model that goes away must end its store subscription; otherwise every opened detail screen leaks a continuation forever. Test in Task 1 (`cancellingSubscriberRemovesItsContinuation`) and Task 4 (`deallocatedViewModelEndsSubscription`).
3. A change to a different movie must not flip the detail screen's toggles. Test in Task 4 (`changeForOtherMovieIsIgnored`).
4. Removing a row from a collection list must not remove it from the other collections. Test in Task 1 (`flagsAreIndependent`).
5. A failed persist must not leave the toggle showing a state the disk does not have. Test in Task 4 (`failedToggleRevertsAndTracksError`).

---

### Task 1: `MovieStore` package: types, protocol, actor, in-memory persistence

**Files:**
- Create: `MovieDemo/MovieStore/Package.swift`
- Create: `MovieDemo/MovieStore/Sources/MovieStore/MovieCollection.swift`
- Create: `MovieDemo/MovieStore/Sources/MovieStore/MovieStore.swift`
- Create: `MovieDemo/MovieStore/Sources/MovieStore/LocalMovieStore.swift`
- Create: `MovieDemo/MovieStore/Sources/MovieStoreTesting/InMemoryMovieStorePersistence.swift`
- Create: `MovieDemo/MovieStore/Tests/MovieStoreTests/LocalMovieStoreTests.swift`

**Interfaces:**
- Produces: everything in the spec's "MovieStore" contract except `FileMovieStorePersistence` and `MovieStoreModule` (Task 2). Exact signatures are in the spec; copy them.

- [ ] **Step 1: Create `Package.swift`**

Name `MovieStore`; products `MovieStore` and `MovieStoreTesting`; dependencies `../Locator`, `../Models`; targets `MovieStore` (deps `Locator`, `Models`), `MovieStoreTesting` (dep `MovieStore`), test target `MovieStoreTests` (deps `MovieStore`, `MovieStoreTesting`). Platforms per Global Constraints.

- [ ] **Step 2: Write the failing tests**

```swift
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
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd $ROOT/MovieDemo/MovieStore && swift test 2>&1 | tail -5`
Expected: build error, the `MovieStore` target has no sources or `cannot find 'LocalMovieStore' in scope`.

- [ ] **Step 4: Implement `MovieCollection.swift`**

`MovieCollection`, `StoredMovie`, `MovieStoreChange` (with nested `Kind`), `MovieStoreSnapshot` exactly as the spec's contract, all with public memberwise initialisers. Make `subscriberCount` public on the actor from the start (Task 4's tests read it). `MovieStoreSnapshot.empty` is `MovieStoreSnapshot()`.

- [ ] **Step 5: Implement `MovieStore.swift`**

The `MovieStore` and `MovieStorePersistence` protocols from the spec, with the doc comments from the contract (newest first; idempotent and quiet; no-op if absent; one stream per call, ends on cancel).

- [ ] **Step 6: Implement `LocalMovieStore.swift`**

`public actor LocalMovieStore: MovieStore` with `init(persistence:now:)`. Private state: `snapshot: MovieStoreSnapshot?`, `continuations: [UUID: AsyncStream<MovieStoreChange>.Continuation]`. `var subscriberCount: Int { continuations.count }` (internal, for tests). `private func loadIfNeeded() async throws -> MovieStoreSnapshot` loads once. `add`: return early if the movie id is already in that collection; otherwise append `StoredMovie(movie:addedAt: now())`, `try await persistence.save(snapshot)`, then `broadcast(.added)`. `remove`: mirror. `movies(in:)` sorts by `addedAt` descending. `changes()`: build an `AsyncStream` inside the actor, store the continuation under a new UUID, set `onTermination` to `{ _ in Task { await self.removeSubscriber(id) } }`. `broadcast` yields to every continuation.

- [ ] **Step 7: Implement `InMemoryMovieStorePersistence.swift` in the Testing target**

`public final class InMemoryMovieStorePersistence: MovieStorePersistence, Sendable` backed by `OSAllocatedUnfairLock<(initial: MovieStoreSnapshot, saved: [MovieStoreSnapshot])>`; `load()` returns `initial`, `save` appends. Plus `public extension LocalMovieStore { static func inMemory(initial: MovieStoreSnapshot = .empty, now: @escaping @Sendable () -> Date = Date.init) -> LocalMovieStore }`.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd $ROOT/MovieDemo/MovieStore && swift test 2>&1 | tail -3`
Expected: `Test run with 9 tests in 1 suite passed`.

- [ ] **Step 9: Commit**

```bash
git add MovieDemo/MovieStore
git commit -m "feat: add MovieStore actor with in-memory persistence"
```

---

### Task 2: File persistence, module registration, project wiring, `AppRouter`

**Files:**
- Create: `MovieDemo/MovieStore/Sources/MovieStore/FileMovieStorePersistence.swift`
- Create: `MovieDemo/MovieStore/Sources/MovieStore/MovieStoreModule.swift`
- Create: `MovieDemo/MovieStore/Tests/MovieStoreTests/FileMovieStorePersistenceTests.swift`
- Modify: `project.yml`
- Modify: `MovieDemo/AppRouter.swift` (`setupLocator` only)
- Modify: `MovieDemoTests/AppRouterTests.swift`

**Interfaces:**
- Consumes: `MovieStoreSnapshot`, `MovieStorePersistence`, `LocalMovieStore` from Task 1.
- Produces: `FileMovieStorePersistence(fileURL:)`, `FileMovieStorePersistence.applicationSupport()`, `MovieStoreModule.requiredKinds`, `MovieStoreModule.registerServices(in:)`, `Locator.Kind.movieStore`, `AnyLocatorKind.movieStore`.

- [ ] **Step 1: Write the failing persistence tests**

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd $ROOT/MovieDemo/MovieStore && swift test 2>&1 | grep -m2 'error:'`
Expected: `cannot find 'FileMovieStorePersistence' in scope`.

- [ ] **Step 3: Implement `FileMovieStorePersistence.swift`**

`public struct FileMovieStorePersistence: MovieStorePersistence { public let fileURL: URL }`. `load()`: if no file at `fileURL` return `.empty`; otherwise `try? JSONDecoder` with `.iso8601` dates, returning `.empty` on decode failure. `save(_:)`: create the parent directory with intermediates, encode with `.iso8601` dates and `.sortedKeys`, write with `.atomic`. `applicationSupport()`: `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]` + `MovieDemo/movie-store.json`.

- [ ] **Step 4: Implement `MovieStoreModule.swift`**

Same shape as `MovieDemo/APIClient/Sources/APIClient/APIClientModule.swift`: `requiredKinds = []`, `registerServices` registers `{ _ in LocalMovieStore(persistence: FileMovieStorePersistence.applicationSupport()) }`, `Locator.Kind` extension with id `"MovieStore"`, `AnyLocatorKind` extension via `.erased`.

- [ ] **Step 5: Run the package tests**

Run: `cd $ROOT/MovieDemo/MovieStore && swift test 2>&1 | tail -3`
Expected: `Test run with 13 tests in 2 suites passed`.

- [ ] **Step 6: Wire the package and extend the AppRouter test**

`project.yml`: add `MovieStore: { path: MovieDemo/MovieStore }` under `packages`, `"MovieStore/**"` to the app target excludes, `- package: MovieStore` to its dependencies, `- package: MovieStore/MovieStoreTests` to the scheme's test targets. Run `xcodegen generate`.

In `MovieDemoTests/AppRouterTests.swift`: `import MovieStore`; in `setupLocatorRegistersEverything` add `+ MovieStoreModule.requiredKinds` to `required` and `#expect(locator.isRegistered(.movieStore))`.

Run: `TEST -only-testing:MovieDemoTests` → Expected: one failure, `Expectation failed: locator.isRegistered(.movieStore)`.

- [ ] **Step 7: Register the module in `AppRouter.setupLocator`**

`import MovieStore`; add `MovieStoreModule.registerServices(in: locator)` after `AnalyticsClientModule` and `+ MovieStoreModule.requiredKinds` to `verify(allOf:)`.

Run: `TEST -only-testing:MovieDemoTests` → Expected: `Test run with 3 tests in 1 suite passed`.

- [ ] **Step 8: Commit**

```bash
git add MovieDemo/MovieStore project.yml MovieDemo/AppRouter.swift MovieDemoTests/AppRouterTests.swift
git commit -m "feat: persist MovieStore to a JSON file and register it in the locator"
```

---

### Task 3: `MovieUI` package: shared `MovieCell` and collection display attributes

**Files:**
- Create: `MovieDemo/MovieUI/Package.swift`
- Create: `MovieDemo/MovieUI/Sources/MovieUI/MovieCell.swift` (moved from `MovieDemo/MovieList/Sources/MovieList/View/MovieCell.swift`)
- Create: `MovieDemo/MovieUI/Sources/MovieUI/MovieCollection+Display.swift`
- Create: `MovieDemo/MovieUI/Tests/MovieUITests/MovieCollectionDisplayTests.swift`
- Delete: `MovieDemo/MovieList/Sources/MovieList/View/MovieCell.swift`
- Modify: `MovieDemo/MovieList/Package.swift`, `MovieDemo/MovieList/Sources/MovieList/View/MovieListView.swift` (add `import MovieUI`)
- Modify: `project.yml`

**Interfaces:**
- Consumes: `MovieCollection` from Task 1.
- Produces: `public struct MovieCell: View { public init(movie: Movie) }`; `public extension MovieCollection { var title: String; var systemImage: String; var selectedSystemImage: String }`.

- [ ] **Step 1: Create the package and the failing test**

`Package.swift`: name `MovieUI`, product `MovieUI`, dependencies `../Models`, `../MovieStore`; target `MovieUI` (deps `Models`, `MovieStore`); test target `MovieUITests` (dep `MovieUI`).

```swift
import Testing
import MovieStore
@testable import MovieUI

@Suite("MovieCollection display")
struct MovieCollectionDisplayTests {

  @Test func titlesSymbolsAndSelectedSymbols() {
    let all = MovieCollection.allCases
    #expect(all.map(\.title) == ["Watchlist", "Seen", "Favourites"])
    #expect(all.map(\.systemImage) == ["bookmark", "checkmark.circle", "heart"])
    #expect(all.map(\.selectedSystemImage) == ["bookmark.fill", "checkmark.circle.fill", "heart.fill"])
  }
}
```

`project.yml`: add `MovieUI` package, exclude, app dependency, and `- package: MovieUI/MovieUITests` to the scheme. `xcodegen generate`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `TEST -only-testing:MovieUITests 2>&1 | grep -m1 'error:'`
Expected: target has no sources or `value of type 'MovieCollection' has no member 'title'`.

- [ ] **Step 3: Implement `MovieCollection+Display.swift` and move `MovieCell`**

The extension with the three computed properties. `git mv` the cell file into `MovieUI`, make the struct and its `init(movie:)` `public`; body unchanged.

- [ ] **Step 4: Point `MovieList` at `MovieUI`**

`MovieList/Package.swift`: add `.package(path: "../MovieUI")` and `"MovieUI"` to the target dependencies. `MovieListView.swift`: `import MovieUI`.

- [ ] **Step 5: Run the affected tests**

Run: `TEST -only-testing:MovieUITests -only-testing:MovieListTests 2>&1 | grep -E 'Test run with|\*\* TEST'`
Expected: `1 test in 1 suite passed`, `20 tests in 3 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add project.yml MovieDemo/MovieUI MovieDemo/MovieList/Package.swift MovieDemo/MovieList/Sources/MovieList/View
git commit -m "feat: extract MovieCell and collection display into MovieUI"
```

---

### Task 4: `MovieDetail` repository and view model toggles

**Files:**
- Modify: `MovieDemo/MovieDetail/Package.swift` (add `../MovieStore`, `../MovieUI`; test target adds `.product(name: "MovieStoreTesting", package: "MovieStore")`)
- Modify: `MovieDemo/MovieDetail/Sources/MovieDetail/Repository/MovieDetailRepository.swift`
- Modify: `MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailViewModel.swift` (convert to 2 spaces first, see Global Constraints)
- Modify: `MovieDemo/MovieDetail/Tests/MovieDetailTests/MovieDetailViewModelTests.swift`

**Interfaces:**
- Consumes: `MovieStore`, `MovieCollection`, `MovieStoreChange`, `LocalMovieStore.inMemory()`, `InMemoryMovieStorePersistence` from Tasks 1–2.
- Produces: `MovieDetailRepository` with the five methods in the spec; `MovieDetailRepositoryImpl(apiClient:store:)`; on the view model `collections`, `collectionsTask`, `observationTask`, `isIn(_:)`, `toggle(_:)`.

- [ ] **Step 1: Update the test harness and write the failing tests**

Change `makeViewModel` to take a store: `makeViewModel(mock:spy:store: any MovieStore = LocalMovieStore.inMemory())` building `MovieDetailRepositoryImpl(apiClient: mock, store: store)`. Existing tests keep passing with the default. Add:

```swift
  @Test func toggleAddsThenRemovesAndTracks() async throws {
    let store = LocalMovieStore.inMemory()
    let spy = SpyAnalyticsClient()
    let viewModel = makeViewModel(mock: MockAPIClient(), spy: spy, store: store)

    viewModel.toggle(.watchlist)
    #expect(viewModel.isIn(.watchlist))             // optimistic
    await viewModel.collectionsTask?.value
    #expect(try await store.collections(containing: 7) == [.watchlist])

    viewModel.toggle(.watchlist)
    #expect(!viewModel.isIn(.watchlist))
    await viewModel.collectionsTask?.value
    #expect(try await store.collections(containing: 7).isEmpty)

    let events = spy.events(named: "movie_collection_toggled")
    #expect(events.map { $0.parameters["action"] } == ["added", "removed"])
    #expect(events.allSatisfy { $0.parameters["movie_id"] == "7" && $0.parameters["collection"] == "watchlist" })
  }

  @Test func onAppearLoadsExistingCollections() async throws {
    let store = LocalMovieStore.inMemory()
    try await store.add(seed, to: .favourites)
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)

    viewModel.onAppear()
    await viewModel.collectionsTask?.value

    #expect(viewModel.collections == [.favourites])
  }

  @Test func externalChangeForThisMovieUpdatesCollections() async throws {
    let store = LocalMovieStore.inMemory()
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)
    viewModel.onAppear()
    await viewModel.collectionsTask?.value
    await Task.yield()   // let the observation task reach its first await

    try await store.add(seed, to: .seen)
    for _ in 0..<50 where !viewModel.isIn(.seen) { await Task.yield() }

    #expect(viewModel.isIn(.seen))
  }

  @Test func changeForOtherMovieIsIgnored() async throws {
    let store = LocalMovieStore.inMemory()
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)
    viewModel.onAppear()
    await viewModel.collectionsTask?.value
    await Task.yield()

    try await store.add(Movie(id: 99, title: "Other"), to: .seen)
    try await store.add(seed, to: .watchlist)   // sentinel so we know the stream was processed
    for _ in 0..<50 where !viewModel.isIn(.watchlist) { await Task.yield() }

    #expect(viewModel.collections == [.watchlist])
  }

  @Test func failedToggleRevertsAndTracksError() async throws {
    struct Failing: MovieStorePersistence {
      func load() async throws -> MovieStoreSnapshot { .empty }
      func save(_ snapshot: MovieStoreSnapshot) async throws { throw CocoaError(.fileWriteNoPermission) }
    }
    let spy = SpyAnalyticsClient()
    let viewModel = makeViewModel(mock: MockAPIClient(), spy: spy, store: LocalMovieStore(persistence: Failing()))

    viewModel.toggle(.favourites)
    await viewModel.collectionsTask?.value

    #expect(!viewModel.isIn(.favourites))
    #expect(spy.events(named: "error_shown").first?.parameters["screen"] == "movie_detail")
  }

  @Test func deallocatedViewModelEndsSubscription() async throws {
    let store = LocalMovieStore.inMemory()
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    var viewModel: MovieDetailViewModel? = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)
    viewModel?.onAppear()
    await viewModel?.collectionsTask?.value
    var attempts = 0
    while await store.subscriberCount == 0, attempts < 50 { attempts += 1; await Task.yield() }
    #expect(await store.subscriberCount == 1)

    viewModel = nil
    attempts = 0
    while await store.subscriberCount != 0, attempts < 50 { attempts += 1; await Task.yield() }
    #expect(await store.subscriberCount == 0)
  }
```

Add `import MovieStore` and `import MovieStoreTesting` to the test file. `subscriberCount` is internal to `MovieStore`; make it `public` in `LocalMovieStore` for this test (one-line change in Task 1's file, commit it here).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST -only-testing:MovieDetailTests 2>&1 | grep -m3 'error:'`
Expected: `no such module 'MovieStore'` or `extra argument 'store' in call`.

- [ ] **Step 3: Extend the repository**

Add the four store methods to the protocol and `MovieDetailRepositoryImpl(apiClient:store:)` forwarding each to `store`.

- [ ] **Step 4: Extend the view model**

Convert the file to 2-space indentation. `import MovieStore`. Add `private(set) var collections: Set<MovieCollection> = []`, `private(set) var collectionsTask: Task<Void, Never>?`, `private(set) var observationTask: Task<Void, Never>?`, `@ObservationIgnored private var isObserving = false`. `isIn(_:)` reads `collections`. `onAppear()`: after the existing `load()` guard logic, always call `loadCollections()` if `collectionsTask == nil` and `startObserving()` if not yet observing (both independent of `state`). `toggle(_:)`: decide `action` from `isIn`, flip `collections` immediately, track the event, then `collectionsTask = Task { do { add or remove } catch { flip back; track error_shown with screen movie_detail and the error's description } }`. `startObserving()`: `observationTask = Task { [weak self, movieID = movie.id] in guard let stream = await self?.repository.changes() else { return }; for await change in stream where change.movieID == movieID { guard let self else { return }; apply(change) } }`, where `apply` inserts or removes the collection. `deinit { observationTask?.cancel() }`.

The `[weak self]` plus per-iteration `guard let self` is the point of the exercise: between iterations the task holds no strong reference, so the view model can deallocate, its `deinit` cancels the task, and the stream's `onTermination` removes the continuation from the actor.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TEST -only-testing:MovieDetailTests 2>&1 | grep -E '✘|Test run with|\*\* TEST'`
Expected: `Test run with 11 tests in 2 suites passed` (4 existing view model tests + 6 new, plus the module test) and `** TEST SUCCEEDED **`. The module test still passes because the factory has not changed yet.

- [ ] **Step 6: Commit**

```bash
git add MovieDemo/MovieDetail/Package.swift MovieDemo/MovieDetail/Sources/MovieDetail/Repository/MovieDetailRepository.swift MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailViewModel.swift MovieDemo/MovieDetail/Tests/MovieDetailTests/MovieDetailViewModelTests.swift MovieDemo/MovieStore/Sources/MovieStore/LocalMovieStore.swift
git commit -m "feat: detail view model toggles collections and observes the store"
```

---

### Task 5: `MovieDetail` screen: bar buttons, hero to the top, wiring

**Files:**
- Modify: `MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailViewController.swift`
- Modify: `MovieDemo/MovieDetail/Sources/MovieDetail/View/MovieDetailView.swift`
- Modify: `MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailFactory.swift`
- Modify: `MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailProvider.swift`
- Modify: `MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailModule.swift`
- Modify: `MovieDemo/MovieDetail/Tests/MovieDetailTests/MovieDetailModuleTests.swift`

**Interfaces:**
- Consumes: view model API from Task 4; `MovieCollection` display from Task 3.
- Produces: `MovieDetailModule.requiredKinds = [.apiClient, .analyticsClient, .movieStore]`; `MovieDetailFactory.makeMovieDetailViewController(movie:apiClient:store:analytics:)`.

- [ ] **Step 1: Rewrite the module test**

```swift
import Testing
import UIKit
import Locator
import Models
import MovieStore
import MovieStoreTesting
import APIClientTesting
import AnalyticsClientTesting
@testable import MovieDetail

@Suite("MovieDetailModule")
@MainActor
struct MovieDetailModuleTests {

  @Test func moduleRegistersProviderAndProviderBuildsViewController() {
    let locator = Locator()
    locator.register(.apiClient, MockAPIClient())
    locator.register(.analyticsClient, SpyAnalyticsClient())
    locator.register(.movieStore, LocalMovieStore.inMemory())

    MovieDetailModule.registerServices(in: locator)

    #expect(MovieDetailModule.requiredKinds.contains(.movieStore))
    #expect(locator.missing(from: MovieDetailModule.requiredKinds).isEmpty)

    let viewController = locator.resolve(.movieDetailProvider).movieDetailViewController(movie: Movie(id: 1, title: "Title"))
    viewController.loadViewIfNeeded()
    #expect(viewController is MovieDetailViewController)
    #expect(viewController.title == nil)
    let items = viewController.navigationItem.rightBarButtonItems ?? []
    #expect(items.count == 3)
    #expect(items.map(\.accessibilityLabel) == ["Watchlist", "Seen", "Favourites"])
    #expect(items.allSatisfy { $0.image != nil })   // outline vs filled is covered by the view model's isIn tests
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `TEST -only-testing:MovieDetailTests 2>&1 | grep -E -m3 'error:|Expectation failed'`
Expected: `Expectation failed: (MovieDetailModule.requiredKinds ...).contains(.movieStore)` or a build error on `.movieStore` being unregistered at resolve time.

- [ ] **Step 3: Wire the store through module, provider and factory**

`MovieDetailModule.requiredKinds = [.apiClient, .analyticsClient, .movieStore]`. Provider: `import MovieStore`, resolve `.movieStore` and pass `store:`. Factory: new signature from Interfaces, builds `MovieDetailRepositoryImpl(apiClient: apiClient, store: store)`.

- [ ] **Step 4: Rebuild the controller's navigation item**

`import MovieStore`, `import MovieUI`. In `bind`: do not set `title`. In `viewDidLoad`: `navigationItem.largeTitleDisplayMode = .never`; `let edge = UINavigationBarAppearance(); edge.configureWithTransparentBackground(); navigationItem.scrollEdgeAppearance = edge`; build `rightBarButtonItems` as one `UIBarButtonItem(image:style:target:action:)` per `MovieCollection.allCases` with `accessibilityLabel = collection.title` and `tag = index`; then start `observeCollections()`. `observeCollections()` uses `withObservationTracking { render() } onChange: { Task { @MainActor [weak self] in self?.observeCollections() } }` where `render()` sets each item's `image` to `UIImage(systemName: viewModel.isIn(c) ? c.selectedSystemImage : c.systemImage)`. The action handler maps `sender.tag` to the collection and calls `viewModel.toggle`.

- [ ] **Step 5: Move the hero to the top**

In `MovieDetailView`: apply `.ignoresSafeArea(edges: .top)` to the `ScrollView`; hero `.frame(height: 420)`. Title and the rest already sit below the image.

- [ ] **Step 6: Run the module's tests**

Run: `TEST -only-testing:MovieDetailTests 2>&1 | grep -E '✘|Test run with|\*\* TEST'`
Expected: `Test run with 11 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add MovieDemo/MovieDetail/Sources MovieDemo/MovieDetail/Tests/MovieDetailTests/MovieDetailModuleTests.swift
git commit -m "feat: collection toggles and full-bleed hero on the detail screen"
```

---

### Task 6: `MyMovies` on `MovieCollection`, real repository

**Files:**
- Modify: `MovieDemo/MyMovies/Package.swift` (add `../MovieStore`, `../MovieUI`, `../MovieDetail`; test target adds `MovieStoreTesting`)
- Delete: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesSection.swift`, `MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesSectionTests.swift`
- Modify: `MovieDemo/MyMovies/Sources/MyMovies/Repository/MyMoviesRepository.swift`
- Modify: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesViewModel.swift`, `MyMoviesRouter.swift`, `View/MyMoviesView.swift`, `Previews/MyMoviesView_Previews.swift`, `MyMoviesFactory.swift` (compile only; full rewiring in Task 8)
- Modify: `MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesRepositoryTests.swift`, `MyMoviesViewModelTests.swift`, `Support/SpyMyMoviesRouter.swift`

**Interfaces:**
- Consumes: `MovieCollection`, `StoredMovie`, `MovieStoreChange`, `MovieStore`, `LocalMovieStore.inMemory()`; `MovieCollection.title/systemImage` from Task 3.
- Produces: `MyMoviesRepository` with `movies(in:)`, `remove(movieID:from:)`, `changes()`; `MyMoviesRepositoryImpl(store:)`; `MyMoviesRouter.routeTo(collection:)` (the `routeToMovieDetails` method arrives in Task 8); `MyMoviesViewModel.sections: [MovieCollection]`, `sectionTapped(_ collection: MovieCollection)`.

- [ ] **Step 1: Rewrite the repository and view model tests**

`MyMoviesRepositoryTests.swift`:

```swift
import Testing
import Models
import MovieStore
import MovieStoreTesting
@testable import MyMovies

@Suite("MyMoviesRepository")
struct MyMoviesRepositoryTests {

  @Test func forwardsToTheStore() async throws {
    let store = LocalMovieStore.inMemory()
    let repository = MyMoviesRepositoryImpl(store: store)
    try await store.add(Movie(id: 1, title: "One"), to: .watchlist)

    #expect(try await repository.movies(in: .watchlist).map(\.id) == [1])
    try await repository.remove(movieID: 1, from: .watchlist)
    #expect(try await repository.movies(in: .watchlist).isEmpty)
  }
}
```

`MyMoviesViewModelTests.swift`: replace `MyMoviesSection` with `MovieCollection`, `NoOpMyMoviesRepository()` with `MyMoviesRepositoryImpl(store: LocalMovieStore.inMemory())`, `section.analyticsName` with `section.rawValue`; add `import MovieStore`, `import MovieStoreTesting`. `SpyMyMoviesRouter`: `routed: [MovieCollection]`, `routeTo(collection:)`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST -only-testing:MyMoviesTests 2>&1 | grep -m3 'error:'`
Expected: `no such module 'MovieStore'` or `cannot find 'MyMoviesRepositoryImpl' in scope`.

- [ ] **Step 3: Make the module compile on `MovieCollection`**

Delete `MyMoviesSection.swift` and its test. `Package.swift` dependencies per Files. Repository: the three-method protocol from the spec and `MyMoviesRepositoryImpl(store:)`; delete `NoOpMyMoviesRepository`. View model: `let sections = MovieCollection.allCases`, `sectionTapped(_ collection: MovieCollection)` with `["section": collection.rawValue]`, `router.routeTo(collection:)`. Router protocol: `routeTo(collection:)`, body still empty. View and previews: `import MovieUI`, use `collection.title` / `collection.systemImage`; previews build `MyMoviesRepositoryImpl(store: LocalMovieStore.inMemory())` (`import MovieStoreTesting` under `#if DEBUG` is acceptable only if `MovieStoreTesting` is a dependency of the main target; it is not, so previews instead use a private `PreviewPersistence: MovieStorePersistence` returning `.empty`). Factory: `makeMyMoviesViewController(store: any MovieStore, analytics:)` building the real repository; provider resolves `.movieStore`; module `requiredKinds = [.analyticsClient, .movieStore]` (Task 8 adds the detail provider).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `TEST -only-testing:MyMoviesTests 2>&1 | grep -E '✘|error:|Test run with|\*\* TEST'`
Expected: the module test fails on `missing(from:)` because `.movieStore` is not registered in it. Add `locator.register(.movieStore, LocalMovieStore.inMemory())` (and the two imports) to `MyMoviesModuleTests.swift`; rerun. Expected: `Test run with 6 tests in 3 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add -u MovieDemo/MyMovies
git add MovieDemo/MyMovies
git commit -m "refactor: MyMovies uses MovieCollection and a store-backed repository"
```

(`git add -u` stages the two deletions by path; both commands are scoped to the package.)

---

### Task 7: Collection list screen: view model, view, controller

**Files:**
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MovieCollectionViewModel.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MovieCollectionViewController.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/View/MovieCollectionView.swift`
- Create: `MovieDemo/MyMovies/Tests/MyMoviesTests/MovieCollectionViewModelTests.swift`
- Modify: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesRouter.swift` (add `routeToMovieDetails(movie:)` to the protocol; empty body for now), `Tests/MyMoviesTests/Support/SpyMyMoviesRouter.swift` (record `detailMovies: [Movie]`)

**Interfaces:**
- Consumes: `MyMoviesRepository` from Task 6; `MovieCell` from Task 3.
- Produces: `MovieCollectionViewModel(collection:repository:router:analytics:)` with `movies`, `isLoading`, `errorMessage`, `loadTask`, `observationTask`, `emptyMessage`, `onAppear()`, `reload()`, `remove(_:)`, `movieWasTapped(_:)`; `MovieCollectionViewController: ViewModelBindable`; `MyMoviesRouter.routeToMovieDetails(movie:)`.

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import Models
import AnalyticsClient
import AnalyticsClientTesting
import MovieStore
import MovieStoreTesting
@testable import MyMovies

@Suite("MovieCollectionViewModel")
@MainActor
struct MovieCollectionViewModelTests {

  @MainActor
  private struct Harness {
    let store = LocalMovieStore.inMemory()
    let spy = SpyAnalyticsClient()
    let router = SpyMyMoviesRouter()
    let viewModel: MovieCollectionViewModel

    init(collection: MovieCollection = .watchlist) {
      viewModel = MovieCollectionViewModel(
        collection: collection,
        repository: MyMoviesRepositoryImpl(store: store),
        router: router,
        analytics: spy
      )
    }

    func settle() async {
      await viewModel.loadTask?.value
    }
  }

  @Test func onAppearLoadsNewestFirstAndTracksOnce() async throws {
    let h = Harness()
    try await h.store.add(Movie(id: 1, title: "One"), to: .watchlist)
    try await h.store.add(Movie(id: 2, title: "Two"), to: .watchlist)

    h.viewModel.onAppear()
    await h.settle()
    h.viewModel.onAppear()
    await h.settle()

    #expect(h.viewModel.movies.map(\.id) == [2, 1])
    #expect(h.viewModel.isLoading == false)
    #expect(h.spy.events(named: "movie_collection_viewed") == [AnalyticsEvent(name: "movie_collection_viewed", parameters: ["collection": "watchlist"])])
  }

  @Test func removeTracksAndListRefreshesThroughTheStream() async throws {
    let h = Harness()
    let movie = Movie(id: 1, title: "One")
    try await h.store.add(movie, to: .watchlist)
    try await h.store.add(movie, to: .seen)
    h.viewModel.onAppear()
    await h.settle()
    await Task.yield()

    h.viewModel.remove(movie)
    for _ in 0..<50 where !h.viewModel.movies.isEmpty { await Task.yield(); await h.settle() }

    #expect(h.viewModel.movies.isEmpty)
    #expect(try await h.store.collections(containing: 1) == [.seen])
    #expect(h.spy.events(named: "movie_collection_removed").first?.parameters == ["movie_id": "1", "collection": "watchlist"])
  }

  @Test func externalAddShowsUp() async throws {
    let h = Harness(collection: .favourites)
    h.viewModel.onAppear()
    await h.settle()
    await Task.yield()

    try await h.store.add(Movie(id: 5, title: "Five"), to: .favourites)
    for _ in 0..<50 where h.viewModel.movies.isEmpty { await Task.yield(); await h.settle() }

    #expect(h.viewModel.movies.map(\.id) == [5])
  }

  @Test func tappingRoutesAndTracks() {
    let h = Harness()
    let movie = Movie(id: 3, title: "Three")
    h.viewModel.movieWasTapped(movie)
    #expect(h.router.detailMovies == [movie])
    #expect(h.spy.events(named: "movie_selected") == [AnalyticsEvent(name: "movie_selected", parameters: ["movie_id": "3"])])
  }

  @Test(arguments: zip(MovieCollection.allCases, ["Nothing in your watchlist yet", "Nothing marked as seen yet", "No favourites yet"]))
  func emptyMessagePerCollection(collection: MovieCollection, message: String) {
    #expect(Harness(collection: collection).viewModel.emptyMessage == message)
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST -only-testing:MyMoviesTests 2>&1 | grep -m2 'error:'`
Expected: `cannot find 'MovieCollectionViewModel' in scope`.

- [ ] **Step 3: Implement `MovieCollectionViewModel.swift`**

`@MainActor @Observable final class MovieCollectionViewModel: ViewModel` with `typealias ViewControllerType = MovieCollectionViewController`. Stored: `let collection: MovieCollection`; `private(set) var movies: [StoredMovie] = []`, `isLoading = false`, `errorMessage: String?`, `loadTask`, `observationTask`; `@ObservationIgnored` repository, router, analytics, `hasAppeared`. `emptyMessage` switches on `collection` with the exact copy. `onAppear()`: first time tracks `movie_collection_viewed` and calls `startObserving()`; every time calls `reload()` if `loadTask == nil`. `reload()`: `isLoading = true`, `loadTask = Task { defer { isLoading = false; loadTask = nil }; do { movies = try await repository.movies(in: collection) } catch { errorMessage = … } }`. `remove(_:)`: track, then `Task { try? await repository.remove(movieID:from:) }`; no local mutation. `movieWasTapped`: track `movie_selected`, `router.routeToMovieDetails(movie:)`. `startObserving()`: same `[weak self]` `for await` shape as the detail view model, filtered on `change.collection == collection`, calling `reload()` for each. `deinit` cancels `observationTask`.

- [ ] **Step 4: Implement the controller and view**

`MovieCollectionViewController`: copy `MyMoviesViewController`'s shape; `bind` sets `title = viewModel.collection.title` and `navigationItem.largeTitleDisplayMode = .never`; `viewWillAppear → onAppear`. `MovieCollectionView`: `import MovieUI`; if `errorMessage` and `movies.isEmpty` → text + Retry calling `reload()`; else if `movies.isEmpty && !isLoading` → `ContentUnavailableView(viewModel.emptyMessage, systemImage: viewModel.collection.systemImage)`; else `List(viewModel.movies) { stored in Button { viewModel.movieWasTapped(stored.movie) } label: { MovieCell(movie: stored.movie) }.buttonStyle(.plain).swipeActions { Button("Remove", role: .destructive) { viewModel.remove(stored.movie) } } }.listStyle(.plain)`; `.overlay { if viewModel.isLoading && viewModel.movies.isEmpty { ProgressView() } }`.

- [ ] **Step 5: Extend the router protocol and spy**

Add `@MainActor func routeToMovieDetails(movie: Movie)` to `MyMoviesRouter`; empty body in `MyMoviesRouterImpl` for now; spy records into `detailMovies`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `TEST -only-testing:MyMoviesTests 2>&1 | grep -E '✘|Test run with|\*\* TEST'`
Expected: `Test run with 11 tests in 4 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add MovieDemo/MyMovies/Sources MovieDemo/MyMovies/Tests
git commit -m "feat: collection list screen with live updates and swipe to remove"
```

---

### Task 8: Routing, factory, module wiring, README, full verification

**Files:**
- Modify: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesRouter.swift`, `MyMoviesFactory.swift`, `MyMoviesProvider.swift`, `MyMoviesModule.swift`
- Create: `MovieDemo/MyMovies/Tests/MyMoviesTests/Support/StubMovieDetailProvider.swift` (copy of the one in `MovieListTests`)
- Modify: `MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesModuleTests.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above; `MovieDetailProvider` from `MovieDetail`.
- Produces: `MyMoviesModule.requiredKinds = [.analyticsClient, .movieStore, .movieDetailProvider]`; `MyMoviesRouterImpl(viewController:movieDetailProvider:makeCollectionScreen:)`; the two factory methods from the spec.

- [ ] **Step 1: Extend the module test and write a routing test**

In `MyMoviesModuleTests`: register `StubMovieDetailProvider()` for `.movieDetailProvider`; assert `MyMoviesModule.requiredKinds == [.analyticsClient, .movieStore, .movieDetailProvider]`. Add:

```swift
  @Test func routerPushesCollectionAndDetail() {
    let navigationController = UINavigationController(rootViewController: UIViewController())
    let host = navigationController.viewControllers[0]
    let router = MyMoviesRouterImpl(
      viewController: host,
      movieDetailProvider: StubMovieDetailProvider(),
      makeCollectionScreen: { collection in
        let vc = UIViewController(); vc.title = collection.title; return vc
      }
    )

    router.routeTo(collection: .seen)
    #expect(navigationController.viewControllers.last?.title == "Seen")

    router.routeToMovieDetails(movie: Movie(id: 1, title: "Detail"))
    #expect(navigationController.viewControllers.last?.title == "Detail")
  }
```

(`pushViewController(animated: false)` is not required; without a window UIKit updates `viewControllers` synchronously for `animated: true` as well. If the assertion is flaky, pass `animated: false` in the router when `viewController?.view.window == nil`; prefer the simple path first.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST -only-testing:MyMoviesTests 2>&1 | grep -m3 -E 'error:|Expectation failed'`
Expected: `extra arguments at positions #2, #3 in call` on the router init, or the `requiredKinds` expectation failing.

- [ ] **Step 3: Implement routing and wiring**

`MyMoviesRouterImpl` per Interfaces: `routeTo(collection:)` pushes `makeCollectionScreen(collection)`; `routeToMovieDetails(movie:)` pushes `movieDetailProvider.movieDetailViewController(movie:)`; both via `viewController?.navigationController`. Factory: `makeMyMoviesViewController(store:analytics:movieDetailProvider:)` builds the hub with a router whose `makeCollectionScreen` calls `self.makeMovieCollectionViewController(collection:store:analytics:movieDetailProvider:)`; that second method builds `MovieCollectionViewController`, `MyMoviesRepositoryImpl(store:)`, `MyMoviesRouterImpl` (same closure), `MovieCollectionViewModel`, binds. Provider resolves `.analyticsClient`, `.movieStore`, `.movieDetailProvider`. Module `requiredKinds` per Interfaces.

- [ ] **Step 4: Run the module tests**

Run: `TEST -only-testing:MyMoviesTests 2>&1 | grep -E '✘|Test run with|\*\* TEST'`
Expected: `Test run with 12 tests in 4 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Update the README**

Module table: add `` `MovieStore` | Local collections (watchlist, seen, favourites): `MovieStore` protocol, `LocalMovieStore` actor persisting a JSON snapshot, `AsyncStream` of changes. `MovieStoreTesting` ships an in-memory variant. `` and `` `MovieUI` | Shared SwiftUI pieces: `MovieCell`, collection titles and symbols. ``. Update the `MyMovies` row: "Hub with three sections and a per-collection list with swipe to remove and live updates." Dependency graph: add `MovieStore` under `MovieDetail` and `MyMovies`, and `MovieUI` under `MovieList`, `MovieDetail`, `MyMovies`. Intro: "My Movies, where the user's watchlist, seen and favourite movies live, stored on device." Design docs: add this spec and plan.

- [ ] **Step 6: Full verification**

Run: `TEST 2>&1 | grep -E '✘|Test run with|\*\* TEST' | sort | uniq -c`
Expected: `** TEST SUCCEEDED **`; per-target counts: MovieDemoTests 3, Locator 7, Protocols 1, Models 5, APIClient 13, AnalyticsClient 4, MovieStore 13, MovieUI 1, MovieDetail 11, MovieList 20, MyMovies 12.
Run: `xcodebuild -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' build 2>&1 | grep 'warning:' | grep -v appintentsmetadataprocessor | wc -l` → `0`.
Run: `cd $ROOT/MovieDemo/MovieStore && swift test 2>&1 | tail -1` → `13 tests in 2 suites passed`.
Run: `git status --short` → only `README.md` and the MyMovies files from this task.

- [ ] **Step 7: Commit**

```bash
git add MovieDemo/MyMovies/Sources MovieDemo/MyMovies/Tests README.md
git commit -m "feat: wire My Movies collections end to end"
```
