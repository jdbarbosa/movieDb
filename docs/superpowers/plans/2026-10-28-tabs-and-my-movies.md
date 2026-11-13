# Tab Bar and My Movies Placeholder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-tab shell (Discover, My Movies) where My Movies is a new feature package showing three no-op buttons, wired through the existing locator and composition root.

**Architecture:** A new `MyMovies` Swift Package with the same parts as `MovieList` (`Module`, `Provider`, `Factory`, `Router`, `Repository`, `ViewModel`, `ViewController`, SwiftUI `View`). `AppRouter` registers it, then builds a `UITabBarController` from the `MovieList` and `MyMovies` providers, each inside its own `UINavigationController`. The modules do not know about tabs.

**Tech Stack:** Swift 6 strict concurrency, iOS 17 deployment target, SwiftPM local packages, XcodeGen, Swift Testing, UIKit hosting SwiftUI via `UIHostingController`, `@MainActor @Observable` view models.

**Spec:** `docs/superpowers/specs/2026-10-28-tabs-and-my-movies-design.md` (extends `docs/superpowers/specs/2026-10-23-moviedemo-architecture-design.md`)

## Global Constraints

- Project root `/Users/v.joao.diasbarbosa/Documents/Glazed/iOS/claude_generated`, abbreviated `$ROOT`. Run every `xcodebuild` from `$ROOT`.
- Test command for every verification step, abbreviated `TEST` below:
  `xcodebuild test -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4'`. Append `-only-testing:MyMoviesTests` or `-only-testing:MovieDemoTests` where a step says so; the final task runs the whole scheme. Passing output ends in `** TEST SUCCEEDED **`.
- The Xcode project is generated. Edit `$ROOT/project.yml`, then run `xcodegen generate` from `$ROOT`. Never edit `.xcodeproj`.
- `Package.swift` for the new package: `// swift-tools-version: 6.0`, `platforms: [.iOS(.v17)]`, local path dependencies only. Copy `MovieDemo/MovieDetail/Package.swift` as the template.
- Zero compiler warnings. No `@unchecked Sendable` or `nonisolated(unsafe)`.
- Code style: 2-space indentation, as the rest of the repo. The owner's editor sometimes converts files to tabs on save; before committing any file, run `grep -c $'^\t' <file>` and expect `0`.
- Two uncommitted owner changes live in the working tree and must never be committed: a hard-coded API key in `MovieDemo/AppRouter.swift` and a whitespace-only re-indent of `MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailViewModel.swift`. Task 5 has the procedure for `AppRouter.swift`. Never `git add -A` or `git add .`; always add files by name.
- Analytics event names exactly: `my_movies_viewed`, `my_movies_section_tapped` with parameter key `section` and values `watchlist`, `seen`, `favourites`.
- Copy exactly: tab titles `Discover` and `My Movies`; SF Symbols `safari` and `film.stack` for the tabs; section titles `Watchlist`, `Seen`, `Favourites`; section symbols `bookmark`, `checkmark.circle`, `heart`; list screen title `Discover`; My Movies screen title `My Movies`.
- Locator key id for the new provider: `"MyMoviesProvider"`.
- Commit after each task with a conventional-commit message ending in `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. Launch without an API key must still show `MissingAPIKeyViewController` and no tab bar. Test in Task 5 (`startWithoutKeyShowsMissingKeyScreen`).
2. The app must open on Discover, never on My Movies. Test in Task 5 (`startWithKeyShowsTabBarOnDiscover`).
3. Returning to the My Movies tab must not re-track `my_movies_viewed`; `viewWillAppear` fires on every tab switch. Test in Task 2 (`onAppearTracksViewedOnce`).
4. Both tabs must show large titles, since `prefersLargeTitles` is now set per navigation controller by `AppRouter`, not by the module. Test in Task 5 (`startWithKeyShowsTabBarOnDiscover` asserts it).
5. The no-op repository must return empty for every section, not trap or throw, so the storage step can swap it in behind an unchanged protocol. Test in Task 1 (`noOpRepositoryReturnsEmptyForEverySection`).

---

### Task 1: MyMovies package scaffold, `MyMoviesSection`, no-op repository

**Files:**
- Create: `MovieDemo/MyMovies/Package.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesSection.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/Repository/MyMoviesRepository.swift`
- Create: `MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesSectionTests.swift`
- Create: `MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesRepositoryTests.swift`
- Modify: `project.yml` (packages, app target excludes and dependencies, scheme test targets)

**Interfaces:**
- Produces:
  ```swift
  enum MyMoviesSection: CaseIterable, Sendable, Equatable {
    case watchlist, seen, favourites
    var title: String
    var systemImage: String
    var analyticsName: String
  }
  protocol MyMoviesRepository: Sendable {
    func movies(in section: MyMoviesSection) async throws -> [Movie]
  }
  final class NoOpMyMoviesRepository: MyMoviesRepository { init() }
  ```

- [ ] **Step 1: Create `Package.swift`**

Name `MyMovies`, one library product `MyMovies`, dependencies `../Locator`, `../Protocols`, `../Models`, `../AnalyticsClient`. Target `MyMovies` depends on `"Locator", "Protocols", "Models", "AnalyticsClient"`. Test target `MyMoviesTests` depends on `"MyMovies"` and `.product(name: "AnalyticsClientTesting", package: "AnalyticsClient")`. No `APIClient`.

- [ ] **Step 2: Wire the package into `project.yml`**

Add under `packages:` → `MyMovies: { path: MovieDemo/MyMovies }`. Add `"MyMovies/**"` to the app target's `sources[0].excludes`. Add `- package: MyMovies` to the app target's `dependencies`. Add `- package: MyMovies/MyMoviesTests` to `schemes.MovieDemo.test.targets`. Run `xcodegen generate` from `$ROOT`; expected output ends with `Created project at MovieDemo.xcodeproj` (or similar success line) and no warnings about missing paths.

- [ ] **Step 3: Write the failing tests**

`MyMoviesSectionTests.swift`:

```swift
import Testing
@testable import MyMovies

