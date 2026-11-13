import Foundation
import Testing
import Models
import APIClient
import APIClientTesting
import AnalyticsClientTesting
import MovieStore
import MovieStoreTesting
@testable import MovieDetail

@Suite("MovieDetailViewModel")
@MainActor
struct MovieDetailViewModelTests {

  private let seed = Movie(id: 7, title: "Seed", posterPath: "/p.jpg")
  private let full = Movie(id: 7, title: "Seed", overview: "o", posterPath: "/p.jpg", runtime: 120, tagline: "T", genres: [Genre(id: 1, name: "Drama")])

  private func makeViewModel(mock: MockAPIClient, spy: SpyAnalyticsClient, store: any MovieStore = LocalMovieStore.inMemory()) -> MovieDetailViewModel {
    MovieDetailViewModel(movie: seed, repository: MovieDetailRepositoryImpl(apiClient: mock, store: store), analytics: spy)
  }

  @Test func onAppearLoadsDetailAndTracksViewed() async {
    let mock = MockAPIClient()
    let spy = SpyAnalyticsClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: spy)

    viewModel.onAppear()
    await viewModel.currentTask?.value

    #expect(viewModel.state == .loaded)
    #expect(viewModel.movie.runtime == 120)
    #expect(spy.events(named: "movie_detail_viewed") == [.init(name: "movie_detail_viewed", parameters: ["movie_id": "7"])])
  }

  @Test func onAppearIsIdempotent() async {
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient())

    viewModel.onAppear()
    await viewModel.currentTask?.value
    viewModel.onAppear()
    await viewModel.currentTask?.value

    #expect(mock.receivedRequests.count == 1)
  }

  @Test func failureSetsFailedStateAndTracksError() async {
    let mock = MockAPIClient()
    let spy = SpyAnalyticsClient()
    mock.stub(path: "/movie/7", result: Result<Movie, APIError>.failure(.network(500)))
    let viewModel = makeViewModel(mock: mock, spy: spy)

    viewModel.onAppear()
    await viewModel.currentTask?.value

    #expect(viewModel.state == .failed("Network error (status 500)."))
    let shown = spy.events(named: "error_shown")
    #expect(shown.count == 1)
    #expect(shown.first?.parameters["screen"] == "movie_detail")
    #expect(shown.first?.parameters["message"] == "Network error (status 500).")
  }

  @Test func retryReloadsAfterFailure() async {
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: Result<Movie, APIError>.failure(.network(500)))
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient())

    viewModel.onAppear()
    await viewModel.currentTask?.value
    #expect(viewModel.state == .failed("Network error (status 500)."))

    viewModel.retry()
    await viewModel.currentTask?.value

    #expect(viewModel.state == .loaded)
    #expect(viewModel.movie.tagline == "T")
  }

  @Test func toggleAddsThenRemovesAndTracks() async throws {
    let store = LocalMovieStore.inMemory()
    let spy = SpyAnalyticsClient()
    let viewModel = makeViewModel(mock: MockAPIClient(), spy: spy, store: store)

    viewModel.toggle(.watchlist)
    #expect(viewModel.isIn(.watchlist))             // optimistic
    await viewModel.collectionsTask?.value
    #expect(try await store.collections(containing: 7) == [.watchlist])

    viewModel.toggle(.watchlist)
    #expect(!viewModel.isIn(.watchlist))
    await viewModel.collectionsTask?.value
    #expect(try await store.collections(containing: 7).isEmpty)

    let events = spy.events(named: "movie_collection_toggled")
    #expect(events.map { $0.parameters["action"] } == ["added", "removed"])
    #expect(events.allSatisfy { $0.parameters["movie_id"] == "7" && $0.parameters["collection"] == "watchlist" })
  }

  @Test func onAppearLoadsExistingCollections() async throws {
    let store = LocalMovieStore.inMemory()
    try await store.add(seed, to: .favourites)
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)

    viewModel.onAppear()
    await viewModel.collectionsTask?.value

    #expect(viewModel.collections == [.favourites])
  }

  @Test func externalChangeForThisMovieUpdatesCollections() async throws {
    let store = LocalMovieStore.inMemory()
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)
    viewModel.onAppear()
    await viewModel.collectionsTask?.value
    await Task.yield()   // let the observation task reach its first await

    try await store.add(seed, to: .seen)
    for _ in 0..<50 where !viewModel.isIn(.seen) { await Task.yield() }

    #expect(viewModel.isIn(.seen))
  }

  @Test func changeForOtherMovieIsIgnored() async throws {
    let store = LocalMovieStore.inMemory()
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    let viewModel = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)
    viewModel.onAppear()
    await viewModel.collectionsTask?.value
    await Task.yield()

    try await store.add(Movie(id: 99, title: "Other"), to: .seen)
    try await store.add(seed, to: .watchlist)   // sentinel so we know the stream was processed
    for _ in 0..<50 where !viewModel.isIn(.watchlist) { await Task.yield() }

    #expect(viewModel.collections == [.watchlist])
  }

  @Test func failedToggleRevertsAndTracksError() async throws {
    struct Failing: MovieStorePersistence {
      func load() async throws -> MovieStoreSnapshot { .empty }
      func save(_ snapshot: MovieStoreSnapshot) async throws { throw CocoaError(.fileWriteNoPermission) }
    }
    let spy = SpyAnalyticsClient()
    let viewModel = makeViewModel(mock: MockAPIClient(), spy: spy, store: LocalMovieStore(persistence: Failing()))

    viewModel.toggle(.favourites)
    await viewModel.collectionsTask?.value

    #expect(!viewModel.isIn(.favourites))
    #expect(spy.events(named: "error_shown").first?.parameters["screen"] == "movie_detail")
  }

  @Test func deallocatedViewModelEndsSubscription() async throws {
    let store = LocalMovieStore.inMemory()
    let mock = MockAPIClient()
    mock.stub(path: "/movie/7", result: .success(full))
    var viewModel: MovieDetailViewModel? = makeViewModel(mock: mock, spy: SpyAnalyticsClient(), store: store)
    viewModel?.onAppear()
    await viewModel?.collectionsTask?.value
    await viewModel?.currentTask?.value   // the detail load holds self strongly until it finishes
    var attempts = 0
    while await store.subscriberCount == 0, attempts < 50 { attempts += 1; await Task.yield() }
    #expect(await store.subscriberCount == 1)

    viewModel = nil
    attempts = 0
    while await store.subscriberCount != 0, attempts < 50 { attempts += 1; await Task.yield() }
    #expect(await store.subscriberCount == 0)
  }
}
