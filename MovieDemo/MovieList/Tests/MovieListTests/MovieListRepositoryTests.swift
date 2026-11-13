import Foundation
import Testing
import APIClientTesting
@testable import MovieList

@Suite("MovieListRepository")
struct MovieListRepositoryTests {

  @Test func popularRequestHitsPathWithPage() async throws {
    let mock = MockAPIClient()
    mock.stub(path: "/movie/popular", result: .success(Fixtures.page(2, ids: [1], totalPages: 5)))
    let repository = MovieListRepositoryImpl(apiClient: mock)

    let response = try await repository.popularMovies(page: 2)

    #expect(response.page == 2)
    #expect(mock.receivedRequests == [
      RecordedRequest(path: "/movie/popular", queryItems: [URLQueryItem(name: "page", value: "2")], method: .get)
    ])
  }

  @Test func searchRequestHitsPathWithQueryAndPage() async throws {
    let mock = MockAPIClient()
    mock.stub(path: "/search/movie", result: .success(Fixtures.page(1, ids: [1], totalPages: 1)))
    let repository = MovieListRepositoryImpl(apiClient: mock)

    _ = try await repository.searchMovies(query: "alien", page: 3)

    #expect(mock.receivedRequests == [
      RecordedRequest(
        path: "/search/movie",
        queryItems: [URLQueryItem(name: "query", value: "alien"), URLQueryItem(name: "page", value: "3")],
        method: .get
      )
    ])
  }
}
