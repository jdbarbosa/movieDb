import Testing
import UIKit
import Locator
import Models
import MovieDetail
import MovieStore
import MovieStoreTesting
import AnalyticsClientTesting
@testable import MyMovies

@Suite("MyMoviesModule")
@MainActor
struct MyMoviesModuleTests {

  @Test func moduleRegistersProviderAndBuildsViewController() {
    let locator = Locator()
    locator.register(.analyticsClient, SpyAnalyticsClient())
    locator.register(.movieStore, LocalMovieStore.inMemory())
    locator.register(.movieDetailProvider, StubMovieDetailProvider())

    MyMoviesModule.registerServices(in: locator)

    #expect(MyMoviesModule.requiredKinds == [.analyticsClient, .movieStore, .movieDetailProvider])
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

  @Test func routerPushesCollectionAndDetail() {
    let navigationController = UINavigationController(rootViewController: UIViewController())
    let host = navigationController.viewControllers[0]
    let router = MyMoviesRouterImpl(
      viewController: host,
      movieDetailProvider: StubMovieDetailProvider(),
      makeCollectionScreen: { collection in
        let vc = UIViewController(); vc.title = collection.title; return vc
      }
    )

    router.routeTo(collection: .seen)
    #expect(navigationController.viewControllers.last?.title == "Seen")

    router.routeToMovieDetails(movie: Movie(id: 1, title: "Detail"))
    #expect(navigationController.viewControllers.last?.title == "Detail")
  }
}
