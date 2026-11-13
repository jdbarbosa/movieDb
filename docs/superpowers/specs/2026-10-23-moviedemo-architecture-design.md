# MovieDemo – Modular iOS Architecture Demo

Date: 2026-10-23
Status: approved by owner for implementation (2026-10-23) after second builder review; review resolutions recorded below

## Intent

A small native iOS app whose purpose is to showcase a modular, testable
architecture rather than product features. Two screens backed by The Movie
Database (TMDB) API: a searchable, infinitely scrolling list of movies, and a
movie detail screen.

The architecture mirrors the owner's existing reference project at
`/Users/v.joao.diasbarbosa/Documents/Glazed/iOS/moviedb-swift`: one Swift
Package per module, a `Locator` module implementing the Service Locator
pattern with typed keys, and in each feature module a `Module` registration
entry point, a public `Provider`, an internal `Factory`, a `Router`, a
`Repository`, a `ViewModel`, a `ViewController` that hosts a SwiftUI `View`.
This project modernises that reference: Swift Concurrency instead of Combine,
Swift 6 strict concurrency, an `AnalyticsClient` module, mock clients shipped
as importable products, real tests, infinite scroll and search.

## Goals

- One Swift Package per module, local path dependencies between them, exactly
  as the reference.
- Service Locator (`Locator` module) for dependency injection. Each module
  registers its services in the locator through a `<Name>Module.registerServices(in:)`
  entry point and exposes its `Locator.Kind` keys.
- Per feature: `Module`, `Provider` (public), `Factory` (package-internal),
  `Router`, `Repository` (+ request types), `ViewModel`, `ViewController`,
  SwiftUI `View`.
- UIKit navigation (`UINavigationController`), each screen a `UIViewController`
  embedding a SwiftUI view through `UIHostingController`, bound via the
  `ViewModelBindable` / `ViewModel` protocols from a `Protocols` module.
- `async`/`await` and Swift Concurrency throughout. Swift 6 language mode,
  strict concurrency, zero warnings.
- `APIClient` and `AnalyticsClient` protocolised, each with a mock/spy product
  that test targets can import.
- Unit tests for ViewModels, Repositories/requests, the live API client and
  the Locator.

## Non-goals

- Visual polish beyond a clean default UI. No design system.
- Offline caching, persistence, favourites, authentication.
- Localisation beyond English. UI tests / snapshot tests.
- A real analytics backend; the analytics client logs to the console.

## Anti-goals (would make it a failure even if it works)

- Business logic in view controllers or SwiftUI views.
- The API key committed to git or hard-coded in source (the reference does
  this; this project must not).
- Combine or completion handlers where `async`/`await` fits.
- Strict concurrency warnings silenced with blanket `@unchecked Sendable` or
  `nonisolated(unsafe)` without a comment explaining why it is safe.

## Constraints

- Toolchain on the machine: Xcode 26.3, Swift 6.2.4, simulators iOS 17.5,
  18.x, 26.3. Must build with Xcode 26.3.
- Deployment target: iOS 17.0 for app and all packages (builder's call;
  reference uses iOS 15 packages / 16.6 app. iOS 17 enables `@Observable`.)
