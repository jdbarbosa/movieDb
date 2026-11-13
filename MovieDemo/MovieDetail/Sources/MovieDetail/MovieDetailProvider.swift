import UIKit
import Locator
import Models
import MovieStore

/// The module's public entry point: builds the detail screen for a movie.
public protocol MovieDetailProvider {
  @MainActor
  func movieDetailViewController(movie: Movie) -> UIViewController
}

/// Resolves the module's dependencies from the locator at call time and
/// hands them to the factory. The only type in this module that touches the locator.
@MainActor
final class MovieDetailProviderImpl: MovieDetailProvider {

  private let locator: any DependencyLocator
  private let factory: any MovieDetailFactory

  init(locator: any DependencyLocator, factory: any MovieDetailFactory = MovieDetailFactoryImpl()) {
    self.locator = locator
    self.factory = factory
  }

  func movieDetailViewController(movie: Movie) -> UIViewController {
    factory.makeMovieDetailViewController(
      movie: movie,
      apiClient: locator.resolve(.apiClient),
      store: locator.resolve(.movieStore),
      analytics: locator.resolve(.analyticsClient)
    )
  }
}
