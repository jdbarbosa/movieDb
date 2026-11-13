import UIKit
import AnalyticsClient
import APIClient
import Models
import MovieStore

protocol MovieDetailFactory {
  @MainActor
  func makeMovieDetailViewController(
    movie: Movie,
    apiClient: any APIClient,
    store: any MovieStore,
    analytics: any AnalyticsClient
  ) -> UIViewController
}

/// Assembles the screen: view controller, repository and view model.
final class MovieDetailFactoryImpl: MovieDetailFactory {

  @MainActor
  func makeMovieDetailViewController(
    movie: Movie,
    apiClient: any APIClient,
    store: any MovieStore,
    analytics: any AnalyticsClient
  ) -> UIViewController {
    let viewController = MovieDetailViewController()
    let repository = MovieDetailRepositoryImpl(apiClient: apiClient, store: store)
    let viewModel = MovieDetailViewModel(movie: movie, repository: repository, analytics: analytics)
    viewController.bind(viewModel: viewModel)
    return viewController
  }
}