@Suite("MyMoviesSection")
struct MyMoviesSectionTests {

  @Test func casesAreInDisplayOrder() {
    #expect(MyMoviesSection.allCases == [.watchlist, .seen, .favourites])
  }

  @Test func titlesSymbolsAndAnalyticsNames() {
    #expect(MyMoviesSection.allCases.map(\.title) == ["Watchlist", "Seen", "Favourites"])
    #expect(MyMoviesSection.allCases.map(\.systemImage) == ["bookmark", "checkmark.circle", "heart"])
    #expect(MyMoviesSection.allCases.map(\.analyticsName) == ["watchlist", "seen", "favourites"])
  }
}
```

`MyMoviesRepositoryTests.swift`:

```swift
import Testing
@testable import MyMovies

@Suite("NoOpMyMoviesRepository")
struct MyMoviesRepositoryTests {

  @Test(arguments: MyMoviesSection.allCases)
  func noOpRepositoryReturnsEmptyForEverySection(section: MyMoviesSection) async throws {
    let repository = NoOpMyMoviesRepository()
    let movies = try await repository.movies(in: section)
    #expect(movies.isEmpty)
  }
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `TEST -only-testing:MyMoviesTests`
Expected: build failure, `cannot find 'MyMoviesSection' in scope` (or equivalent).

- [ ] **Step 5: Implement `MyMoviesSection` in `MyMoviesSection.swift`**

The enum from Interfaces. `title`, `systemImage` and `analyticsName` are computed properties switching over `self` with the exact strings from Global Constraints.

- [ ] **Step 6: Implement `MyMoviesRepository` and `NoOpMyMoviesRepository` in `Repository/MyMoviesRepository.swift`**

`import Models`. The protocol from Interfaces. `NoOpMyMoviesRepository` returns `[]`. One doc comment on the class: the real store arrives with the persistence step; this exists so the factory and view model are already wired.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `TEST -only-testing:MyMoviesTests`
Expected: `Test run with 3 tests in 2 suites passed` and `** TEST SUCCEEDED **`. Swift Testing counts test functions, so the parameterised repository test is one test with three cases.

- [ ] **Step 8: Commit**

```bash
git add project.yml MovieDemo/MyMovies/Package.swift MovieDemo/MyMovies/Sources MovieDemo/MyMovies/Tests
git commit -m "feat: scaffold MyMovies package with sections and no-op repository"
```

---

### Task 2: `MyMoviesRouter` and `MyMoviesViewModel`

**Files:**
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesRouter.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesViewModel.swift`
- Create: `MovieDemo/MyMovies/Tests/MyMoviesTests/Support/SpyMyMoviesRouter.swift`
- Create: `MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesViewModelTests.swift`

**Interfaces:**
- Consumes: `MyMoviesSection`, `MyMoviesRepository` from Task 1.
- Produces:
  ```swift
  protocol MyMoviesRouter: AnyObject {
    @MainActor func routeTo(section: MyMoviesSection)
  }
  @MainActor final class MyMoviesRouterImpl: MyMoviesRouter {
    init(viewController: UIViewController)   // held weak
  }
  @MainActor @Observable final class MyMoviesViewModel: ViewModel {
    typealias ViewControllerType = MyMoviesViewController   // defined in Task 3
    let sections: [MyMoviesSection]
    init(router: any MyMoviesRouter, repository: any MyMoviesRepository, analytics: any AnalyticsClient)
    func onAppear()
    func sectionTapped(_ section: MyMoviesSection)
  }
  ```
  Note: `MyMoviesViewController` does not exist until Task 3. In this task declare the view model **without** the `ViewModel` conformance and typealias; Task 3 adds both. The tests here do not need them.

- [ ] **Step 1: Write the spy router**

```swift
@testable import MyMovies

@MainActor
final class SpyMyMoviesRouter: MyMoviesRouter {
  private(set) var routed: [MyMoviesSection] = []

