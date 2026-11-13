# MovieDemo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A modular UIKit+SwiftUI iOS demo (movie list with debounced search and infinite scroll, movie detail) built from seven local Swift Packages wired through a hardened Service Locator.

**Architecture:** One Swift Package per module inside the app source folder (`Locator`, `Protocols`, `Models`, `APIClient`, `AnalyticsClient`, `MovieDetail`, `MovieList`). Each feature exposes a `Module` (registration + `requiredKinds`), a public `Provider`, and keeps `Factory`, `Router`, `Repository`, `ViewModel`, `ViewController` and SwiftUI `View` internal. The app target is the composition root (`AppRouter.setupLocator`). All async work uses Swift Concurrency under Swift 6 strict checking.

**Tech Stack:** Swift 6.2 / Xcode 26.3, iOS 17.0 deployment target, SwiftPM local packages, XcodeGen 2.46, Swift Testing, UIKit + SwiftUI (`@Observable`), `URLSession` async API, `OSAllocatedUnfairLock`.

**Spec:** `docs/superpowers/specs/2026-10-23-moviedemo-architecture-design.md`

## Global Constraints

- Project root: `/Users/v.joao.diasbarbosa/Documents/Glazed/iOS/claude_generated` (abbreviated `$ROOT` below).
- Every `Package.swift`: `// swift-tools-version: 6.0`, `platforms: [.iOS(.v17), .macOS(.v14)]`. Feature and Protocols packages import UIKit and are tested only on the simulator.
- Zero warnings under strict concurrency. No blanket `@unchecked Sendable` / `nonisolated(unsafe)` without a one-line safety comment.
- No Combine. `async`/`await` everywhere.
- The TMDB key `<TMDB_API_KEY>` goes **only** into `$ROOT/Config/Secrets.xcconfig` (gitignored). Grep for `<key>` over tracked files must be empty.
- Base URL `https://api.themoviedb.org/3`; auth via `api_key` query item. Images: `https://image.tmdb.org/t/p/{w185|w500}{posterPath}`.
- Debounce 300 ms default, injectable. Next page triggers within last 5 rows. Analytics event names exactly as the spec's table.
- Simulator destination for every `xcodebuild`: `-destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'`.
- Commit after each task with a conventional-commit message ending in `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Code style: 2-space indentation, as in the reference project.

## Review Focus

1. Whitespace-only query (e.g. `"   "`) must behave as empty → popular mode, no search request. Test in Task 7 (`whitespaceQueryIsPopularMode`).
2. TMDB repeats a movie id across pages; appending must de-duplicate so `List` ids stay unique and no crash/duplicate row. Test in Task 7 (`nextPageDeduplicatesById`).
3. Cancelling an in-flight request when the user keeps typing must not surface as an error state. Test in Task 7 (`cancellationDoesNotSetError`).
4. HTTP 401 (bad key) must map to `.notAuthenticated` and show a readable message, not a decoding error. Tests in Task 4 (`unauthorizedMapsToNotAuthenticated`) and Task 7 (`errorMessageIsHumanReadable`).
5. `posterPath == nil` must yield a nil URL and the placeholder, never a malformed URL. Test in Task 3 (`imageURLIsNilWithoutPath`).

---

### Task 1: Repository scaffold and Locator package

**Files:**
- Create: `$ROOT/.gitignore`, `$ROOT/Config/App.xcconfig`, `$ROOT/Config/Secrets.example.xcconfig`, `$ROOT/Config/Secrets.xcconfig` (gitignored)
- Create: `$ROOT/MovieDemo/Locator/Package.swift`
- Create: `$ROOT/MovieDemo/Locator/Sources/Locator/AnyLocatorKind.swift`, `DependencyLocator.swift`, `Locator.swift`
- Test: `$ROOT/MovieDemo/Locator/Tests/LocatorTests/LocatorTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct AnyLocatorKind: Hashable, Sendable, CustomStringConvertible { public let id: String; public init(_ id: String) }
  @MainActor public protocol DependencyLocator: AnyObject {
    func register<T>(_ kind: Locator.Kind<T>, make: @escaping @MainActor (any DependencyLocator) -> T)
    func register<T>(_ kind: Locator.Kind<T>, _ value: T)
    func resolve<T>(_ kind: Locator.Kind<T>) -> T
    func isRegistered(_ kind: AnyLocatorKind) -> Bool
    func missing(from required: [AnyLocatorKind]) -> [AnyLocatorKind]
    func verify(allOf required: [AnyLocatorKind])
  }
  @MainActor public final class Locator: DependencyLocator {
    public struct Kind<T>: Hashable, Sendable, CustomStringConvertible { public let id: String; public init(_ id: String = String(describing: T.self)); public var erased: AnyLocatorKind }
    public init()
  }
  ```
- Semantics: storage keyed by `AnyLocatorKind`; lazy entries wrapped in `private struct LazyEntry { let make: @MainActor (any DependencyLocator) -> Any }`; on first `resolve` the closure runs and the result replaces the entry. `register` on an already-registered id → `preconditionFailure("Locator: \(kind) is already registered")`. `resolve` of a missing id → `fatalError("Locator: no registration for \(kind). Registered: \(sortedIds)")`. `verify` → `precondition(missing.isEmpty, "Locator: missing registrations: \(missing)")`.

- [ ] **Step 1: Initialise repo and config files**

```bash
cd $ROOT && git init -b main
```
`.gitignore`: standard Swift/Xcode (`.DS_Store`, `xcuserdata/`, `*.xcodeproj` (generated), `.build/`, `.swiftpm/`, `DerivedData/`, `Config/Secrets.xcconfig`).
`Config/App.xcconfig`:
```
TMDB_API_KEY =
#include? "Secrets.xcconfig"
```
`Config/Secrets.example.xcconfig`: `TMDB_API_KEY = your_tmdb_v3_api_key_here`.
`Config/Secrets.xcconfig`: `TMDB_API_KEY = <TMDB_API_KEY>`.

- [ ] **Step 2: Write failing Locator tests**

`LocatorTests.swift`, all `@Test @MainActor`:
- `resolvesRegisteredValue`: register `.init("Int")` value 42 → resolve == 42.
- `lazyClosureRunsOnceOnFirstResolve`: counter class; register `make:` incrementing counter; counter == 0 before resolve; resolve twice → counter == 1, same instance (`===`).
- `isRegisteredReflectsState`: false before, true after.
- `missingReportsExactlyUnregisteredKinds`: register "A"; `missing(from: [A, B, C]) == [B, C]`.
- `verifyPassesWhenAllPresent`: register A, B; `verify(allOf: [A, B])` does not trap.
- `distinctKindsDoNotCollide`: `Kind<Int>("one")` 1, `Kind<Int>("two")` 2 → resolve each.
- `erasedKindSharesId`: `Kind<Int>("x").erased == AnyLocatorKind("x")`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd $ROOT/MovieDemo/Locator && swift test 2>&1 | tail -5`
Expected: build error, types undefined.

