import UIKit
import Locator

/// The module's public entry point: builds the movie list screen.
public protocol MovieListProvider {
  @MainActor
  func movieListViewController() -> UIViewController
}

/// Resolves the module's dependencies from the locator at call time and
/// hands them to the factory. The only type in this module that touches the locator.
@MainActor
final class MovieListProviderImpl: MovieListProvider {

  private let locator: any DependencyLocator
  private let factory: any MovieListFactory

  init(locator: any DependencyLocator, factory: any MovieListFactory = MovieListFactoryImpl()) {
    self.locator = locator
    self.factory = factory
  }

  func movieListViewController() -> UIViewController {
    factory.makeMovieListViewController(
      apiClient: locator.resolve(.apiClient),
      analytics: locator.resolve(.analyticsClient),
      movieDetailProvider: locator.resolve(.movieDetailProvider)
    )
  }
}
