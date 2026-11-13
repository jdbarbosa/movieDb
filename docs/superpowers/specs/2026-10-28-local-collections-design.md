# MovieDemo – Local Collections: Watchlist, Seen, Favourites

Date: 2026-10-28
Status: approved by owner in conversation (2026-10-28); owner opted out of further questions, remaining calls are the builder's and marked as such
Extends: `2026-10-23-moviedemo-architecture-design.md` and `2026-10-28-tabs-and-my-movies-design.md`.

## Intent

Give the My Movies tab real content. A user marks a movie as Watchlist, Seen
or Favourite from the detail screen, and each section of My Movies lists
what they marked. Everything is stored on the device; the TMDB API has no
such data.

The owner's two goals for this project decide the shape: showcase the
modular architecture, and learn the essentials of Swift concurrency. So the
store is an `actor`, change notification is an `AsyncStream`, view models
consume it with `for await`, and all of that sits behind a module boundary
the features cannot see through.

## Goals

- A `MovieStore` leaf module: protocol, an `actor` implementation that
  persists a Codable JSON file, a `MovieStoreTesting` product with an
  in-memory variant, and a locator registration like `APIClient`.
- A `MovieUI` shared module holding `MovieCell` and the display attributes
  of each collection, so `MovieList`, `MovieDetail` and `MyMovies` render
  movies the same way without depending on each other.
- Detail screen: hero image runs to the top of the screen under a
  transparent navigation bar, the title moves below the image, and three
  toggle buttons sit top right. Toggling persists immediately.
- My Movies: tapping a section pushes a list of that section's movies,
  newest first, with swipe to remove and tap through to detail. Lists update
  live when the detail screen on the other tab changes something.
- Same quality bar: Swift 6 strict concurrency, zero warnings, tests at the
  store, repository, view model and module levels.

## Non-goals

- Reviews, ratings, notes. Any sync, iCloud or backend.
- Marking from the Discover list rows. Only the detail screen toggles.
- Counts or badges on the My Movies hub buttons.
- Remembering the selected tab or scroll positions.
- A migration story for the JSON file. The first version writes version 1
  and the loader treats an unreadable file as empty.

## Anti-goals

- Features importing `FileManager` or knowing where the file lives. Only
  `MovieStore` touches disk.
- `MyMovies` importing `MovieList`. The shared row goes in `MovieUI`.
- Locks or `DispatchQueue` for serialisation. The actor is the point.
- `@unchecked Sendable` or `nonisolated(unsafe)` anywhere.
- An `AsyncStream` whose continuation is never released. Subscriptions end
  when the subscriber's task is cancelled, and the store drops them.

## Constraints

- All constraints from the two earlier specs. XcodeGen project, 2-space
  indentation, tests through `xcodebuild test -scheme MovieDemo` on the
  simulator; UIKit-free packages also run under `swift test`.
- `MovieStore` is UIKit-free: platforms `iOS 17` and `macOS 14`, so its
  tests run with `swift test`.
- The owner keeps a hard-coded API key in `AppRouter.swift` on purpose. Do
  not touch that line.

## Decisions the owner made

- Local storage, on device only, as a Codable JSON file behind an actor.
- Three independent flags per movie. Marking Seen does not touch Watchlist.
- Detail screen: three buttons top right; title under the hero image; the
  image takes the space up to the top.
- Each My Movies section is a plain list of the movies in it.
- A shared `MovieUI` package for the row.
- Design polish is not a priority.

## Decisions made by the builder (Claude)

- **Store a snapshot of the movie**, not just its id, with the date it was
  added. Lists render offline and sort newest first without an API call.
- **Change events name what changed** (`movieID`, `collection`, added or
  removed). Consumers filter the stream and re-query, which is the simplest
  honest pattern and shows filtering a stream.
- **`changes()` is an `async` method on the protocol**, not a property. On
  the actor that means the continuation is registered inside actor
  isolation with no cross-isolation dance. The stream finishes and the store
  forgets the continuation when the consumer's task is cancelled.
