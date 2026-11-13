import Foundation
import Testing
import Models
import APIClient
import APIClientTesting
import AnalyticsClientTesting
@testable import MovieList

@Suite("MovieListViewModel", .serialized)
@MainActor
struct MovieListViewModelTests {

  @MainActor
  private struct Harness {
    let mock = MockAPIClient()
    let spy = SpyAnalyticsClient()
    let router = SpyMovieListRouter()
    let viewModel: MovieListViewModel

    init(debounce: Duration = .milliseconds(10)) {
      viewModel = MovieListViewModel(
        router: router,
        repository: MovieListRepositoryImpl(apiClient: mock),
        analytics: spy,
        debounce: debounce
      )
    }

    /// Stubs `path` with a response that arrives after `delay` even if the request is cancelled.
    func stubUncancellable(path: String, response: MovieListResponse, delay: Duration) {
      mock.stub(path: path) { _ in
        try? await Task.sleep(for: delay)
        return response
      }
    }

    func settle() async {
      await viewModel.debounceTask?.value
      await viewModel.currentTask?.value
    }

    func requests(to path: String) -> [RecordedRequest] {
      mock.receivedRequests.filter { $0.path == path }
    }
  }

  @Test func onAppearLoadsPopularAndTracksViewed() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1, 2, 3], totalPages: 2)))

    h.viewModel.onAppear()
    await h.settle()

    #expect(h.viewModel.movies.map(\.id) == [1, 2, 3])
    #expect(h.viewModel.mode == .popular)
    #expect(h.viewModel.canLoadMore == true)
    #expect(h.viewModel.isLoadingFirstPage == false)
    #expect(h.spy.events(named: "movie_list_viewed").count == 1)
    #expect(h.spy.events(named: "movie_list_page_loaded").first?.parameters == ["page": "1", "mode": "popular"])
  }

  @Test func onAppearIsIdempotentAfterLoad() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1], totalPages: 1)))

    h.viewModel.onAppear()
    await h.settle()
    h.viewModel.onAppear()
    await h.settle()

    #expect(h.requests(to: "/movie/popular").count == 1)
    #expect(h.spy.events(named: "movie_list_viewed").count == 1)
  }

  @Test func burstOfKeystrokesSendsOneSearchRequest() async {
    let h = Harness()
    h.mock.stub(path: "/search/movie", result: .success(Fixtures.page(1, ids: [9], totalPages: 1)))

    h.viewModel.queryChanged("a")
    h.viewModel.queryChanged("al")
    h.viewModel.queryChanged("ali")
    await h.settle()

    let searches = h.requests(to: "/search/movie")
    #expect(searches.count == 1)
    #expect(searches.first?.queryItems.contains(URLQueryItem(name: "query", value: "ali")) == true)
    #expect(h.viewModel.movies.map(\.id) == [9])
    #expect(h.spy.events(named: "movie_search_performed") == [.init(name: "movie_search_performed", parameters: ["query": "ali"])])
  }

  @Test func clearingQueryReturnsToPopular() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1], totalPages: 1)))
    h.mock.stub(path: "/search/movie", result: .success(Fixtures.page(1, ids: [9], totalPages: 1)))

    h.viewModel.queryChanged("x")
    await h.settle()
    #expect(h.viewModel.mode == .search("x"))

    h.viewModel.queryChanged("")
    await h.settle()

    #expect(h.viewModel.mode == .popular)
    #expect(h.viewModel.movies.map(\.id) == [1])
  }

  @Test func whitespaceQueryIsPopularMode() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1], totalPages: 1)))

    h.viewModel.queryChanged("   ")
    await h.settle()

    #expect(h.viewModel.mode == .popular)
    #expect(h.requests(to: "/search/movie").isEmpty)
  }

  @Test func nextPageAppendsAndStopsAtTotalPages() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1, 2, 3], totalPages: 2)))
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(2, ids: [4, 5, 6], totalPages: 2)))

    h.viewModel.onAppear()
    await h.settle()
    h.viewModel.loadNextPageIfNeeded(currentItem: h.viewModel.movies.last!)
    await h.settle()

    #expect(h.viewModel.movies.map(\.id) == [1, 2, 3, 4, 5, 6])
    #expect(h.viewModel.canLoadMore == false)
    #expect(h.requests(to: "/movie/popular").last?.queryItems == [URLQueryItem(name: "page", value: "2")])

    h.viewModel.loadNextPageIfNeeded(currentItem: h.viewModel.movies.last!)
    await h.settle()
    #expect(h.requests(to: "/movie/popular").count == 2)
  }

  @Test func nextPageDeduplicatesById() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1, 2, 3], totalPages: 2)))
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(2, ids: [3, 4, 5], totalPages: 2)))

    h.viewModel.onAppear()
    await h.settle()
    h.viewModel.loadNextPageIfNeeded(currentItem: h.viewModel.movies.last!)
    await h.settle()

    #expect(h.viewModel.movies.map(\.id) == [1, 2, 3, 4, 5])
  }

  @Test func nextPageIsNotRequestedFarFromTheEnd() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: Array(1...20), totalPages: 2)))

    h.viewModel.onAppear()
    await h.settle()
    h.viewModel.loadNextPageIfNeeded(currentItem: h.viewModel.movies[2])
    await h.settle()

    #expect(h.requests(to: "/movie/popular").count == 1)
  }

  @Test func staleResponseIsDiscarded() async {
    let h = Harness(debounce: .milliseconds(300))
    h.stubUncancellable(path: "/movie/popular", response: Fixtures.page(1, ids: [1, 2], totalPages: 2), delay: .milliseconds(40))
    h.mock.stub(path: "/search/movie", result: .success(Fixtures.page(1, ids: [9], totalPages: 1)))

    h.viewModel.onAppear()
    h.viewModel.queryChanged("x")
    // The popular response lands inside the debounce window; it must not be applied.
    try? await Task.sleep(for: .milliseconds(150))
    #expect(h.viewModel.movies.isEmpty)
    #expect(h.viewModel.canLoadMore == false)
    #expect(h.viewModel.mode == .search("x"))

    await h.settle()
    #expect(h.viewModel.movies.map(\.id) == [9])
  }

  @Test func keystrokeDuringInFlightSearchKeepsLoadingState() async {
    let h = Harness()
    h.stubUncancellable(path: "/search/movie", response: Fixtures.page(1, ids: [9], totalPages: 1), delay: .milliseconds(100))

    h.viewModel.queryChanged("b")
    try? await Task.sleep(for: .milliseconds(30))   // debounce fired, "b" request in flight
    h.viewModel.queryChanged("ba")

    #expect(h.viewModel.isLoadingFirstPage == true)
    #expect(h.viewModel.movies.isEmpty)
    try? await Task.sleep(for: .milliseconds(5))
    #expect(h.viewModel.isLoadingFirstPage == true)   // the cancelled task's defer must not clear it

    await h.settle()
    try? await Task.sleep(for: .milliseconds(150))
    #expect(h.viewModel.isLoadingFirstPage == false)
    #expect(h.viewModel.movies.map(\.id) == [9])
  }

  @Test func keystrokeResetsNextPageSpinnerAndError() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1, 2, 3], totalPages: 2)))
    h.stubUncancellable(path: "/movie/popular", response: Fixtures.page(2, ids: [4], totalPages: 2), delay: .milliseconds(100))
    h.mock.stub(path: "/search/movie", result: .success(Fixtures.page(1, ids: [9], totalPages: 1)))

    h.viewModel.onAppear()
    await h.settle()
    h.viewModel.loadNextPageIfNeeded(currentItem: h.viewModel.movies.last!)
    #expect(h.viewModel.isLoadingNextPage == true)

    h.viewModel.queryChanged("x")
    #expect(h.viewModel.isLoadingNextPage == false)
    await h.settle()
    try? await Task.sleep(for: .milliseconds(150))
    #expect(h.viewModel.isLoadingNextPage == false)
    #expect(h.viewModel.movies.map(\.id) == [9])
  }

  @Test func keystrokeClearsPreviousErrorAndRetryIsIgnoredWhileDebouncing() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: Result<MovieListResponse, APIError>.failure(.network(500)))
    h.mock.stub(path: "/search/movie", result: .success(Fixtures.page(1, ids: [9], totalPages: 1)))

    h.viewModel.onAppear()
    await h.settle()
    #expect(h.viewModel.errorMessage != nil)

    h.viewModel.queryChanged("x")
    #expect(h.viewModel.errorMessage == nil)
    h.viewModel.retry()
    await h.settle()

    #expect(h.requests(to: "/search/movie").count == 1)
    #expect(h.viewModel.movies.map(\.id) == [9])
  }

  @Test func cancellationDoesNotSetError() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1], totalPages: 1)), delay: .milliseconds(200))
    h.mock.stub(path: "/search/movie", result: .success(Fixtures.page(1, ids: [9], totalPages: 1)))

    h.viewModel.onAppear()
    h.viewModel.queryChanged("x")
    await h.settle()
    try? await Task.sleep(for: .milliseconds(300))

    #expect(h.viewModel.errorMessage == nil)
    #expect(h.spy.events(named: "error_shown").isEmpty)
  }

  @Test func firstPageErrorSetsMessageAndTracks() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: Result<MovieListResponse, APIError>.failure(.network(500)))

    h.viewModel.onAppear()
    await h.settle()

    #expect(h.viewModel.errorMessage == "Network error (status 500).")
    #expect(h.viewModel.movies.isEmpty)
    let shown = h.spy.events(named: "error_shown")
    #expect(shown.count == 1)
    #expect(shown.first?.parameters["screen"] == "movie_list")
  }

  @Test func errorMessageIsHumanReadable() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: Result<MovieListResponse, APIError>.failure(.notAuthenticated))

    h.viewModel.onAppear()
    await h.settle()

    #expect(h.viewModel.errorMessage == "Invalid API key.")
  }

  @Test func retryClearsErrorAndReloads() async {
    let h = Harness()
    h.mock.stub(path: "/movie/popular", result: Result<MovieListResponse, APIError>.failure(.network(500)))
    h.mock.stub(path: "/movie/popular", result: .success(Fixtures.page(1, ids: [1], totalPages: 1)))

    h.viewModel.onAppear()
    await h.settle()
    #expect(h.viewModel.errorMessage != nil)

    h.viewModel.retry()
    await h.settle()

    #expect(h.viewModel.errorMessage == nil)
    #expect(h.viewModel.movies.map(\.id) == [1])
  }

  @Test func movieTappedRoutesAndTracks() {
    let h = Harness()
    let movie = Fixtures.movie(42)

    h.viewModel.movieWasTapped(movie)

    #expect(h.router.routed == [movie])
    #expect(h.spy.events(named: "movie_selected") == [.init(name: "movie_selected", parameters: ["movie_id": "42"])])
  }
}
