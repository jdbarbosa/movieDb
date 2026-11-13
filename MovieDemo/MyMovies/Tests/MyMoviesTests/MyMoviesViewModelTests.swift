import Testing
import AnalyticsClient
import AnalyticsClientTesting
import MovieStore
import MovieStoreTesting
@testable import MyMovies

@Suite("MyMoviesViewModel")
@MainActor
struct MyMoviesViewModelTests {

  @MainActor
  private struct Harness {
    let spy = SpyAnalyticsClient()
    let router = SpyMyMoviesRouter()
    let viewModel: MyMoviesViewModel

    init() {
      viewModel = MyMoviesViewModel(
        router: router,
        repository: MyMoviesRepositoryImpl(store: LocalMovieStore.inMemory()),
        analytics: spy
      )
    }
  }

  @Test func sectionsAreAllCasesInOrder() {
    let h = Harness()
    #expect(h.viewModel.sections == MovieCollection.allCases)
  }

  @Test func onAppearTracksViewedOnce() {
    let h = Harness()
    h.viewModel.onAppear()
    h.viewModel.onAppear()
    #expect(h.spy.events(named: "my_movies_viewed") == [AnalyticsEvent(name: "my_movies_viewed")])
  }

  @Test(arguments: MovieCollection.allCases)
  func sectionTappedTracksAndRoutes(section: MovieCollection) {
    let h = Harness()
    h.viewModel.sectionTapped(section)
    #expect(h.spy.events(named: "my_movies_section_tapped") == [
      AnalyticsEvent(name: "my_movies_section_tapped", parameters: ["section": section.rawValue])
    ])
    #expect(h.router.routed == [section])
  }
}
