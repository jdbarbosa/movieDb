import Foundation
import Testing
import Models
import AnalyticsClient
import AnalyticsClientTesting
import MovieStore
import MovieStoreTesting
@testable import MyMovies

@Suite("MovieCollectionViewModel")
@MainActor
struct MovieCollectionViewModelTests {

  @MainActor
  private struct Harness {
    let store = LocalMovieStore.inMemory()
    let spy = SpyAnalyticsClient()
    let router = SpyMyMoviesRouter()
    let viewModel: MovieCollectionViewModel

    init(collection: MovieCollection = .watchlist) {
      viewModel = MovieCollectionViewModel(
        collection: collection,
        repository: MyMoviesRepositoryImpl(store: store),
        router: router,
        analytics: spy
      )
    }

    func settle() async {
      await viewModel.loadTask?.value
    }
  }

  @Test func onAppearLoadsNewestFirstAndTracksOnce() async throws {
    let h = Harness()
    try await h.store.add(Movie(id: 1, title: "One"), to: .watchlist)
    try await h.store.add(Movie(id: 2, title: "Two"), to: .watchlist)

    h.viewModel.onAppear()
    await h.settle()
    h.viewModel.onAppear()
    await h.settle()

    #expect(h.viewModel.movies.map(\.id) == [2, 1])
    #expect(h.viewModel.isLoading == false)
    #expect(h.spy.events(named: "movie_collection_viewed") == [AnalyticsEvent(name: "movie_collection_viewed", parameters: ["collection": "watchlist"])])
  }

  @Test func removeTracksAndListRefreshesThroughTheStream() async throws {
    let h = Harness()
    let movie = Movie(id: 1, title: "One")
    try await h.store.add(movie, to: .watchlist)
    try await h.store.add(movie, to: .seen)
    h.viewModel.onAppear()
    await h.settle()
    await Task.yield()

    h.viewModel.remove(movie)
    for _ in 0..<50 where !h.viewModel.movies.isEmpty { await Task.yield(); await h.settle() }

    #expect(h.viewModel.movies.isEmpty)
    #expect(try await h.store.collections(containing: 1) == [.seen])
    #expect(h.spy.events(named: "movie_collection_removed").first?.parameters == ["movie_id": "1", "collection": "watchlist"])
  }

  @Test func externalAddShowsUp() async throws {
    let h = Harness(collection: .favourites)
    h.viewModel.onAppear()
    await h.settle()
    await Task.yield()

    try await h.store.add(Movie(id: 5, title: "Five"), to: .favourites)
    for _ in 0..<50 where h.viewModel.movies.isEmpty { await Task.yield(); await h.settle() }

    #expect(h.viewModel.movies.map(\.id) == [5])
  }

  @Test func tappingRoutesAndTracks() {
    let h = Harness()
    let movie = Movie(id: 3, title: "Three")
    h.viewModel.movieWasTapped(movie)
    #expect(h.router.detailMovies == [movie])
    #expect(h.spy.events(named: "movie_selected") == [AnalyticsEvent(name: "movie_selected", parameters: ["movie_id": "3"])])
  }

  @Test(arguments: zip(MovieCollection.allCases, ["Nothing in your watchlist yet", "Nothing marked as seen yet", "No favourites yet"]))
  func emptyMessagePerCollection(collection: MovieCollection, message: String) {
    #expect(Harness(collection: collection).viewModel.emptyMessage == message)
  }

  @Test func failedRemoveTracksErrorAndKeepsRow() async throws {
    final class FailingRemoves: MovieStorePersistence, Sendable {
      func load() async throws -> MovieStoreSnapshot {
        MovieStoreSnapshot(entries: [.watchlist: [StoredMovie(movie: Movie(id: 1, title: "One"), addedAt: Date())]])
      }
      func save(_ snapshot: MovieStoreSnapshot) async throws { throw CocoaError(.fileWriteNoPermission) }
    }
    let spy = SpyAnalyticsClient()
    let viewModel = MovieCollectionViewModel(
      collection: .watchlist,
      repository: MyMoviesRepositoryImpl(store: LocalMovieStore(persistence: FailingRemoves())),
      router: SpyMyMoviesRouter(),
      analytics: spy
    )
    viewModel.onAppear()
    await viewModel.loadTask?.value
    #expect(viewModel.movies.count == 1)

    viewModel.remove(Movie(id: 1, title: "One"))
    await viewModel.removeTask?.value

    #expect(viewModel.movies.count == 1)
    #expect(viewModel.errorMessage != nil)
    #expect(spy.events(named: "error_shown").first?.parameters["screen"] == "movie_collection")
  }
}