- **Persistence is a strategy protocol** so one actor serves both the file
  and the in-memory test variant. `LocalMovieStore(persistence:)` holds the
  logic; `FileMovieStorePersistence` and the testing product's
  `InMemoryMovieStorePersistence` only load and save a snapshot.
- **Add is idempotent and quiet.** Adding a movie already in a collection
  keeps its original `addedAt`, writes nothing and emits nothing. Removing an
  absent movie is the same.
- **Writes happen after every mutation**, atomically, inside the actor.
  Small data, no batching.
- **Collection display attributes live in `MovieUI`**, as an extension on
  `MovieCollection`: title, symbol, filled symbol. The storage module stays
  free of UI strings.
- **`MyMoviesSection` is deleted.** `MovieCollection` from `MovieStore` is
  the one enum; `MyMovies` uses `rawValue` for analytics.
- **The section screen lives inside `MyMovies`** as a second screen built by
  the same factory. The hub's router pushes it through a closure the factory
  supplies, and the section screen's router pushes detail through the
  `MovieDetail` provider.
- **Detail navigation bar**: `title` is `nil`, the scroll-edge appearance is
  transparent so the hero shows under the bar, and the standard appearance
  stays default so the bar turns opaque once scrolled. The three buttons are
  `UIBarButtonItem`s updated from the view model through
  `withObservationTracking`, which is how UIKit observes an `@Observable`
  model on iOS 17.
- **Optimistic toggles.** The view model flips the flag immediately, then
  persists. On failure it flips back and tracks `error_shown`.
- **Live updates in view models** use one owned `Task` running
  `for await` over the repository's stream, holding `self` weakly between
  iterations and cancelled in `deinit`. A view model that is deallocated
  ends its subscription without any explicit teardown call.
- **Analytics**: `movie_collection_toggled` with `movie_id`, `collection`,
  `action` (`added`/`removed`); `movie_collection_viewed` with `collection`;
  `movie_collection_removed` with `movie_id`, `collection`; the section list
  reuses `movie_selected` with `movie_id`. The hub keeps
  `my_movies_section_tapped`.
- **Empty copy**: "Nothing in your watchlist yet", "Nothing marked as seen
  yet", "No favourites yet".
- **File location**: Application Support/`MovieDemo`/`movie-store.json`.
  The directory is created on first save. A missing file loads as empty; an
  unreadable one also loads as empty, so a corrupt file never blocks launch.

## Repository layout (additions and moves)

```
MovieDemo/MovieStore/
  Package.swift                       products: MovieStore, MovieStoreTesting; platforms iOS 17, macOS 14
  Sources/MovieStore/
    MovieCollection.swift             enum + StoredMovie + MovieStoreChange + MovieStoreSnapshot
    MovieStore.swift                  protocol + MovieStorePersistence protocol
    LocalMovieStore.swift             actor
    FileMovieStorePersistence.swift
    MovieStoreModule.swift            registration + Kind
  Sources/MovieStoreTesting/
    InMemoryMovieStorePersistence.swift   records saves; LocalMovieStore.inMemory(initial:)
  Tests/MovieStoreTests/
    LocalMovieStoreTests.swift
    FileMovieStorePersistenceTests.swift

MovieDemo/MovieUI/
  Package.swift                       depends on Models, MovieStore; platforms iOS 17
  Sources/MovieUI/MovieCell.swift     moved from MovieList, made public
  Sources/MovieUI/MovieCollection+Display.swift
  Tests/MovieUITests/MovieCollectionDisplayTests.swift

MovieDemo/MovieDetail/                + MovieStore, MovieUI deps; repository, view model, view, controller, factory, provider, module change
MovieDemo/MyMovies/                   + MovieStore, MovieUI, MovieDetail deps; MyMoviesSection deleted; adds
  Sources/MyMovies/MovieCollectionViewController.swift
  Sources/MyMovies/MovieCollectionViewModel.swift
  Sources/MyMovies/View/MovieCollectionView.swift
  Tests/MyMoviesTests/MovieCollectionViewModelTests.swift
  Tests/MyMoviesTests/MyMoviesRepositoryTests.swift   (rewritten over the in-memory store)
  Tests/MyMoviesTests/Support/StubMovieDetailProvider.swift
MovieDemo/MovieList/                  MovieCell removed; imports MovieUI
```

