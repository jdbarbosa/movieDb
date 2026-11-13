import Testing
import UIKit
import Locator
import Models
import MovieStore
import MovieStoreTesting
import APIClientTesting
import AnalyticsClientTesting
@testable import MovieDetail

@Suite("MovieDetailModule")
@MainActor
struct MovieDetailModuleTests {

  @Test func moduleRegistersProviderAndProviderBuildsViewController() {
    let locator = Locator()
    locator.register(.apiClient, MockAPIClient())
    locator.register(.analyticsClient, SpyAnalyticsClient())
    locator.register(.movieStore, LocalMovieStore.inMemory())

    MovieDetailModule.registerServices(in: locator)

    #expect(MovieDetailModule.requiredKinds.contains(.movieStore))
    #expect(locator.missing(from: MovieDetailModule.requiredKinds).isEmpty)

    let viewController = locator.resolve(.movieDetailProvider).movieDetailViewController(movie: Movie(id: 1, title: "Title"))
    viewController.loadViewIfNeeded()
    #expect(viewController is MovieDetailViewController)
    #expect(viewController.title == nil)
    let items = viewController.navigationItem.rightBarButtonItems ?? []
    #expect(items.count == 3)
    #expect(items.map(\.accessibilityLabel) == ["Watchlist", "Seen", "Favourites"])
    #expect(items.allSatisfy { $0.image != nil })   // outline vs filled is covered by the view model's isIn tests
  }
}
