import UIKit
import Locator
import MovieDetail
import MovieStore

/// The module's public entry point: builds the My Movies screen.
public protocol MyMoviesProvider {
  @MainActor
  func myMoviesViewController() -> UIViewController
}

/// Resolves the module's dependencies from the locator at call time and
/// hands them to the factory. The only type in this module that touches the locator.
@MainActor
final class MyMoviesProviderImpl: MyMoviesProvider {

  // Unowned: the locator owns this provider, so it always outlives it. A strong
  // reference would form a Locator -> Provider -> Locator cycle.
  private unowned let locator: any DependencyLocator
  private let factory: any MyMoviesFactory

  init(locator: any DependencyLocator, factory: any MyMoviesFactory = MyMoviesFactoryImpl()) {
    self.locator = locator
    self.factory = factory
  }

  func myMoviesViewController() -> UIViewController {
    factory.makeMyMoviesViewController(
      store: locator.resolve(.movieStore),
      analytics: locator.resolve(.analyticsClient),
      movieDetailProvider: locator.resolve(.movieDetailProvider)
    )
  }
}