- Project location: `/Users/v.joao.diasbarbosa/Documents/Glazed/iOS/claude_generated`.
- API: `https://api.themoviedb.org/3`, TMDB **v3** `api_key` query item (the
  owner's credential is a 32-character hex v3 key). Stored outside git.
- No third-party runtime dependencies. XcodeGen is a build-time tool only.

## Decisions the owner made

| Topic | Decision |
|---|---|
| UI stack | UIKit navigation controllers; each screen embeds a SwiftUI view via `UIHostingController`. |
| Pattern | MVVM per feature with Repository, Router, ViewModel, bound through `ViewModelBindable`. |
| Modules | `Locator`, `Protocols`, `Models`, `APIClient`, `AnalyticsClient`, `MovieList`, `MovieDetail`, each its own Swift Package. |
| DI | Service Locator with typed `Locator.Kind<T>` keys. Each module has `registerServices(in:)`, a public `Provider` that resolves dependencies from the locator, and a `Factory` that assembles the screen. |
| Concurrency | `async`/`await`, Swift Concurrency, Swift 6 strict mode. |
| Search | Debounced search-as-you-type. Empty query → `/movie/popular`; otherwise `/search/movie?query=&page=`. |
| Infinite scroll | Yes, via `page`, for both popular and search. |
| Detail | Tapping a row pushes detail, which fetches `/movie/{id}`. |
| Reference | Structure, naming and file layout follow `moviedb-swift`. |
| Cross-feature routing | `MovieList` depends on `MovieDetail` and routes to it directly through `MovieDetailProvider`, as in the reference. |

## Cross-feature routing (owner decided)

As in the reference, `MovieList` depends on the `MovieDetail` package. The
`MovieListProvider` resolves `.movieDetailProvider` from the locator and
hands it to `MovieListRouterImpl`, which pushes the detail view controller
onto the list's navigation controller. The `MovieListRouter` protocol stays
internal to the feature. Consequence accepted by the owner: `MovieList`
cannot be built or tested without `MovieDetail`, and features form a
dependency chain rather than a flat set.

## Decisions made by the builder (Claude) – owner may override

| Topic | Call |
|---|---|
| Project generation | XcodeGen from `project.yml`; generated `.xcodeproj` gitignored. |
| Package location | Packages live inside the app source folder, as in the reference (`MovieDemo/<Package>/`). The app target's `sources` entry in `project.yml` excludes every package folder (`Locator/**`, … , `**/.swiftpm/**`); otherwise XcodeGen globs `Package.swift` and the package sources into the app target. |
| Test framework | Swift Testing (`import Testing`), as the reference's templates already use. |
| Test execution | Feature packages vend `UIViewController`, so `swift test` on macOS cannot build them. Tests run with `xcodebuild test -scheme MovieDemo` on the iOS simulator, `platform=iOS Simulator,name=iPhone 16,OS=18.4`. The `MovieDemo` scheme lists every package test target (`schemes.MovieDemo.test.targets` with `package:` entries) so one invocation runs them all. Every `Package.swift` also declares `.macOS(.v14)` so the UIKit-free packages can `swift test` on the Mac. |
| Observation | ViewModels are `@MainActor @Observable` classes (iOS 17) instead of `ObservableObject`/`@Published`. |
| Locator concurrency | `Locator` is `@MainActor`. Registration and resolution happen on the main actor (app start, screen creation), which makes the `[AnyHashable: Any]` storage safe under strict concurrency without locks. |
| Locator hardening | Owner approved all four: lazy closure registration, declared `requiredKinds` verified at startup and in tests, duplicate-registration precondition, locator used only by Providers at call time. See Locator section. |
| Debounce | 300 ms via cancellable `Task` + `Task.sleep`, injectable for tests. |
| Images | `AsyncImage`; `w185` in list rows, `w500` in detail. URL building helper in `Models`. |
| Secrets | `Config/Secrets.xcconfig` (gitignored) optionally included by committed `Config/App.xcconfig` → `TMDB_API_KEY` → `Info.plist` `TMDBAPIKey`; `Config/Secrets.example.xcconfig` committed. Missing key shows an explanatory screen instead of crashing. |
| Page envelope name | `MovieListResponse`, as in the reference, moved into `Models`. (Avoids a type named `MovieList` clashing with the module.) |
| Git | Repo initialised in the project folder with a Swift/Xcode `.gitignore`. |

## Repository layout

```
claude_generated/
├── project.yml
├── .gitignore
├── README.md
├── Config/
│   ├── App.xcconfig                     # TMDB_API_KEY = ; #include? "Secrets.xcconfig"
│   ├── Secrets.example.xcconfig
│   └── Secrets.xcconfig                 # gitignored
├── MovieDemo/                           # app target sources
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── AppRouter.swift                  # window + setupLocator() + start()
│   ├── Resources/Assets.xcassets
│   ├── Info.plist
│   ├── Locator/            Package.swift, Sources/Locator, Tests/LocatorTests
│   ├── Protocols/          Package.swift, Sources/Protocols, Tests/ProtocolsTests
│   ├── Models/             Package.swift, Sources/Models, Tests/ModelsTests
│   ├── APIClient/          Package.swift, Sources/APIClient, Sources/APIClientTesting, Tests/APIClientTests
│   ├── AnalyticsClient/    Package.swift, Sources/AnalyticsClient, Sources/AnalyticsClientTesting, Tests/AnalyticsClientTests
│   ├── MovieList/          Package.swift, Sources/MovieList, Tests/MovieListTests
│   └── MovieDetail/        Package.swift, Sources/MovieDetail, Tests/MovieDetailTests
├── MovieDemoTests/                      # app-level tests (AppRouter/locator wiring smoke test)
└── docs/superpowers/specs/
```

## Package dependency graph

```
Locator      → (none)
Protocols    → (none)              # UIKit only
Models       → (none)
APIClient    → Locator, Models
AnalyticsClient → Locator
MovieDetail  → Locator, Protocols, Models, APIClient, AnalyticsClient
MovieList    → Locator, Protocols, Models, APIClient, AnalyticsClient, MovieDetail
App          → all of the above

Products for tests:
APIClient package     → products "APIClient", "APIClientTesting"
AnalyticsClient package → products "AnalyticsClient", "AnalyticsClientTesting"
MovieListTests   → MovieList, APIClientTesting, AnalyticsClientTesting
MovieDetailTests → MovieDetail, APIClientTesting, AnalyticsClientTesting
```

## Module contracts

### Locator

Ported from the reference, made `@MainActor`, and hardened in four ways
(owner approved): lazy closure registration, declared-and-verified
dependencies, duplicate-registration assertion, locator used only at module
edges.

```swift
@MainActor
public protocol DependencyLocator: AnyObject {
    /// Registers a lazy factory. The closure runs on first resolve and its result is cached.
    func register<T>(_ kind: Locator.Kind<T>, _ make: @escaping @MainActor (any DependencyLocator) -> T)
    /// Convenience for already-built values.
    func register<T>(_ kind: Locator.Kind<T>, _ value: T)
    /// Returns the registered value, building it on first use. `fatalError` if missing,
    /// with a message listing the missing kind and every registered kind.
    func resolve<T>(_ kind: Locator.Kind<T>) -> T
    func isRegistered<T>(_ kind: Locator.Kind<T>) -> Bool
    /// Collects every kind in `required` that is not registered. Empty means OK.
    func missing(from required: [AnyLocatorKind]) -> [AnyLocatorKind]
    /// `precondition`s that nothing is missing; failure message lists all missing kinds.
    func verify(allOf required: [AnyLocatorKind])
}

@MainActor
public final class Locator: DependencyLocator {
    public struct Kind<T>: Hashable, Sendable, CustomStringConvertible {
        public let id: String
        public init(_ id: String = String(describing: T.self))
        public var erased: AnyLocatorKind { get }
    }
    public init()
}

/// Type-erased key, used for dependency declarations and verification.
public struct AnyLocatorKind: Hashable, Sendable, CustomStringConvertible { public let id: String }
```

Rules:

1. **Lazy registration.** Every `Module.registerServices(in:)` registers a
   closure. Nothing is constructed until first `resolve`. Registration order
   in `setupLocator()` therefore does not matter.
2. **Declared dependencies.** Every module that resolves anything exposes
   `public static let requiredKinds: [AnyLocatorKind]`. `AppRouter.setupLocator()`
   ends with `locator.verify(allOf: APIClientModule.requiredKinds + ... )`,
   so a forgotten registration fails once, at launch, with the full list.
   `MovieDemoTests` runs the same check.
3. **No duplicate registration.** `register` hits a `precondition` if the kind
   is already registered. (If a test needs to override a registration it
   builds a fresh `Locator`.)
4. **Locator at the edges only.** Inside a feature, only the `Provider`
   touches the locator, and it resolves at call time
   (`movieListViewController()`), never in its initializer. It passes
   concrete values into the `Factory`, which passes them into the
   `Router`, `Repository` and `ViewModel` as plain initializer parameters.
   Everything below the Provider is constructible in tests without a
   locator.

Each module declares its keys twice, side by side: a typed computed
`Locator.Kind` static in a `where T == any X` extension (for `register`/
`resolve`, used as `.apiClient`) and an `AnyLocatorKind` static with the
same id (for `requiredKinds`). Both are computed or `let` constants of
`Sendable` types, which strict concurrency requires. Internally the locator
stores entries keyed by `AnyLocatorKind` (the id), not by `Kind<T>` as
`AnyHashable`, so `missing(from:)` and `resolve` agree. Lazy entries are
stored in a small wrapper struct holding the `@MainActor` closure, avoiding a
fragile `Any` cast back to a function type.

`LocatorTests`: register/resolve round-trip; closure runs once and is cached;
closure not run until resolved; distinct kinds don't collide; `missing(from:)`
reports exactly the unregistered kinds; `isRegistered` reflects state
(duplicate-registration trap is documented, since Swift Testing cannot catch
`precondition`); `verify` passes when all present.

### Protocols

Ported from the reference:

```swift
public protocol ViewModelBindable {
    associatedtype ViewModelType
    @MainActor func bind(viewModel: ViewModelType)
}

public protocol ViewModel {
    associatedtype ViewControllerType: UIViewController & ViewModelBindable
        where ViewControllerType.ViewModelType == Self
}
```

### Models

Pure `Codable & Sendable & Equatable & Hashable` structs with explicit
`CodingKeys` (reference style; no `convertFromSnakeCase` so the decoder is
plain).

- `Movie`: `id`, `title`, `overview: String?`, `posterPath: String?`,
  `backdropPath: String?`, `releaseDate: String?`, `voteAverage: Double?`,
  `voteCount: Int?`, plus detail-only optionals `runtime: Int?`,
  `tagline: String?`, `genres: [Genre]?`.
- `Genre`: `id`, `name`.
- `MovieListResponse`: `page`, `results: [Movie]`, `totalPages`, `totalResults`.
- `TMDBImage.url(path:size:)` helper (`.w185`, `.w500`) → `URL?`.

`ModelsTests` decode fixture JSON for a popular-list page and a detail
payload.

### APIClient

Reference shape converted to `async`/`await`. The api key is injected, never
hard-coded.

```swift
public protocol APIRequest: Sendable {
    associatedtype Response: Decodable & Sendable
    var path: String { get }
    var queryItems: [URLQueryItem]? { get }
    var httpRequestMethod: HTTPRequestMethod { get }      // default .get
    var additionalHeaders: [String: String]? { get }      // default nil
    var httpBody: Data? { get }                           // default nil
}
public enum HTTPRequestMethod: String, Sendable { case delete, get, patch, post, put }

public protocol APIClient: Sendable {
    func send<T: APIRequest>(_ request: T) async throws -> T.Response
}

public enum APIError: Error, Equatable, Sendable {
    case client            // could not build the request
    case network(Int?)     // transport failure or non-2xx (status when available)
    case decoding
    case unreachable
    case notAuthenticated  // 401
}

public struct APIConfiguration: Sendable {
    public var baseUrl: URL
    public var apiKey: String
}

public final class MovieDatabaseAPIClient: APIClient {
    public init(configuration: APIConfiguration, session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder())
}

public enum APIClientModule {
    public static let requiredKinds: [AnyLocatorKind] = []
    @MainActor public static func registerServices(in locator: any DependencyLocator, configuration: APIConfiguration)
}
extension Locator.Kind where T == any APIClient { public static var apiClient: Self { Self("APIClient") } }
extension AnyLocatorKind { public static let apiClient = AnyLocatorKind("APIClient") }
```

`APIRequest` gets a package-internal `buildRequest(baseUrl:apiKey:)` extension
(reference logic, api key appended as a query item). `MovieDatabaseAPIClient`
uses `session.data(for:)`, maps 401 → `.notAuthenticated`, other non-2xx →
`.network(status)`, `URLError` → `.network(nil)` (`.notConnectedToInternet`
→ `.unreachable`), decoding failures → `.decoding`.

**APIClientTesting product** (same package, separate target):

```swift
public final class MockAPIClient: APIClient, Sendable {
    public init()
    /// FIFO of responses per path. Each call to a path consumes the next stub; the last one repeats.
    public func stub<R: Decodable & Sendable>(path: String, result: Result<R, APIError>, delay: Duration? = nil)
    /// Closure form for tests that need to inspect query items (e.g. page/query) or vary by call.
    public func stub<R: Decodable & Sendable>(path: String, handler: @Sendable (RecordedRequest) async throws -> R)
    public var receivedRequests: [RecordedRequest] { get }   // computed over a lock; path, queryItems, method
}
public struct RecordedRequest: Equatable, Sendable { public let path: String; public let queryItems: [URLQueryItem]; public let method: HTTPRequestMethod }
```

State lives behind an `OSAllocatedUnfairLock` (iOS 16+; `Mutex` is iOS 18+
so not available at the iOS 17 target), making the class genuinely
`Sendable`. Unstubbed path → throws `APIError.client` and still records the
call. Per-stub `delay` is honoured with `Task.sleep` so tests can observe
cancellation and out-of-order responses.

`APIClientTests`: URL building (base + path + query + `api_key`), status
mapping, decoding mapping, using a `URLProtocol` stub.

### AnalyticsClient

```swift
public struct AnalyticsEvent: Equatable, Sendable { public var name: String; public var parameters: [String: String] }

public protocol AnalyticsClient: Sendable { func track(_ event: AnalyticsEvent) }

public struct ConsoleAnalyticsClient: AnalyticsClient { public init() }   // os.Logger

public enum AnalyticsClientModule {
    public static let requiredKinds: [AnyLocatorKind] = []
    @MainActor public static func registerServices(in locator: any DependencyLocator)
}
extension Locator.Kind where T == any AnalyticsClient { public static var analyticsClient: Self { Self("AnalyticsClient") } }
extension AnyLocatorKind { public static let analyticsClient = AnyLocatorKind("AnalyticsClient") }
```

**AnalyticsClientTesting product**: `SpyAnalyticsClient: AnalyticsClient, Sendable`
with `events: [AnalyticsEvent]` as a computed property over an
`OSAllocatedUnfairLock`.

Events emitted by features (fixed names so tests can assert):

| Event | Parameters | When |
|---|---|---|
| `movie_list_viewed` | – | list appears first time |
| `movie_search_performed` | `query` | debounced search request sent |
| `movie_list_page_loaded` | `page`, `mode` (`popular`/`search`) | any page load completes |
| `movie_selected` | `movie_id` | row tapped |
| `movie_detail_viewed` | `movie_id` | detail loaded |
| `error_shown` | `screen`, `message` | error state shown |

### MovieList feature

Files (reference layout): `MovieListModule.swift`, `MovieListProvider.swift`,
`MovieListFactory.swift`, `MovieListRouter.swift`, `MovieListViewController.swift`,
`MovieListViewModel.swift`, `Repository/MovieListRepository.swift`,
`Repository/Requests/PopularMoviesRequest.swift`,
`Repository/Requests/SearchMoviesRequest.swift`, `View/MovieListView.swift`,
`Previews/MovieListView_Previews.swift`.

```swift
public enum MovieListModule {
    public static let requiredKinds: [AnyLocatorKind] = [.apiClient, .analyticsClient, .movieDetailProvider]
    @MainActor public static func registerServices(in locator: any DependencyLocator)   // registers a closure
}
extension Locator.Kind where T == any MovieListProvider { public static var movieListProvider: Self { Self("MovieListProvider") } }
extension AnyLocatorKind { public static let movieListProvider = AnyLocatorKind("MovieListProvider") }

public protocol MovieListProvider {
    @MainActor func movieListViewController() -> UIViewController
}
// MovieListProviderImpl(locator:) stores the locator only. movieListViewController()
// resolves .apiClient, .analyticsClient and .movieDetailProvider at call time and
// passes them to the factory.

protocol MovieListFactory {            // internal, as reference's `package`
    @MainActor func makeMovieListViewController(
        apiClient: any APIClient,
        analytics: any AnalyticsClient,
        movieDetailProvider: any MovieDetailProvider
    ) -> UIViewController
}
// MovieListFactoryImpl assembles: ViewController, RepositoryImpl(apiClient),
// RouterImpl(viewController, movieDetailProvider), ViewModel(router, repository, analytics), then bind().

protocol MovieListRouter {             // internal; implemented by MovieListRouterImpl
    @MainActor func routeToMovieDetails(movie: Movie)
}

protocol MovieListRepository: Sendable {
    func popularMovies(page: Int) async throws -> MovieListResponse
    func searchMovies(query: String, page: Int) async throws -> MovieListResponse
}
// PopularMoviesRequest(page:) → "/movie/popular"; SearchMoviesRequest(page:query:) → "/search/movie"
// Request types are structs with `let` properties (APIRequest is Sendable; the reference's classes with `var` would not compile).
```

`MovieListViewModel` (`@MainActor @Observable final class`, conforms to
`Protocols.ViewModel` with `ViewControllerType = MovieListViewController`):

- state: `query`, `movies: [Movie]`, `isLoadingFirstPage`, `isLoadingNextPage`,
  `errorMessage: String?`, `canLoadMore`.
- intents: `onAppear()`, `queryChanged(_:)`, `loadNextPageIfNeeded(currentItem:)`,
  `retry()`, `movieWasTapped(_:)`.
- `queryChanged`: cancel pending debounce + in-flight load, start a `Task`
  that sleeps `debounce` (injected, default 300 ms), then loads page 1 in the
  mode derived from the trimmed query (empty → popular, else search). Stale
  results are discarded via `Task.isCancelled` / request token.
- `loadNextPageIfNeeded`: when `currentItem` is within the last 5 rows,
  `page < totalPages`, nothing loading → load next page, append,
  de-duplicate by `id`.
- `movieWasTapped`: track `movie_selected`, call `router.routeToMovieDetails(movie:)`.

`MovieListViewController`: `ViewModelBindable`; `bind(viewModel:)` adds a
`UIHostingController(rootView: MovieListView(viewModel:))` as a child
(reference code), `title = "Movies"`, `viewWillAppear` → `viewModel.onAppear()`. `onAppear()` is idempotent: it loads only when nothing has been loaded yet, so returning from detail keeps the current list and search, and `movie_list_viewed` fires once.
Search field: a `UISearchController` on `navigationItem.searchController`
whose text updates feed `viewModel.queryChanged` (keeps the search bar in
UIKit's navigation bar, which is reliable when hosting SwiftUI). Builder may
use `.searchable` instead if it renders correctly when embedded.

`MovieListView`: `List`/`LazyVStack` of `MovieCell` rows (poster `w185`,
title, year, rating), progress footer, empty state, error state with Retry.

### MovieDetail feature

Files: `MovieDetailModule.swift`, `MovieDetailProvider.swift`,
`MovieDetailFactory.swift`, `MovieDetailViewController.swift`,
`MovieDetailViewModel.swift`, `Repository/MovieDetailRepository.swift`,
`Repository/Requests/MovieDetailRequest.swift`, `View/MovieDetailView.swift`.

```swift
public enum MovieDetailModule {
    public static let requiredKinds: [AnyLocatorKind] = [.apiClient, .analyticsClient]
    @MainActor public static func registerServices(in locator: any DependencyLocator)   // registers a closure
}
extension Locator.Kind where T == any MovieDetailProvider { public static var movieDetailProvider: Self { Self("MovieDetailProvider") } }
extension AnyLocatorKind { public static let movieDetailProvider = AnyLocatorKind("MovieDetailProvider") }

public protocol MovieDetailProvider {
    @MainActor func movieDetailViewController(movie: Movie) -> UIViewController
}
// ProviderImpl resolves .apiClient and .analyticsClient at call time; Factory assembles VC + Repository + ViewModel.

protocol MovieDetailRepository: Sendable { func movieDetails(id: Int) async throws -> Movie }
// MovieDetailRequest(id:) → "/movie/{id}"
```

`MovieDetailViewModel` (`@MainActor @Observable`): initialised with the
tapped `Movie` so the screen renders title/poster immediately; `state`:
`idle | loading | loaded(Movie) | failed(String)`; `onAppear()` fetches
`/movie/{id}` and replaces the movie with the full payload; `retry()`.
Tracks `movie_detail_viewed` / `error_shown`.

`MovieDetailView`: reference layout (poster header, title, release date,
rating, overview) plus tagline, runtime and genre chips from the fetched
detail; loading overlay and error state. No favourite button, no lorem ipsum.

### App target

- `AppRouter(window:)` as the reference: `start()` calls `setupLocator()`,
  resolves `.movieListProvider`, sets a `UINavigationController` with the
  list as root. `setupLocator(configuration:)` is a static function that
  builds and returns a fresh `Locator` every call (so tests can call it
  without tripping the duplicate-registration precondition), taking the
  `APIConfiguration` as a parameter.
- `setupLocator(configuration:)` calls `registerServices` on
  `APIClientModule`, `AnalyticsClientModule`, `MovieDetailModule` and
  `MovieListModule` (order irrelevant thanks to lazy registration), then
  `locator.verify(allOf:)` with the concatenated `requiredKinds` of all four
  modules.
- `start()` reads `TMDBAPIKey` from `Bundle.main`. If it is empty (clean
  checkout without `Secrets.xcconfig`) the app does **not** crash: it shows a
  simple full-screen "Missing TMDB API key, see README" view controller
  instead of the list. This keeps the project generating, building and
  running for anyone who clones it, which is the audience of an architecture
  showcase.
- `SceneDelegate` creates the window, the `AppRouter`, calls `start()`,
  makes the window key.
- `MovieDemoTests`: a smoke test that `AppRouter.setupLocator(configuration:)`
  with a dummy `APIConfiguration` leaves `missing(from:)` empty for every
  module's `requiredKinds`, and that `movieListViewController()` returns a
  view controller. It never reads the real key, so it runs without
  `Secrets.xcconfig`.

## Behaviour summary

1. Launch: list screen titled "Movies", popular page 1 loads with a spinner.
2. Typing: 300 ms after the last keystroke, search page 1 replaces the list.
   Clearing the query returns to popular page 1. In-flight requests are
   cancelled when the query changes.
3. Scrolling near the bottom loads the next page in the current mode and
   appends. Stops at `totalPages`.
4. First-page failure: error message with Retry. Later-page failure: inline
   retry footer, rows stay.
5. Tapping a row pushes detail; detail shows known data immediately, fetches
   `/movie/{id}`, fills in the rest; failure shows error with Retry.
6. Back navigation is standard UIKit.

## Testing plan

Swift Testing, run via `xcodebuild test` on the simulator.

- `LocatorTests`: see the Locator section (lazy build, caching, `missing`, `verify`).
- `ModelsTests`: decode fixtures.
- `APIClientTests`: URL building with `api_key`, status/decoding mapping, via a `URLProtocol` stub whose handler is held in a lock-protected static (not a plain `static var`, which Swift 6 rejects).
- `AnalyticsClientTests`: `ConsoleAnalyticsClient.track` does not crash;
  `SpyAnalyticsClient` records.
- `MovieListTests` (over `MockAPIClient` + `SpyAnalyticsClient`):
  requests hit the right paths/query items; popular loads on appear and
  tracks `movie_list_viewed`; a burst of keystrokes yields one search
  request after the debounce; clearing returns to popular; page 2 appends and
  stops at `totalPages`; stale responses discarded (using `delay`); error →
  `errorMessage` + `error_shown`, retry clears; `movieWasTapped` calls a spy
  router and tracks `movie_selected`.
- `MovieDetailTests`: `loading → loaded`; failure → `failed` + `error_shown`;
  retry reloads.
- `MovieDemoTests`: locator wiring smoke test.

## Secrets

`Config/Secrets.xcconfig` (gitignored): `TMDB_API_KEY = <key>`. A committed
`Config/App.xcconfig` sets `TMDB_API_KEY =` (empty) and then
`#include? "Secrets.xcconfig"` (optional include, so a clean checkout still
generates and builds). `project.yml` applies `App.xcconfig` to the app target
and `Info.plist` carries `TMDBAPIKey = $(TMDB_API_KEY)`. README explains the
setup. The key the owner shared in chat is written only into the gitignored
file. Owner is advised to rotate it after the demo.

## What is left to the builder

- Exact SwiftUI layout and styling.
- `UISearchController` vs `.searchable` (see MovieList).
- Internal synchronisation of the mocks.
- `project.yml` contents, scheme names, bundle id (suggest
  `com.glazedsolutions.MovieDemo`).
- README: XcodeGen install, key setup, generate, build, test.

## Definition of done

- `xcodegen generate` then
  `xcodebuild -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' build`
  succeeds with zero warnings.
- `xcodebuild test -scheme MovieDemo` on the same destination passes, covering all seven package test targets and `MovieDemoTests`.
- On the simulator: popular list loads, search updates while typing,
  infinite scroll works, tapping opens detail with fetched data.
- `grep -r "<key>" --include=*.swift --include=*.yml --include=*.plist` over
  the committed tree returns nothing.

## Review resolutions (2026-10-23, second builder review)

All items settled by the builder as routine calls; none change what the owner
sees.

- Clean checkout without the secret must generate, build, test and run:
  optional `#include?` of `Secrets.xcconfig`, explanatory screen instead of
  crash when the key is empty, app tests inject a dummy configuration.
- Packages inside the app folder are excluded from the app target's source
  glob in `project.yml`.
- Locator keys are computed statics in `where T ==` extensions plus
  `AnyLocatorKind` constants; storage keyed by id; closures wrapped.
- Mocks are `Sendable` classes over `OSAllocatedUnfairLock` with computed
  read accessors; stubs are per-path FIFOs or closures with optional
  per-stub delay so pagination and stale-response tests are expressible.
- Request types are structs with `let` properties.
- `onAppear()` is idempotent so back navigation keeps list state.
- `setupLocator(configuration:)` is static and returns a fresh locator.
- `MovieDemo` scheme includes all package test targets; packages declare
  `.macOS(.v14)` too.
- Module names equal to a contained type name (`APIClient`, `Locator`) are
  kept as in the reference; code never relies on module-qualified names.