## Module contracts

### MovieStore

```swift
public enum MovieCollection: String, Codable, CaseIterable, Sendable, Hashable {
  case watchlist, seen, favourites
}

public struct StoredMovie: Codable, Sendable, Equatable, Identifiable {
  public let movie: Movie
  public let addedAt: Date
  public var id: Int { movie.id }
  public init(movie: Movie, addedAt: Date)
}

public struct MovieStoreChange: Sendable, Equatable {
  public enum Kind: Sendable { case added, removed }
  public let movieID: Int
  public let collection: MovieCollection
  public let kind: Kind
}

public struct MovieStoreSnapshot: Codable, Sendable, Equatable {
  public var entries: [MovieCollection: [StoredMovie]]
  public init(entries: [MovieCollection: [StoredMovie]] = [:])
  public static let empty: MovieStoreSnapshot
}

public protocol MovieStore: Sendable {
  func movies(in collection: MovieCollection) async throws -> [StoredMovie]      // newest first
  func collections(containing movieID: Int) async throws -> Set<MovieCollection>
  func add(_ movie: Movie, to collection: MovieCollection) async throws         // idempotent, quiet
  func remove(movieID: Int, from collection: MovieCollection) async throws      // no-op if absent, quiet
  func changes() async -> AsyncStream<MovieStoreChange>                          // one stream per call; ends on cancel
}

public protocol MovieStorePersistence: Sendable {
  func load() async throws -> MovieStoreSnapshot
  func save(_ snapshot: MovieStoreSnapshot) async throws
}

public actor LocalMovieStore: MovieStore {
  public init(persistence: any MovieStorePersistence, now: @escaping @Sendable () -> Date = Date.init)
}
// Loads the snapshot lazily on first use. Every mutation that changes state
// saves the whole snapshot, then yields one MovieStoreChange to every live
// continuation. Continuations are keyed by UUID; onTermination hops back
// into the actor to remove the key.

public struct FileMovieStorePersistence: MovieStorePersistence {
  public init(fileURL: URL)
  public static func applicationSupport() -> FileMovieStorePersistence   // …/Application Support/MovieDemo/movie-store.json
}
// load(): missing or undecodable file → .empty. save(): creates the directory, writes atomically, ISO 8601 dates.

public enum MovieStoreModule {
  public static let requiredKinds: [AnyLocatorKind] = []
  @MainActor public static func registerServices(in locator: any DependencyLocator)
  // registers { _ in LocalMovieStore(persistence: FileMovieStorePersistence.applicationSupport()) }
}
extension Locator.Kind { public static var movieStore: Locator.Kind<any MovieStore> }   // id "MovieStore"
extension AnyLocatorKind { public static let movieStore: AnyLocatorKind }               // .erased
```

`MovieStoreTesting`:

```swift
public final class InMemoryMovieStorePersistence: MovieStorePersistence, Sendable {
  public init(initial: MovieStoreSnapshot = .empty)
  public var saved: [MovieStoreSnapshot] { get }    // every snapshot passed to save(), in order
}
public extension LocalMovieStore {
  static func inMemory(initial: MovieStoreSnapshot = .empty, now: @escaping @Sendable () -> Date = Date.init) -> LocalMovieStore
}
```

### MovieUI

```swift
public struct MovieCell: View { public init(movie: Movie) }    // the existing cell, unchanged visually

public extension MovieCollection {
  var title: String               // "Watchlist", "Seen", "Favourites"
  var systemImage: String         // "bookmark", "checkmark.circle", "heart"
  var selectedSystemImage: String // "bookmark.fill", "checkmark.circle.fill", "heart.fill"
}
```

### MovieDetail (changes)

