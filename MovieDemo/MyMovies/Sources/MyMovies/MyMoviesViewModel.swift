import Foundation
import Observation
import AnalyticsClient
import MovieStore
import Protocols

@MainActor
@Observable
final class MyMoviesViewModel: ViewModel {

  typealias ViewControllerType = MyMoviesViewController

  let sections = MovieCollection.allCases

  @ObservationIgnored private let router: any MyMoviesRouter
  // Held but not read: the hub only routes. The collection screens read the repository.
  @ObservationIgnored private let repository: any MyMoviesRepository
  @ObservationIgnored private let analytics: any AnalyticsClient

  @ObservationIgnored private var hasAppeared = false

  init(
    router: any MyMoviesRouter,
    repository: any MyMoviesRepository,
    analytics: any AnalyticsClient
  ) {
    self.router = router
    self.repository = repository
    self.analytics = analytics
  }

  // MARK: - Intents

  func onAppear() {
    guard !hasAppeared else { return }
    hasAppeared = true
    analytics.track(AnalyticsEvent(name: "my_movies_viewed"))
  }

  func sectionTapped(_ collection: MovieCollection) {
    analytics.track(AnalyticsEvent(name: "my_movies_section_tapped", parameters: ["section": collection.rawValue]))
    router.routeTo(collection: collection)
  }
}