  func routeTo(section: MyMoviesSection) {
    routed.append(section)
  }
}
```

- [ ] **Step 2: Write the failing view model tests**

```swift
import Testing
import AnalyticsClient
import AnalyticsClientTesting
@testable import MyMovies

@Suite("MyMoviesViewModel")
@MainActor
struct MyMoviesViewModelTests {

  @MainActor
  private struct Harness {
    let spy = SpyAnalyticsClient()
    let router = SpyMyMoviesRouter()
    let viewModel: MyMoviesViewModel

    init() {
      viewModel = MyMoviesViewModel(router: router, repository: NoOpMyMoviesRepository(), analytics: spy)
    }
  }

  @Test func sectionsAreAllCasesInOrder() {
    let h = Harness()
    #expect(h.viewModel.sections == MyMoviesSection.allCases)
  }

  @Test func onAppearTracksViewedOnce() {
    let h = Harness()
    h.viewModel.onAppear()
    h.viewModel.onAppear()
    #expect(h.spy.events(named: "my_movies_viewed") == [AnalyticsEvent(name: "my_movies_viewed")])
  }

  @Test(arguments: MyMoviesSection.allCases)
  func sectionTappedTracksAndRoutes(section: MyMoviesSection) {
    let h = Harness()
    h.viewModel.sectionTapped(section)
    #expect(h.spy.events(named: "my_movies_section_tapped") == [
      AnalyticsEvent(name: "my_movies_section_tapped", parameters: ["section": section.analyticsName])
    ])
    #expect(h.router.routed == [section])
  }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `TEST -only-testing:MyMoviesTests`
Expected: build failure, `cannot find type 'MyMoviesRouter' in scope`.

- [ ] **Step 4: Implement `MyMoviesRouter.swift`**

`import UIKit`. The protocol and `MyMoviesRouterImpl` from Interfaces. `viewController` is `private weak var`, with the same one-line comment `MovieListRouterImpl` carries about ownership. `routeTo(section:)` has an empty body and a comment: destination screens arrive with the persistence step.

- [ ] **Step 5: Implement `MyMoviesViewModel.swift`**

`import Foundation`, `import Observation`, `import AnalyticsClient`. Stored `router`, `repository`, `analytics` are `@ObservationIgnored private let`; `hasAppeared` is `@ObservationIgnored private var`. `sections` is `let sections = MyMoviesSection.allCases`. `onAppear()` tracks `AnalyticsEvent(name: "my_movies_viewed")` only when `hasAppeared` was false, then sets it. `sectionTapped` tracks `AnalyticsEvent(name: "my_movies_section_tapped", parameters: ["section": section.analyticsName])` then calls `router.routeTo(section:)`. The repository is stored and not used; add a one-line comment saying so.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `TEST -only-testing:MyMoviesTests`
Expected: `Test run with 6 tests in 3 suites passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add MovieDemo/MyMovies/Sources/MyMovies/MyMoviesRouter.swift MovieDemo/MyMovies/Sources/MyMovies/MyMoviesViewModel.swift MovieDemo/MyMovies/Tests/MyMoviesTests/Support/SpyMyMoviesRouter.swift MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesViewModelTests.swift
git commit -m "feat: add MyMovies router and view model"
```