```swift
public enum MovieDetailModule { requiredKinds = [.apiClient, .analyticsClient, .movieStore] }
// provider resolves .movieStore too and passes it to the factory

protocol MovieDetailFactory {
  @MainActor func makeMovieDetailViewController(movie: Movie, apiClient: any APIClient, store: any MovieStore, analytics: any AnalyticsClient) -> UIViewController
}

protocol MovieDetailRepository: Sendable {
  func movieDetails(id: Int) async throws -> Movie
  func collections(containing movieID: Int) async throws -> Set<MovieCollection>
  func add(_ movie: Movie, to collection: MovieCollection) async throws
  func remove(movieID: Int, from collection: MovieCollection) async throws
  func changes() async -> AsyncStream<MovieStoreChange>
}
// MovieDetailRepositoryImpl(apiClient:store:) forwards the last four to the store.
```

`MovieDetailViewModel` additions: `private(set) var collections: Set<MovieCollection>`,
`private(set) var collectionsTask: Task<Void, Never>?`,
`private(set) var observationTask: Task<Void, Never>?`,
`func isIn(_ collection: MovieCollection) -> Bool`,
`func toggle(_ collection: MovieCollection)`. `onAppear()` additionally loads
`collections` and starts observing on first call. `deinit` cancels
`observationTask`.

`MovieDetailViewController`: `title = nil`; transparent
`navigationItem.scrollEdgeAppearance`; `rightBarButtonItems` = one item per
`MovieCollection.allCases` in order, image `systemImage` or
`selectedSystemImage` from `viewModel.isIn`, accessibility label the
collection's title, action `viewModel.toggle`. Re-rendered through a
`withObservationTracking` loop.

`MovieDetailView`: `ScrollView` ignores the top safe area; hero height 420;
the rest as today.

### MyMovies (changes)

```swift
public enum MyMoviesModule { requiredKinds = [.analyticsClient, .movieStore, .movieDetailProvider] }

protocol MyMoviesFactory {
  @MainActor func makeMyMoviesViewController(store: any MovieStore, analytics: any AnalyticsClient, movieDetailProvider: any MovieDetailProvider) -> UIViewController
  @MainActor func makeMovieCollectionViewController(collection: MovieCollection, store: any MovieStore, analytics: any AnalyticsClient, movieDetailProvider: any MovieDetailProvider) -> UIViewController
}

protocol MyMoviesRepository: Sendable {
  func movies(in collection: MovieCollection) async throws -> [StoredMovie]
  func remove(movieID: Int, from collection: MovieCollection) async throws
  func changes() async -> AsyncStream<MovieStoreChange>
}
// MyMoviesRepositoryImpl(store:) forwards to the store. NoOpMyMoviesRepository is deleted.

protocol MyMoviesRouter: AnyObject {
  @MainActor func routeTo(collection: MovieCollection)
  @MainActor func routeToMovieDetails(movie: Movie)
}
@MainActor final class MyMoviesRouterImpl: MyMoviesRouter {
  init(viewController: UIViewController,
       movieDetailProvider: any MovieDetailProvider,
       makeCollectionScreen: @escaping @MainActor (MovieCollection) -> UIViewController)
}
```

`MyMoviesViewModel`: `sections: [MovieCollection]`, `sectionTapped(_:)`
tracks `my_movies_section_tapped` with `section: collection.rawValue` and
calls `router.routeTo(collection:)`. Repository still held, still unused.

`MovieCollectionViewModel` (`@MainActor @Observable`, `ViewModel` with
`ViewControllerType = MovieCollectionViewController`):
`init(collection:repository:router:analytics:)`; state `movies: [StoredMovie]`,
`isLoading`, `errorMessage: String?`, `loadTask`, `observationTask`;
`emptyMessage: String`; intents `onAppear()` (tracks
`movie_collection_viewed` once, loads, observes once), `reload()`,
`remove(_ movie: Movie)` (tracks `movie_collection_removed`, repository
remove; the list refreshes through the stream, not by local mutation),
`movieWasTapped(_ movie: Movie)` (tracks `movie_selected`, routes).

