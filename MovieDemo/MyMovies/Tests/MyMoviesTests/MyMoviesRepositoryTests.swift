import Testing
import Models
import MovieStore
import MovieStoreTesting
@testable import MyMovies

@Suite("MyMoviesRepository")
struct MyMoviesRepositoryTests {

  @Test func forwardsToTheStore() async throws {
    let store = LocalMovieStore.inMemory()
    let repository = MyMoviesRepositoryImpl(store: store)
    try await store.add(Movie(id: 1, title: "One"), to: .watchlist)

    #expect(try await repository.movies(in: .watchlist).map(\.id) == [1])
    try await repository.remove(movieID: 1, from: .watchlist)
    #expect(try await repository.movies(in: .watchlist).isEmpty)
  }
}
