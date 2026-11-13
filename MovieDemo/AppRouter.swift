import UIKit
import AnalyticsClient
import APIClient
import Locator
import MovieDetail
import MovieList
import MovieStore
import MyMovies

/// Composition root. Owns the window, builds the locator and shows the tab bar
/// with one navigation stack per tab.
@MainActor
final class AppRouter {

  private let window: UIWindow
  private var locator: Locator?

  init(window: UIWindow) {
    self.window = window
  }

  func start() {
    let apiKey = "181af7fcab50e40fabe2d10cc8b90e37"
    start(apiKey: apiKey)
  }

  /// Empty key: the missing-key screen. Otherwise: the locator and the tab bar.
  func start(apiKey: String) {
    let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else {
      window.rootViewController = MissingAPIKeyViewController()
      return
    }

    let locator = Self.setupLocator(configuration: .movieDatabase(apiKey: apiKey))
    self.locator = locator

    let discover = Self.makeTab(
      root: locator.resolve(.movieListProvider).movieListViewController(),
      title: "Discover",
      systemImage: "safari",
      tag: 0
    )
    let myMovies = Self.makeTab(
      root: locator.resolve(.myMoviesProvider).myMoviesViewController(),
      title: "My Movies",
      systemImage: "film.stack",
      tag: 1
    )

    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [discover, myMovies]
    tabBarController.selectedIndex = 0
    window.rootViewController = tabBarController
  }

  /// Builds a fresh locator with every module registered and verified.
  /// Registration is lazy, so the order below does not matter.
  static func setupLocator(configuration: APIConfiguration) -> Locator {
    let locator = Locator()

    APIClientModule.registerServices(in: locator, configuration: configuration)
    AnalyticsClientModule.registerServices(in: locator)
    MovieStoreModule.registerServices(in: locator)
    MovieDetailModule.registerServices(in: locator)
    MovieListModule.registerServices(in: locator)
    MyMoviesModule.registerServices(in: locator)

    locator.verify(allOf:
      APIClientModule.requiredKinds
        + AnalyticsClientModule.requiredKinds
        + MovieDetailModule.requiredKinds
        + MovieListModule.requiredKinds
        + MyMoviesModule.requiredKinds
        + MovieStoreModule.requiredKinds
    )
    return locator
  }

  private static func makeTab(root: UIViewController, title: String, systemImage: String, tag: Int) -> UINavigationController {
    let navigationController = UINavigationController(rootViewController: root)
    navigationController.navigationBar.prefersLargeTitles = true
    navigationController.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: systemImage), tag: tag)
    return navigationController
  }
}
