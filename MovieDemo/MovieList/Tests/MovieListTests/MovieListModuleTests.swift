import Testing
import UIKit
import Locator
import APIClientTesting
import AnalyticsClientTesting
import MovieDetail
@testable import MovieList

@Suite("MovieListModule")
@MainActor
struct MovieListModuleTests {

  @Test func moduleRegistersProviderAndBuildsViewController() {
    let locator = Locator()
    locator.register(.apiClient, MockAPIClient())
    locator.register(.analyticsClient, SpyAnalyticsClient())
    locator.register(.movieDetailProvider, StubMovieDetailProvider())

    MovieListModule.registerServices(in: locator)

    #expect(locator.missing(from: MovieListModule.requiredKinds).isEmpty)
    #expect(locator.isRegistered(.movieListProvider))

    let viewController = locator.resolve(.movieListProvider).movieListViewController()
    viewController.loadViewIfNeeded()
    #expect(viewController is MovieListViewController)
    #expect(viewController.title == "Discover")
    #expect(viewController.navigationItem.searchController != nil)
  }
}