---

### Task 3: Screen, factory, provider and module registration

**Files:**
- Create: `MovieDemo/MyMovies/Sources/MyMovies/View/MyMoviesView.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesViewController.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesFactory.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesProvider.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesModule.swift`
- Create: `MovieDemo/MyMovies/Sources/MyMovies/Previews/MyMoviesView_Previews.swift`
- Modify: `MovieDemo/MyMovies/Sources/MyMovies/MyMoviesViewModel.swift` (add `ViewModel` conformance and typealias)
- Create: `MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesModuleTests.swift`

**Interfaces:**
- Consumes: `MyMoviesViewModel`, `MyMoviesRouterImpl`, `NoOpMyMoviesRepository` from Tasks 1 and 2.
- Produces (public, used by Task 5):
  ```swift
  public enum MyMoviesModule {
    public static let requiredKinds: [AnyLocatorKind] = [.analyticsClient]
    @MainActor public static func registerServices(in locator: any DependencyLocator)
  }
  extension Locator.Kind { public static var myMoviesProvider: Locator.Kind<any MyMoviesProvider> }   // id "MyMoviesProvider"
  extension AnyLocatorKind { public static let myMoviesProvider: AnyLocatorKind }                      // = Locator.Kind<any MyMoviesProvider>.myMoviesProvider.erased
  public protocol MyMoviesProvider {
    @MainActor func myMoviesViewController() -> UIViewController
  }
  ```
  Internal: `protocol MyMoviesFactory { @MainActor func makeMyMoviesViewController(analytics: any AnalyticsClient) -> UIViewController }`, `MyMoviesFactoryImpl`, `MyMoviesProviderImpl(locator:factory:)`, `MyMoviesViewController: UIViewController, ViewModelBindable` with `typealias ViewModelType = MyMoviesViewModel`.

- [ ] **Step 1: Write the failing module test**