`MovieCollectionViewController`: `ViewModelBindable`, `title = collection.title`,
large title off, `viewWillAppear → onAppear`. `MovieCollectionView`: `List` of
`MovieCell` rows as buttons, `.swipeActions` delete calling `remove`,
`ContentUnavailableView` with `emptyMessage` when empty and not loading,
error text with Retry calling `reload`.

### App target

`setupLocator` also calls `MovieStoreModule.registerServices(in:)` and
verifies `MovieStoreModule.requiredKinds`. Nothing else changes.

## Behaviour summary

1. Detail screen opens with the hero at the very top under a see-through
   bar, title below, three outline icons top right. If the movie is already
   in a collection, that icon is filled. Scrolling up turns the bar opaque.
2. Tapping an icon fills or outlines it immediately and writes the file.
3. My Movies → Watchlist shows the watchlisted movies newest first with
   poster, title, year, rating. Empty: "Nothing in your watchlist yet".
4. Swipe left on a row → Remove. The row disappears because the store
   emitted a change, not because the view model edited its array.
5. Tap a row → the same detail screen. Toggle Watchlist off there, go back:
   the row is gone.
6. On Discover, open a detail, add to Favourites, switch tabs, open
   Favourites: it is there. The list view model on the other tab received
   the change while it was off screen.
7. Kill and relaunch: everything is still there.

## Testing plan

`MovieStoreTests` (`swift test`, macOS):

- add then `movies(in:)` returns it; `collections(containing:)` reports it.
- two adds with injected clock sort newest first.
- second add of the same movie is quiet: `saved.count` unchanged, no change
  emitted; `addedAt` keeps the first date.
- remove present movie emits `.removed` and saves; remove absent is quiet.
- flags are independent: add to watchlist and seen, remove from seen, still
  in watchlist.
- every mutation saves exactly once; the saved snapshot equals what
  `movies(in:)` reports.
- `changes()` delivers to two subscribers; cancelling one subscriber's task
  finishes its stream and the other still receives.
- `LocalMovieStore(persistence:)` loads `initial` lazily: `movies(in:)` on a
  store built over a non-empty snapshot returns it.
- `FileMovieStorePersistence`: save then load in a temp directory round-trips
  a snapshot with dates to the second; load of a missing file → `.empty`;
  load of a garbage file → `.empty`.

`MovieUITests`: display attributes for the three cases.

`MovieDetailTests`: view model `toggle` adds then removes through an
in-memory store, tracks `movie_collection_toggled` with the right action,
`isIn` reflects it; a change made directly on the store for the same movie
updates `collections` through observation; a change for a different movie
does not; failure (a persistence whose `save` throws) reverts the flag and
tracks `error_shown`. Module test: three right bar button items, `title` nil,
images match outline symbols before any toggle.

`MyMoviesTests`: repository forwards to the store; collection view model
loads newest first, `remove` triggers a reload via the stream and the row is
gone, `movieWasTapped` routes and tracks, `emptyMessage` per collection;
hub view model tests updated to `MovieCollection`; module test registers
store, analytics and a stub detail provider and resolves the hub.

`MovieDemoTests`: `MovieStoreModule.requiredKinds` added to the
`setupLocator` test; `.movieStore` registered.

## What is left to the builder

- Hero image height and exact spacing on the detail screen.
- Exact `withObservationTracking` helper shape (inline in the controller is
  fine).
- Whether the collection list uses `List` + `.onDelete` or `.swipeActions`.
- JSON `version` field handling beyond writing `1`.

## Definition of done

- `xcodegen generate` and `xcodebuild test -scheme MovieDemo` pass with
  every target green; `swift test` passes in `MovieStore`.
- Zero compiler warnings.
- Behaviour summary items 1 to 7 hold when run on a simulator.
- README: module table rows for `MovieStore` and `MovieUI`, dependency
  graph, My Movies description updated, this spec and its plan listed.
