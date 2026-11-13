#if DEBUG
import SwiftUI
import AnalyticsClient
import Models

private final class PreviewRepository: MovieListRepository {
  func popularMovies(page: Int) async throws -> MovieListResponse {
    MovieListResponse(
      page: page,
      results: (1...10).map { Movie(id: $0 + page * 100, title: "Preview Movie \($0)", releaseDate: "2024-01-01", voteAverage: 7.3) },
      totalPages: 3,
      totalResults: 30
    )
  }

  func searchMovies(query: String, page: Int) async throws -> MovieListResponse {
    MovieListResponse(page: 1, results: [], totalPages: 1, totalResults: 0)
  }
}

private final class PreviewRouter: MovieListRouter {
  func routeToMovieDetails(movie: Movie) {}
}

private struct PreviewAnalytics: AnalyticsClient {
  func track(_ event: AnalyticsEvent) {}
}

#Preview("Popular") {
  let viewModel = MovieListViewModel(router: PreviewRouter(), repository: PreviewRepository(), analytics: PreviewAnalytics())
  viewModel.onAppear()
  return NavigationStack { MovieListView(viewModel: viewModel).navigationTitle("Movies") }
}
#endif