```swift
import Testing
import UIKit
import Locator
import AnalyticsClientTesting
@testable import MyMovies

@Suite("MyMoviesModule")
@MainActor
struct MyMoviesModuleTests {

  @Test func moduleRegistersProviderAndBuildsViewController() {
    let locator = Locator()
    locator.register(.analyticsClient, SpyAnalyticsClient())

    MyMoviesModule.registerServices(in: locator)

    #expect(locator.missing(from: MyMoviesModule.requiredKinds).isEmpty)
    #expect(locator.isRegistered(.myMoviesProvider))

    let viewController = locator.resolve(.myMoviesProvider).myMoviesViewController()
    viewController.loadViewIfNeeded()
    #expect(viewController is MyMoviesViewController)
    #expect(viewController.title == "My Movies")
    #expect(viewController.navigationItem.largeTitleDisplayMode == .always)
  }

  @Test func providerKeyIdIsStable() {
    #expect(AnyLocatorKind.myMoviesProvider == AnyLocatorKind("MyMoviesProvider"))
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `TEST -only-testing:MyMoviesTests`
Expected: build failure, `cannot find 'MyMoviesModule' in scope`.

- [ ] **Step 3: Implement `View/MyMoviesView.swift`**

`struct MyMoviesView: View { let viewModel: MyMoviesViewModel }`. Body: a `VStack(spacing: 16)` of `ForEach(viewModel.sections, id: \.self)` producing a `Button` that calls `viewModel.sectionTapped(section)`, labelled `Label(section.title, systemImage: section.systemImage)`, `.frame(maxWidth: .infinity)`, `.buttonStyle(.bordered)`, `.controlSize(.large)`. Wrap the stack in `.padding(.horizontal, 24)` and `.frame(maxHeight: .infinity)` so it centres vertically. Not a `List`.

- [ ] **Step 4: Implement `MyMoviesViewController.swift`**

Copy the shape of `MovieDemo/MovieList/Sources/MovieList/MovieListViewController.swift` minus the search controller and `UISearchResultsUpdating`: `init()`, unavailable `init?(coder:)`, `bind(viewModel:)` embedding `UIHostingController(rootView: MyMoviesView(viewModel: viewModel))` with the same four constraints, `viewDidLoad` sets `title = "My Movies"`, `view.backgroundColor = .systemBackground`, `navigationItem.largeTitleDisplayMode = .always`; `viewWillAppear` calls `viewModel?.onAppear()`.

- [ ] **Step 5: Add `ViewModel` conformance to `MyMoviesViewModel`**

`import Protocols`; declare `final class MyMoviesViewModel: ViewModel` with `typealias ViewControllerType = MyMoviesViewController`.

- [ ] **Step 6: Implement `MyMoviesFactory.swift`**

Protocol and `MyMoviesFactoryImpl` from Interfaces. The implementation creates `MyMoviesViewController()`, `NoOpMyMoviesRepository()`, `MyMoviesRouterImpl(viewController:)`, `MyMoviesViewModel(router:repository:analytics:)`, calls `viewController.bind(viewModel:)`, returns the view controller.

- [ ] **Step 7: Implement `MyMoviesProvider.swift`**

Public protocol from Interfaces. `MyMoviesProviderImpl` is `@MainActor final class`, with `private unowned let locator: any DependencyLocator` (comment: the locator owns this provider, so it always outlives it; `unowned` breaks the `Locator → Provider → Locator` cycle) and `private let factory: any MyMoviesFactory`, `init(locator:factory: = MyMoviesFactoryImpl())`. `myMoviesViewController()` calls `factory.makeMyMoviesViewController(analytics: locator.resolve(.analyticsClient))`.

- [ ] **Step 8: Implement `MyMoviesModule.swift`**

Exactly the shape of `MovieDemo/MovieList/Sources/MovieList/MovieListModule.swift` with the names from Interfaces: `requiredKinds = [.analyticsClient]`, `registerServices` registers the closure `{ locator in MyMoviesProviderImpl(locator: locator) }`, the `Locator.Kind` extension with id `"MyMoviesProvider"`, and the `AnyLocatorKind` extension deriving from `.erased`.

- [ ] **Step 9: Add `Previews/MyMoviesView_Previews.swift`**

`#if DEBUG`. A private `PreviewRouter: MyMoviesRouter` with an empty `routeTo`, a private `PreviewAnalytics: AnalyticsClient` with an empty `track`, and one `#Preview("My Movies")` building `MyMoviesViewModel(router: PreviewRouter(), repository: NoOpMyMoviesRepository(), analytics: PreviewAnalytics())` and wrapping `MyMoviesView` in a `NavigationStack` with `.navigationTitle("My Movies")`. Mirror `MovieList/Sources/MovieList/Previews/MovieListView_Previews.swift`.

- [ ] **Step 10: Run the tests to verify they pass**

Run: `TEST -only-testing:MyMoviesTests`
Expected: `Test run with 8 tests in 4 suites passed` and `** TEST SUCCEEDED **`. Also confirm the build log shows no `warning:` lines for files under `MovieDemo/MyMovies/`.

- [ ] **Step 11: Commit**

```bash
git add MovieDemo/MyMovies/Sources MovieDemo/MyMovies/Tests/MyMoviesTests/MyMoviesModuleTests.swift
git commit -m "feat: add MyMovies screen, factory, provider and module"
```

---

### Task 4: Rename the list screen to "Discover"

**Files:**
- Modify: `MovieDemo/MovieList/Sources/MovieList/MovieListViewController.swift` (the `title = "Movies"` line in `viewDidLoad`)
- Modify: `MovieDemo/MovieList/Tests/MovieListTests/MovieListModuleTests.swift` (the `title == "Movies"` assertion)

**Interfaces:** none.

- [ ] **Step 1: Change the test assertion to `"Discover"`**

In `MovieListModuleTests.moduleRegistersProviderAndBuildsViewController`, replace `#expect(viewController.title == "Movies")` with `#expect(viewController.title == "Discover")`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `TEST -only-testing:MovieListTests`
Expected: one failure, `Expectation failed: (viewController.title → "Movies") == "Discover"`.

- [ ] **Step 3: Change the title**

In `MovieListViewController.viewDidLoad`, `title = "Discover"`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `TEST -only-testing:MovieListTests`
Expected: `Test run with 20 tests in 3 suites passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add MovieDemo/MovieList/Sources/MovieList/MovieListViewController.swift MovieDemo/MovieList/Tests/MovieListTests/MovieListModuleTests.swift
git commit -m "feat: title the list screen Discover to match its tab"
```