- [ ] **Step 4: Implement `Package.swift`, `AnyLocatorKind`, `DependencyLocator`, `Locator`** per Interfaces.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd $ROOT/MovieDemo/Locator && swift test 2>&1 | tail -5`
Expected: `Test run with 7 tests passed`, zero warnings.

- [ ] **Step 6: Commit** `chore: scaffold repo and add Locator package`

---

### Task 2: Protocols package

**Files:**
- Create: `$ROOT/MovieDemo/Protocols/Package.swift`, `Sources/Protocols/ViewModelBindable.swift`
- Test: `Tests/ProtocolsTests/ProtocolsTests.swift`

**Interfaces:**
- Produces (verbatim from the reference):
  ```swift
  public protocol ViewModelBindable { associatedtype ViewModelType; @MainActor func bind(viewModel: ViewModelType) }
  public protocol ViewModel { associatedtype ViewControllerType: UIViewController & ViewModelBindable where ViewControllerType.ViewModelType == Self }
  ```
- `platforms: [.iOS(.v17)]` only (UIKit).

- [ ] **Step 1: Write failing test** `bindStoresViewModel`: a test-local `@MainActor @Observable final class FakeVM: ViewModel { typealias ViewControllerType = FakeVC }` and `final class FakeVC: UIViewController, ViewModelBindable { var bound: FakeVM? ; func bind(viewModel:) }`; assert `bound === vm` after bind.
- [ ] **Step 2: Run to verify fail**: `cd $ROOT/MovieDemo/Protocols && xcodebuild test -scheme Protocols -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' 2>&1 | grep -E "error|Test Suite|passed|failed" | head` → compile error.
- [ ] **Step 3: Implement** the two protocols.
- [ ] **Step 4: Run to verify pass**: same command → `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit** `feat: add Protocols package with MVVM binding protocols`

---

### Task 3: Models package

**Files:**
- Create: `$ROOT/MovieDemo/Models/Package.swift`, `Sources/Models/Movie.swift`, `Genre.swift`, `MovieListResponse.swift`, `TMDBImage.swift`
- Test: `Tests/ModelsTests/ModelsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct Movie: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: Int; public let title: String; public let overview: String?; public let posterPath: String?; public let backdropPath: String?
    public let releaseDate: String?; public let voteAverage: Double?; public let voteCount: Int?
    public let runtime: Int?; public let tagline: String?; public let genres: [Genre]?
    public init(id:title:overview:posterPath:backdropPath:releaseDate:voteAverage:voteCount:runtime:tagline:genres:)  // all optionals default nil
    public var releaseYear: String?   // first 4 chars of releaseDate if count >= 4
  }
  public struct Genre: Codable, Sendable, Equatable, Hashable, Identifiable { public let id: Int; public let name: String; public init(id:name:) }
  public struct MovieListResponse: Codable, Sendable, Equatable { public let page: Int; public let results: [Movie]; public let totalPages: Int; public let totalResults: Int; public init(page:results:totalPages:totalResults:) }
  public enum TMDBImage { public enum Size: String, Sendable { case w185, w500 }; public static func url(path: String?, size: Size) -> URL? }
  ```
- Explicit `CodingKeys` with snake_case raw values (`poster_path`, `backdrop_path`, `release_date`, `vote_average`, `vote_count`, `total_pages`, `total_results`).

- [ ] **Step 1: Write failing tests**
  - `decodesPopularPage`: inline JSON with `page:1, total_pages:3, total_results:60, results:[{id:1,title:"A",poster_path:"/a.jpg",vote_average:7.5,release_date:"2024-05-01",overview:"x"}]` → fields match, `releaseYear == "2024"`, `runtime == nil`.
  - `decodesDetailPayload`: JSON with `runtime:120, tagline:"T", genres:[{id:28,name:"Action"}]`.
  - `decodesEmptyReleaseDate`: `release_date:""` → `releaseYear == nil`.
  - `imageURLBuildsForPath`: `TMDBImage.url(path:"/a.jpg", size:.w185)?.absoluteString == "https://image.tmdb.org/t/p/w185/a.jpg"`.
  - `imageURLIsNilWithoutPath`: `url(path:nil, size:.w500) == nil`.
- [ ] **Step 2: Run to verify fail**: `cd $ROOT/MovieDemo/Models && swift test 2>&1 | tail -5`.
- [ ] **Step 3: Implement** the four files.
- [ ] **Step 4: Run to verify pass**: 5 tests passed.
- [ ] **Step 5: Commit** `feat: add Models package`

---

### Task 4: APIClient package (client, testing product, locator registration)

**Files:**
- Create: `$ROOT/MovieDemo/APIClient/Package.swift` (deps: `../Locator`; products `APIClient`, `APIClientTesting`; targets `APIClient` [dep Locator], `APIClientTesting` [dep APIClient], test `APIClientTests` [deps APIClient, APIClientTesting])
- Create: `Sources/APIClient/APIRequest.swift`, `APIError.swift`, `APIConfiguration.swift`, `APIClient.swift`, `MovieDatabaseAPIClient.swift`, `APIClientModule.swift`
- Create: `Sources/APIClientTesting/MockAPIClient.swift`
- Test: `Tests/APIClientTests/MovieDatabaseAPIClientTests.swift`, `MockAPIClientTests.swift`, `StubURLProtocol.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum HTTPRequestMethod: String, Sendable { case delete, get, patch, post, put }
  public protocol APIRequest: Sendable {
    associatedtype Response: Decodable & Sendable
    var path: String { get }; var queryItems: [URLQueryItem]? { get }
    var httpRequestMethod: HTTPRequestMethod { get }; var additionalHeaders: [String: String]? { get }; var httpBody: Data? { get }
  }
  public extension APIRequest { /* defaults: .get, nil, nil */ }
  extension APIRequest { func buildRequest(baseUrl: URL, apiKey: String) -> URLRequest? }   // internal; path appended to baseUrl.path, queryItems + api_key
  public enum APIError: Error, Equatable, Sendable { case client, network(Int?), decoding, unreachable, notAuthenticated }
  extension APIError: LocalizedError { public var errorDescription: String? }  // "Could not build the request." / "Network error (status 500)." / "Could not read the server response." / "No internet connection." / "Invalid API key."
  public struct APIConfiguration: Sendable { public let baseUrl: URL; public let apiKey: String; public init(baseUrl:apiKey:); public static func movieDatabase(apiKey: String) -> APIConfiguration }
  public protocol APIClient: Sendable { func send<T: APIRequest>(_ request: T) async throws -> T.Response }
  public final class MovieDatabaseAPIClient: APIClient { public init(configuration: APIConfiguration, session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) }
  public enum APIClientModule { public static let requiredKinds: [AnyLocatorKind] = []; @MainActor public static func registerServices(in locator: any DependencyLocator, configuration: APIConfiguration) }
  extension Locator.Kind { public static var apiClient: Locator.Kind<any APIClient> { Locator.Kind("APIClient") } }
  extension AnyLocatorKind { public static let apiClient = AnyLocatorKind("APIClient") }
  // APIClientTesting
  public struct RecordedRequest: Equatable, Sendable { public let path: String; public let queryItems: [URLQueryItem]; public let method: HTTPRequestMethod }
  public final class MockAPIClient: APIClient, Sendable {
    public init()
    public func stub<R: Decodable & Sendable>(path: String, result: Result<R, APIError>, delay: Duration? = nil)
    public func stub<R: Decodable & Sendable>(path: String, handler: @escaping @Sendable (RecordedRequest) async throws -> R)
    public var receivedRequests: [RecordedRequest] { get }
  }
  ```
- `send` behaviour: non-2xx → 401 `.notAuthenticated`, else `.network(status)`; `URLError.notConnectedToInternet` → `.unreachable`, other `URLError` → `.network(nil)`; `DecodingError` → `.decoding`; `CancellationError` rethrown as is.
- Mock: per-path FIFO of handlers (`[String: [Handler]]`, `Handler = @Sendable (RecordedRequest) async throws -> any Sendable`); consume front while more than one remains, last repeats; `delay` → `try await Task.sleep(for:)` before returning; unstubbed → record then `throw APIError.client`; cast failure → `throw APIError.decoding`. State in `OSAllocatedUnfairLock<State>`.
- `StubURLProtocol` (test target): `static let handler = OSAllocatedUnfairLock<(@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?>(initialState: nil)`; `URLSessionConfiguration.ephemeral` with `protocolClasses = [StubURLProtocol.self]`.

- [ ] **Step 1: Write failing client tests** (`MovieDatabaseAPIClientTests`, using a test `struct PingRequest: APIRequest { typealias Response = Pong; path "/ping"; queryItems [page=2] }`):
  - `buildsURLWithPathQueryAndAPIKey`: captured request URL == `https://api.themoviedb.org/3/ping?page=2&api_key=KEY` (compare `URLComponents.queryItems` as a set and `path`).
  - `decodesSuccessfulResponse`: 200 + `{"value":"ok"}` → `Pong(value:"ok")`.
  - `unauthorizedMapsToNotAuthenticated`: 401 → `APIError.notAuthenticated`.
  - `serverErrorMapsToNetworkStatus`: 500 → `.network(500)`.
  - `badJSONMapsToDecoding`: 200 + `nope` → `.decoding`.
  - `offlineMapsToUnreachable`: handler throws `URLError(.notConnectedToInternet)` → `.unreachable`.
  - `moduleRegistersClient` (`@MainActor`): `Locator()`; `APIClientModule.registerServices(in:configuration:)`; `isRegistered(.apiClient)`; `resolve(.apiClient)` is `MovieDatabaseAPIClient`.
- [ ] **Step 2: Write failing mock tests** (`MockAPIClientTests`):
  - `returnsStubbedResultAndRecordsRequest`; `fifoConsumesThenRepeatsLast` (stub A then B; calls → A, B, B); `unstubbedThrowsClient`; `handlerSeesQueryItems` (handler returns page from query); `delayIsCancellable` (stub with 10 s delay; `Task` sending; cancel; `await` throws `CancellationError`).
- [ ] **Step 3: Run to verify fail**: `cd $ROOT/MovieDemo/APIClient && swift test 2>&1 | tail -5`.
- [ ] **Step 4: Implement** all source files per Interfaces.
- [ ] **Step 5: Run to verify pass**: 12 tests passed, no warnings.
- [ ] **Step 6: Commit** `feat: add APIClient package with async client, mock and locator registration`

---

### Task 5: AnalyticsClient package

**Files:**
- Create: `$ROOT/MovieDemo/AnalyticsClient/Package.swift` (deps `../Locator`; products `AnalyticsClient`, `AnalyticsClientTesting`)
- Create: `Sources/AnalyticsClient/AnalyticsEvent.swift`, `AnalyticsClient.swift`, `ConsoleAnalyticsClient.swift`, `AnalyticsClientModule.swift`
- Create: `Sources/AnalyticsClientTesting/SpyAnalyticsClient.swift`
- Test: `Tests/AnalyticsClientTests/AnalyticsClientTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct AnalyticsEvent: Equatable, Sendable { public let name: String; public let parameters: [String: String]; public init(name: String, parameters: [String: String] = [:]) }
  public protocol AnalyticsClient: Sendable { func track(_ event: AnalyticsEvent) }
  public struct ConsoleAnalyticsClient: AnalyticsClient { public init() }   // os.Logger(subsystem: "com.glazedsolutions.MovieDemo", category: "Analytics")
  public enum AnalyticsClientModule { public static let requiredKinds: [AnyLocatorKind] = []; @MainActor public static func registerServices(in locator: any DependencyLocator) }
  extension Locator.Kind { public static var analyticsClient: Locator.Kind<any AnalyticsClient> { Locator.Kind("AnalyticsClient") } }
  extension AnyLocatorKind { public static let analyticsClient = AnyLocatorKind("AnalyticsClient") }
  public final class SpyAnalyticsClient: AnalyticsClient, Sendable { public init(); public var events: [AnalyticsEvent] { get }; public func events(named: String) -> [AnalyticsEvent] }
  ```

- [ ] **Step 1: Write failing tests**: `spyRecordsEventsInOrder`, `spyFiltersByName`, `consoleClientTracksWithoutCrashing`, `moduleRegistersConsoleClient` (`@MainActor`).
- [ ] **Step 2: Run to verify fail**: `cd $ROOT/MovieDemo/AnalyticsClient && swift test 2>&1 | tail -5`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify pass**: 4 tests passed.
- [ ] **Step 5: Commit** `feat: add AnalyticsClient package with console client and spy`

---

### Task 6: MovieDetail feature package

**Files:**
- Create: `$ROOT/MovieDemo/MovieDetail/Package.swift` (deps `../Locator ../Protocols ../Models ../APIClient ../AnalyticsClient`; test target deps add `APIClientTesting`, `AnalyticsClientTesting`)
- Create: `Sources/MovieDetail/MovieDetailModule.swift`, `MovieDetailProvider.swift`, `MovieDetailFactory.swift`, `MovieDetailViewController.swift`, `MovieDetailViewModel.swift`, `Repository/MovieDetailRepository.swift`, `Repository/Requests/MovieDetailRequest.swift`, `View/MovieDetailView.swift`
- Test: `Tests/MovieDetailTests/MovieDetailViewModelTests.swift`, `MovieDetailModuleTests.swift`

**Interfaces:**
- Consumes: Task 1 locator API, Task 2 protocols, Task 3 `Movie`/`TMDBImage`, Task 4 `APIClient`/`APIRequest`/`MockAPIClient`, Task 5 analytics.
- Produces (public):
  ```swift
  public protocol MovieDetailProvider { @MainActor func movieDetailViewController(movie: Movie) -> UIViewController }
  public enum MovieDetailModule { public static let requiredKinds: [AnyLocatorKind] = [.apiClient, .analyticsClient]; @MainActor public static func registerServices(in locator: any DependencyLocator) }
  extension Locator.Kind { public static var movieDetailProvider: Locator.Kind<any MovieDetailProvider> { Locator.Kind("MovieDetailProvider") } }
  extension AnyLocatorKind { public static let movieDetailProvider = AnyLocatorKind("MovieDetailProvider") }
  ```
- Internal:
  ```swift
  struct MovieDetailRequest: APIRequest { typealias Response = Movie; let id: Int; var path: String { "/movie/\(id)" }; var queryItems: [URLQueryItem]? { nil } }
  protocol MovieDetailRepository: Sendable { func movieDetails(id: Int) async throws -> Movie }
  final class MovieDetailRepositoryImpl: MovieDetailRepository { init(apiClient: any APIClient) }
  @MainActor @Observable final class MovieDetailViewModel: ViewModel {
    typealias ViewControllerType = MovieDetailViewController
    enum State: Equatable { case idle, loading, loaded, failed(String) }
    private(set) var movie: Movie; private(set) var state: State
    private(set) var currentTask: Task<Void, Never>?          // tests await .value
    init(movie: Movie, repository: any MovieDetailRepository, analytics: any AnalyticsClient)
    func onAppear()   // idempotent: only loads when state == .idle
    func retry()
  }
  protocol MovieDetailFactory { @MainActor func makeMovieDetailViewController(movie: Movie, apiClient: any APIClient, analytics: any AnalyticsClient) -> UIViewController }
  final class MovieDetailFactoryImpl: MovieDetailFactory
  final class MovieDetailProviderImpl: MovieDetailProvider { init(locator: any DependencyLocator) }   // resolves at call time
  final class MovieDetailViewController: UIViewController, ViewModelBindable  // hosts MovieDetailView, title = movie.title, viewWillAppear → onAppear()
  struct MovieDetailView: View { let viewModel: MovieDetailViewModel }   // poster w500, title, tagline, year · runtime min, genre chips, ★ rating, overview; ProgressView overlay while loading; error banner with Retry when failed
  ```
- Analytics: on success `AnalyticsEvent(name: "movie_detail_viewed", parameters: ["movie_id": "\(id)"])`; on failure `("error_shown", ["screen": "movie_detail", "message": msg])`. `msg` = `(error as? LocalizedError)?.errorDescription ?? "Something went wrong."`. `CancellationError` → return silently, state back to `.idle`.

- [ ] **Step 1: Write failing ViewModel tests** (`@MainActor`, MockAPIClient + SpyAnalyticsClient + `MovieDetailRepositoryImpl`):
  - `onAppearLoadsDetailAndTracksViewed`: stub `/movie/7` with a full Movie → after `await vm.currentTask?.value`: `state == .loaded`, `movie.runtime == 120`, spy has `movie_detail_viewed` with `movie_id == "7"`.
  - `onAppearIsIdempotent`: call `onAppear()` twice, await → `receivedRequests.count == 1`.
  - `failureSetsFailedStateAndTracksError`: stub `.failure(.network(500))` → `state == .failed("Network error (status 500).")`, spy has `error_shown` with `screen == "movie_detail"`.
  - `retryReloadsAfterFailure`: FIFO failure then success → after retry, `.loaded`.
  - `moduleRegistersProviderAndProviderBuildsViewController` (in `MovieDetailModuleTests`): `Locator()` with `MockAPIClient` and `SpyAnalyticsClient` registered under `.apiClient`/`.analyticsClient`; `MovieDetailModule.registerServices(in:)`; `missing(from: MovieDetailModule.requiredKinds).isEmpty`; `resolve(.movieDetailProvider).movieDetailViewController(movie:)` is `MovieDetailViewController` and `title == movie.title` after `loadViewIfNeeded()`.
- [ ] **Step 2: Run to verify fail**: `cd $ROOT/MovieDemo/MovieDetail && xcodebuild test -scheme MovieDetail -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' 2>&1 | grep -E "error:|TEST" | head`.
- [ ] **Step 3: Implement** all source files.
- [ ] **Step 4: Run to verify pass**: `** TEST SUCCEEDED **`, and `grep -c "warning:"` on the log == 0.
- [ ] **Step 5: Commit** `feat: add MovieDetail feature package`

---

### Task 7: MovieList feature package

**Files:**
- Create: `$ROOT/MovieDemo/MovieList/Package.swift` (deps as MovieDetail plus `../MovieDetail`)
- Create: `Sources/MovieList/MovieListModule.swift`, `MovieListProvider.swift`, `MovieListFactory.swift`, `MovieListRouter.swift`, `MovieListViewController.swift`, `MovieListViewModel.swift`, `Repository/MovieListRepository.swift`, `Repository/Requests/PopularMoviesRequest.swift`, `Repository/Requests/SearchMoviesRequest.swift`, `View/MovieListView.swift`, `View/MovieCell.swift`, `Previews/MovieListView_Previews.swift`
- Test: `Tests/MovieListTests/MovieListViewModelTests.swift`, `MovieListRepositoryTests.swift`, `MovieListModuleTests.swift`, `Support/SpyMovieListRouter.swift`, `Support/Fixtures.swift`

**Interfaces:**
- Consumes: Task 6 `MovieDetailProvider`, `.movieDetailProvider`, plus everything Task 6 consumes.
- Produces (public):
  ```swift
  public protocol MovieListProvider { @MainActor func movieListViewController() -> UIViewController }
  public enum MovieListModule { public static let requiredKinds: [AnyLocatorKind] = [.apiClient, .analyticsClient, .movieDetailProvider]; @MainActor public static func registerServices(in locator: any DependencyLocator) }
  extension Locator.Kind { public static var movieListProvider: Locator.Kind<any MovieListProvider> { Locator.Kind("MovieListProvider") } }
  extension AnyLocatorKind { public static let movieListProvider = AnyLocatorKind("MovieListProvider") }
  ```
- Internal:
  ```swift
  struct PopularMoviesRequest: APIRequest { typealias Response = MovieListResponse; let page: Int; path "/movie/popular"; queryItems [page] }
  struct SearchMoviesRequest: APIRequest { typealias Response = MovieListResponse; let page: Int; let query: String; path "/search/movie"; queryItems [query, page] }
  protocol MovieListRepository: Sendable { func popularMovies(page: Int) async throws -> MovieListResponse; func searchMovies(query: String, page: Int) async throws -> MovieListResponse }
  final class MovieListRepositoryImpl: MovieListRepository { init(apiClient: any APIClient) }
  protocol MovieListRouter: AnyObject { @MainActor func routeToMovieDetails(movie: Movie) }
  final class MovieListRouterImpl: MovieListRouter { init(viewController: UIViewController, movieDetailProvider: any MovieDetailProvider) }  // weak viewController; pushes on its navigationController
  @MainActor @Observable final class MovieListViewModel: ViewModel {
    typealias ViewControllerType = MovieListViewController
    enum Mode: Equatable { case popular, search(String) }
    private(set) var movies: [Movie]; private(set) var isLoadingFirstPage: Bool; private(set) var isLoadingNextPage: Bool
    private(set) var errorMessage: String?; private(set) var canLoadMore: Bool; private(set) var mode: Mode
    var query: String   // raw text, set by VC
    private(set) var debounceTask: Task<Void, Never>?; private(set) var currentTask: Task<Void, Never>?   // tests await
    init(router: any MovieListRouter, repository: any MovieListRepository, analytics: any AnalyticsClient, debounce: Duration = .milliseconds(300))
    func onAppear()                                     // loads popular page 1 only if movies.isEmpty && !loading; tracks movie_list_viewed once
    func queryChanged(_ text: String)                   // trims; cancels debounceTask + currentTask; new mode; debounce then load page 1
    func loadNextPageIfNeeded(currentItem: Movie)       // within last 5 && canLoadMore && !loading
    func retry()
    func movieWasTapped(_ movie: Movie)
  }
  protocol MovieListFactory { @MainActor func makeMovieListViewController(apiClient:analytics:movieDetailProvider:) -> UIViewController }
  final class MovieListFactoryImpl: MovieListFactory
  final class MovieListProviderImpl: MovieListProvider { init(locator: any DependencyLocator) }
  final class MovieListViewController: UIViewController, ViewModelBindable, UISearchResultsUpdating  // title "Movies"; navigationItem.searchController with placeholder "Search movies"; hidesSearchBarWhenScrolling = false; updateSearchResults → viewModel.queryChanged(text)
  struct MovieListView: View { let viewModel: MovieListViewModel }   // List of MovieCell; row .onAppear → loadNextPageIfNeeded; footer ProgressView when isLoadingNextPage; ContentUnavailableView for empty search; error view with Retry when errorMessage != nil && movies.isEmpty; .overlay ProgressView when isLoadingFirstPage
  struct MovieCell: View { let movie: Movie }   // poster w185 60×90, title (headline), year, ★ rating 1 decimal
  ```
- Load semantics: `loadFirstPage()` increments `requestID`, clears `movies`, sets `isLoadingFirstPage`; fetch; if `requestID` unchanged apply (`movies = dedupe(results)`, `page`, `totalPages`, `canLoadMore = page < totalPages`), track `movie_list_page_loaded` with `page` and `mode` (`"popular"`/`"search"`); in search mode also track `movie_search_performed` with `query` before sending. Errors: `CancellationError` → ignore; else `errorMessage = description`, track `error_shown` with `screen: "movie_list"`. `loadNextPage()` appends with de-dup by id. Whitespace-only text → `.popular`.

- [ ] **Step 1: Write failing repository tests**: `popularRequestHitsPathWithPage` (`receivedRequests.first == RecordedRequest(path:"/movie/popular", queryItems:[page=2], method:.get)`), `searchRequestHitsPathWithQueryAndPage`.
- [ ] **Step 2: Write failing ViewModel tests** (`@MainActor`; `Fixtures.page(_ n: Int, ids: [Int], totalPages: Int) -> MovieListResponse`; `debounce: .milliseconds(10)`):
  - `onAppearLoadsPopularAndTracksViewed`
  - `onAppearIsIdempotentAfterLoad` (second call, no new request)
  - `burstOfKeystrokesSendsOneSearchRequest`: `queryChanged("a")`, `("al")`, `("ali")` back to back; `await debounceTask?.value`; exactly one `/search/movie` request with `query == "ali"`; `movie_search_performed` tracked once.
  - `clearingQueryReturnsToPopular`
  - `whitespaceQueryIsPopularMode`: `queryChanged("   ")` → `mode == .popular`, no `/search/movie` request.
  - `nextPageAppendsAndStopsAtTotalPages`: FIFO page1(ids 1...3,total 2), page2(ids 4...6) → after `loadNextPageIfNeeded(currentItem: movies.last!)` + await: 6 movies, `canLoadMore == false`; another call → no request.
  - `nextPageDeduplicatesById`: page2 contains id 3 → count 5.
  - `staleResponseIsDiscarded`: stub `/movie/popular` with 200 ms delay; `onAppear()`; immediately `queryChanged("x")` (search stub instant); await both tasks → `movies` are the search results, `mode == .search("x")`.
  - `cancellationDoesNotSetError`: same as above → `errorMessage == nil`.
  - `firstPageErrorSetsMessageAndTracks`: `.failure(.network(500))` → `errorMessage == "Network error (status 500)."`, `error_shown` tracked with `screen == "movie_list"`.
  - `errorMessageIsHumanReadable`: `.failure(.notAuthenticated)` → `errorMessage == "Invalid API key."`.
  - `retryClearsErrorAndReloads`
  - `movieTappedRoutesAndTracks`: `SpyMovieListRouter.routed == [movie]`, `movie_selected` with `movie_id`.
- [ ] **Step 3: Write failing module test**: `moduleRegistersProviderAndBuildsViewController` (register mock clients + a stub `MovieDetailProvider` under `.movieDetailProvider`; `missing(from: MovieListModule.requiredKinds).isEmpty`; VC `title == "Movies"` after `loadViewIfNeeded()`; `navigationItem.searchController != nil`).
- [ ] **Step 4: Run to verify fail**: `cd $ROOT/MovieDemo/MovieList && xcodebuild test -scheme MovieList -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' 2>&1 | grep -E "error:|TEST" | head`.
- [ ] **Step 5: Implement** all source files.
- [ ] **Step 6: Run to verify pass**: `** TEST SUCCEEDED **`, zero warnings.
- [ ] **Step 7: Commit** `feat: add MovieList feature package with debounced search and paging`

---

### Task 8: App target, project generation, README

**Files:**
- Create: `$ROOT/project.yml`, `$ROOT/README.md`
- Create: `$ROOT/MovieDemo/AppDelegate.swift`, `SceneDelegate.swift`, `AppRouter.swift`, `MissingAPIKeyViewController.swift`, `Resources/Assets.xcassets` (AppIcon + AccentColor placeholders)
- Test: `$ROOT/MovieDemoTests/AppRouterTests.swift`

**Interfaces:**
- Consumes: all module `registerServices`/`requiredKinds`, `.movieListProvider`.
- Produces:
  ```swift
  @MainActor final class AppRouter {
    init(window: UIWindow)
    func start()   // reads Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String; empty → MissingAPIKeyViewController as root; else setupLocator + UINavigationController(root: movieListViewController())
    static func setupLocator(configuration: APIConfiguration) -> Locator   // registers 4 modules, verify(allOf: all requiredKinds), returns fresh locator
  }
  final class MissingAPIKeyViewController: UIViewController   // centered label: "Missing TMDB API key.\nCopy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig, add your key, and run xcodegen generate."
  ```
- `project.yml` essentials: `name: MovieDemo`; `options: { bundleIdPrefix: com.glazedsolutions, deploymentTarget: { iOS: "17.0" }, xcodeVersion: "26.3", createIntermediateGroups: true }`; `packages:` seven local `path: MovieDemo/<Name>`; target `MovieDemo` (`type: application`, `platform: iOS`, `sources: [{ path: MovieDemo, excludes: ["Locator/**","Protocols/**","Models/**","APIClient/**","AnalyticsClient/**","MovieList/**","MovieDetail/**","**/.swiftpm/**","**/.build/**"] }]`, `dependencies: [package: MovieList, package: MovieDetail, package: APIClient, package: AnalyticsClient, package: Locator, package: Models, package: Protocols]`, `configFiles: { Debug: Config/App.xcconfig, Release: Config/App.xcconfig }`, `settings: { SWIFT_VERSION: "6.0", SWIFT_STRICT_CONCURRENCY: complete, GENERATE_INFOPLIST_FILE: YES, INFOPLIST_KEY_UILaunchScreen_Generation: YES }`, `info: { path: MovieDemo/Info.plist, properties: { TMDBAPIKey: "$(TMDB_API_KEY)", UIApplicationSceneManifest: {...SceneDelegate, no storyboard}, UILaunchScreen: {} } }`); target `MovieDemoTests` (`bundle.unit-test`, `sources: MovieDemoTests`, `dependencies: [target: MovieDemo]`); `schemes: MovieDemo: { build: { targets: { MovieDemo: all } }, test: { targets: [MovieDemoTests, { package: Locator/LocatorTests }, { package: Protocols/ProtocolsTests }, { package: Models/ModelsTests }, { package: APIClient/APIClientTests }, { package: AnalyticsClient/AnalyticsClientTests }, { package: MovieDetail/MovieDetailTests }, { package: MovieList/MovieListTests }] } }`. `MovieDemo/Info.plist` is generated; add it to `.gitignore`.

- [ ] **Step 1: Write failing app test** (`@MainActor`): `setupLocatorRegistersEverything`: `AppRouter.setupLocator(configuration: .movieDatabase(apiKey: "test"))`; `missing(from: APIClientModule.requiredKinds + AnalyticsClientModule.requiredKinds + MovieDetailModule.requiredKinds + MovieListModule.requiredKinds).isEmpty`; `resolve(.movieListProvider).movieListViewController()` is a `UIViewController`.
- [ ] **Step 2: Write `project.yml`, app sources, README.** README sections: What this is, Architecture (module list + one line each, locator rules), Setup (`brew install xcodegen`, copy secrets, `xcodegen generate`, open), Build & test commands, Module dependency graph.
- [ ] **Step 3: Generate and build**: `cd $ROOT && xcodegen generate && xcodebuild -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' build 2>&1 | grep -E "warning:|error:|BUILD" | head` → `** BUILD SUCCEEDED **`, no warnings.
- [ ] **Step 4: Run full test suite**: `xcodebuild test -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' 2>&1 | grep -E "Test Suite|Executed|TEST|error:" | tail -20` → `** TEST SUCCEEDED **`, all eight test bundles listed.
- [ ] **Step 5: Verify secret hygiene**: `git ls-files | xargs grep -l <key>` → no output; `git status --porcelain | grep Secrets.xcconfig` → only the example.
- [ ] **Step 6: Commit** `feat: add app target, composition root, project spec and README`

---

### Task 9: Simulator verification

**Files:** none created (screenshots in scratchpad).

- [ ] **Step 1: Boot and install**: `xcrun simctl boot "iPhone 16"` (18.4 UDID from `xcrun simctl list devices`); `xcodebuild -scheme MovieDemo -destination ... -derivedDataPath /tmp/... build`; `xcrun simctl install <udid> <path/MovieDemo.app>`; `xcrun simctl launch <udid> com.glazedsolutions.MovieDemo`.
- [ ] **Step 2: Screenshot the list after 3 s**: `xcrun simctl io <udid> screenshot <scratchpad>/list.png`; view it; expect populated rows with posters.
- [ ] **Step 3: Search**: tap the search field via `xcrun simctl` is not scriptable; instead verify search behaviour through the unit tests (Task 7) and by `xcrun simctl spawn <udid> log stream --predicate 'subsystem == "com.glazedsolutions.MovieDemo"'` showing `movie_list_page_loaded` events after launch.
- [ ] **Step 4: Detail**: `xcrun simctl openurl` is unavailable for this app; rely on `MovieDetailModuleTests` plus a manual note in the final report asking the owner to tap a row.
- [ ] **Step 5: Record outcome** in the final message (what was verified automatically, what remains manual).
