import Testing
import UIKit
import APIClient
import AnalyticsClient
import Locator
import MovieDetail
import MovieList
import MyMovies
import MovieStore
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
      + MovieStoreModule.requiredKinds
    #expect(locator.missing(from: required).isEmpty)
    #expect(locator.isRegistered(.movieListProvider))
    #expect(locator.isRegistered(.myMoviesProvider))
    #expect(locator.isRegistered(.movieStore))

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