---

### Task 5: `AppRouter` builds the tab bar

**Files:**
- Modify: `MovieDemo/AppRouter.swift`
- Modify: `MovieDemoTests/AppRouterTests.swift`

**Interfaces:**
- Consumes: `MyMoviesModule`, `.myMoviesProvider` from Task 3; `.movieListProvider` from `MovieList`.
- Produces (internal to the app target):
  ```swift
  @MainActor final class AppRouter {
    init(window: UIWindow)
    func start()                       // reads the key from Bundle.main, calls start(apiKey:)
    func start(apiKey: String)         // "" → MissingAPIKeyViewController root; otherwise tab bar root
    static func setupLocator(configuration: APIConfiguration) -> Locator
  }
  ```
  The spec suggested `makeRootViewController(locator:)`; `start(apiKey:)` is chosen instead because it also lets the missing-key path be tested. Record this in the commit message.

- [ ] **Step 1: Prepare `AppRouter.swift` for a clean commit**

The working tree copy has the owner's hard-coded key and tab indentation. Before editing, record the key line so you can restore it locally afterwards: `git diff MovieDemo/AppRouter.swift | grep '^+.*apiKey ='` and keep that output outside the repo (do not paste it into any file you commit). Then convert indentation to two spaces: `perl -pi -e 's/^(\t+)/"  " x length($1)/e; s/^[ \t]+$//' MovieDemo/AppRouter.swift`, and restore the key line to the committed form:
`let apiKey = (Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String ?? "")`.
Check: `git diff MovieDemo/AppRouter.swift` should now show only the register-order swap and a blank line, or nothing.

- [ ] **Step 2: Write the failing tests**

Replace the body of `MovieDemoTests/AppRouterTests.swift` with:

```swift
import Testing
import UIKit
import APIClient
import AnalyticsClient
import Locator
import MovieDetail
import MovieList
import MyMovies
@testable import MovieDemo

@Suite("AppRouter")
@MainActor
struct AppRouterTests {

  @Test func setupLocatorRegistersEverything() {
    let locator = AppRouter.setupLocator(configuration: .movieDatabase(apiKey: "test"))

    let required = APIClientModule.requiredKinds
      + AnalyticsClientModule.requiredKinds
      + MovieDetailModule.requiredKinds
      + MovieListModule.requiredKinds
      + MyMoviesModule.requiredKinds
    #expect(locator.missing(from: required).isEmpty)
    #expect(locator.isRegistered(.movieListProvider))
    #expect(locator.isRegistered(.myMoviesProvider))

    #expect(locator.resolve(.movieListProvider).movieListViewController().isKind(of: UIViewController.self))
    #expect(locator.resolve(.myMoviesProvider).myMoviesViewController().isKind(of: UIViewController.self))
  }

  @Test func startWithKeyShowsTabBarOnDiscover() throws {
    let window = UIWindow()
    let router = AppRouter(window: window)

    router.start(apiKey: "test")

    let tabBar = try #require(window.rootViewController as? UITabBarController)
    let tabs = try #require(tabBar.viewControllers as? [UINavigationController])
    #expect(tabs.count == 2)
    #expect(tabBar.selectedIndex == 0)
    #expect(tabs.map(\.tabBarItem.title) == ["Discover", "My Movies"])
    #expect(tabs.allSatisfy { $0.navigationBar.prefersLargeTitles })
    #expect(tabs.allSatisfy { $0.tabBarItem.image != nil })   // symbol names are pinned in Global Constraints, not comparable here
  }

  @Test func startWithoutKeyShowsMissingKeyScreen() {
    let window = UIWindow()
    let router = AppRouter(window: window)

    router.start(apiKey: "   ")

    #expect(window.rootViewController is MissingAPIKeyViewController)
  }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `TEST -only-testing:MovieDemoTests`
Expected: build failure, `no such module 'MyMovies'` or `cannot find 'MyMoviesModule' in scope`, and `value of type 'AppRouter' has no member 'start(apiKey:)'`.

- [ ] **Step 4: Implement the `AppRouter` changes**

`import MyMovies`. Split `start()`: it reads and trims the key from `Bundle.main` exactly as today and calls `start(apiKey:)`. `start(apiKey:)` trims, and on empty sets `MissingAPIKeyViewController()` as root and returns; otherwise builds the locator via `setupLocator`, stores it, and sets the tab bar as root. Keep `locator` stored as today.

In `setupLocator`, add `MyMoviesModule.registerServices(in: locator)` after the existing four calls and `+ MyMoviesModule.requiredKinds` to `verify(allOf:)`. Restore the original `MovieDetail` before `MovieList` order and remove the stray blank line.

Add a private helper `static func makeTab(root: UIViewController, title: String, systemImage: String, tag: Int) -> UINavigationController` that wraps `root` in a `UINavigationController`, sets `navigationBar.prefersLargeTitles = true`, and `tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: systemImage), tag: tag)`. Build `discover` from `locator.resolve(.movieListProvider).movieListViewController()` with `"Discover"`, `"safari"`, `0`; build `myMovies` from `locator.resolve(.myMoviesProvider).myMoviesViewController()` with `"My Movies"`, `"film.stack"`, `1`. `UITabBarController()` with `viewControllers = [discover, myMovies]`, `selectedIndex = 0`, set as `window.rootViewController`.

Update the class doc comment to mention the tab bar.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `TEST -only-testing:MovieDemoTests`
Expected: `Test run with 3 tests in 1 suite passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 6: Verify the file is clean to commit**

