import APIClient
import Models

protocol MovieListRepository: Sendable {
  func popularMovies(page: Int) async throws -> MovieListResponse
  func searchMovies(query: String, page: Int) async throws -> MovieListResponse
}

final class MovieListRepositoryImpl: MovieListRepository {

  private let apiClient: any APIClient

  init(apiClient: any APIClient) {
    self.apiClient = apiClient
  }

  func popularMovies(page: Int) async throws -> MovieListResponse {
    try await apiClient.send(PopularMoviesRequest(page: page))
  }

  func searchMovies(query: String, page: Int) async throws -> MovieListResponse {
    try await apiClient.send(SearchMoviesRequest(page: page, query: query))
  }
}
