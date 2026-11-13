import UIKit
import AnalyticsClient
import MovieDetail
import MovieStore

protocol MyMoviesFactory {
  @MainActor
  func makeMyMoviesViewController(
    store: any MovieStore,
    analytics: any AnalyticsClient,
    movieDetailProvider: any MovieDetailProvider
  ) -> UIViewController

  @MainActor
  func makeMovieCollectionViewController(
    collection: MovieCollection,
    store: any MovieStore,
    analytics: any AnalyticsClient,
    movieDetailProvider: any MovieDetailProvider
  ) -> UIViewController
}

/// Assembles both of the module's screens. The hub's router asks this factory
/// for a collection screen, so screen construction stays in one place.
final class MyMoviesFactoryImpl: MyMoviesFactory {

  @MainActor
  func makeMyMoviesViewController(
    store: any MovieStore,
    analytics: any AnalyticsClient,
    movieDetailProvider: any MovieDetailProvider
  ) -> UIViewController {
    let viewController = MyMoviesViewController()
    let repository = MyMoviesRepositoryImpl(store: store)
    let router = makeRouter(
			for: viewController,
			store: store,
			analytics: analytics,
			movieDetailProvider: movieDetailProvider
		)
    let viewModel = MyMoviesViewModel(
			router: router,
			repository: repository,
			analytics: analytics
		)
    viewController.bind(viewModel: viewModel)
    return viewController
  }

  @MainActor
  func makeMovieCollectionViewController(
    collection: MovieCollection,
    store: any MovieStore,
    analytics: any AnalyticsClient,
    movieDetailProvider: any MovieDetailProvider
  ) -> UIViewController {
    let viewController = MovieCollectionViewController()
    let repository = MyMoviesRepositoryImpl(store: store)
    let router = makeRouter(
			for: viewController,
			store: store,
			analytics: analytics,
			movieDetailProvider: movieDetailProvider
		)
    let viewModel = MovieCollectionViewModel(
			collection: collection,
			repository: repository,
			router: router,
			analytics: analytics
		)
    viewController.bind(viewModel: viewModel)
    return viewController
  }

  @MainActor
  private func makeRouter(
    for viewController: UIViewController,
    store: any MovieStore,
    analytics: any AnalyticsClient,
    movieDetailProvider: any MovieDetailProvider
  ) -> MyMoviesRouterImpl {
    MyMoviesRouterImpl(viewController: viewController, movieDetailProvider: movieDetailProvider) { [self] collection in
      makeMovieCollectionViewController(collection: collection, store: store, analytics: analytics, movieDetailProvider: movieDetailProvider)
    }
  }
}