Run: `grep -c $'^\t' MovieDemo/AppRouter.swift` → `0`. Run: `grep -n 'apiKey = "' MovieDemo/AppRouter.swift` → no output. Run: `git diff MovieDemo/AppRouter.swift | grep -i 'bundle.main'` → shows no removed `Bundle.main` line.

- [ ] **Step 7: Commit**

```bash
git add MovieDemo/AppRouter.swift MovieDemoTests/AppRouterTests.swift
git commit -m "feat: host Discover and My Movies in a tab bar

start(apiKey:) is split out of start() so both the missing-key and the
tab-bar paths are testable; the spec's makeRootViewController(locator:)
is folded into it."
```

Then verify the committed content: `git show HEAD:MovieDemo/AppRouter.swift | grep -c 'Bundle.main'` → `1`.

- [ ] **Step 8: Restore the owner's local key**

Re-apply the hard-coded key line recorded in Step 1 to the working copy of `MovieDemo/AppRouter.swift` so the owner's local run keeps working. `git diff MovieDemo/AppRouter.swift` must show exactly that one line changed. This change stays uncommitted.

---

### Task 6: README and full verification

**Files:**
- Modify: `README.md`

**Interfaces:** none.

- [ ] **Step 1: Update the README**

Intro paragraph: "Two tabs: Discover, a searchable, infinitely scrolling list of movies with a detail screen, and My Movies, a placeholder for the user's watchlist, seen and favourite movies." Module table: add a row `` `MyMovies` | Feature: same shape as MovieList with a no-op Repository and Router. Three buttons that only track analytics for now. `` Dependency graph: add a branch `App ──> MyMovies ──> AnalyticsClient, Models, Protocols`. UI paragraph: mention `UITabBarController` hosting one `UINavigationController` per tab. Design docs list: add `docs/superpowers/specs/2026-10-28-tabs-and-my-movies-design.md` and `docs/superpowers/plans/2026-10-28-tabs-and-my-movies.md`.

- [ ] **Step 2: Run the full suite**

Run: `TEST` (whole scheme, no `-only-testing`).
Expected: `** TEST SUCCEEDED **` with these per-target lines present: `MyMoviesTests` 8 tests in 4 suites, `MovieListTests` 20 tests in 3 suites, `MovieDemoTests` 3 tests in 1 suite, and every other target's count unchanged from before this plan (Locator 7, Protocols 1, Models 5, APIClient 13, AnalyticsClient 4, MovieDetail 5).

- [ ] **Step 3: Check for warnings and leaked secrets**

Run: `xcodebuild -scheme MovieDemo -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.4' build 2>&1 | grep -c 'warning:'` → `0`.
Run: `git grep -n 'apiKey = "'` → no output.

- [ ] **Step 4: Check the working tree**

Run: `git status --short`. Expected: exactly two modified files, `MovieDemo/AppRouter.swift` (the owner's local key line) and `MovieDemo/MovieDetail/Sources/MovieDetail/MovieDetailViewModel.swift` (the owner's whitespace change). Nothing untracked.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: describe the tab bar and MyMovies module in the README"
```
