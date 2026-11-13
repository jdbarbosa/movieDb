import UIKit
import AnalyticsClient
import APIClient
import MovieDetail

protocol MovieListFactory {
  @MainActor
  func makeMovieListViewController(
    apiClient: any APIClient,
    analytics: any AnalyticsClient,
    movieDetailProvider: any MovieDetailProvider
  ) -> UIViewController
}

/// Assembles the screen: view controller, repository, router and view model.
final class MovieListFactoryImpl: MovieListFactory {

  @MainActor
  func makeMovieListViewController(
    apiClient: any APIClient,
    analytics: any AnalyticsClient,
    movieDetailProvider: any MovieDetailProvider
  ) -> UIViewController {
    let viewController = MovieListViewController()
    let repository = MovieListRepositoryImpl(apiClient: apiClient)
    let router = MovieListRouterImpl(viewController: viewController, movieDetailProvider: movieDetailProvider)
    let viewModel = MovieListViewModel(router: router, repository: repository, analytics: analytics)
    viewController.bind(viewModel: viewModel)
    return viewController
  }
}
