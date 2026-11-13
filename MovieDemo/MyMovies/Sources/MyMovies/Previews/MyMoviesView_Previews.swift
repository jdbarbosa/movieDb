#if DEBUG
import SwiftUI
import AnalyticsClient
import Models
import MovieStore

private final class PreviewRouter: MyMoviesRouter {
  func routeTo(collection: MovieCollection) {}
  func routeToMovieDetails(movie: Movie) {}
}

private struct PreviewAnalytics: AnalyticsClient {
  func track(_ event: AnalyticsEvent) {}
}

private struct PreviewPersistence: MovieStorePersistence {
  func load() async throws -> MovieStoreSnapshot { .empty }
  func save(_ snapshot: MovieStoreSnapshot) async throws {}
}

#Preview("My Movies") {
  let viewModel = MyMoviesViewModel(
    router: PreviewRouter(),
    repository: MyMoviesRepositoryImpl(store: LocalMovieStore(persistence: PreviewPersistence())),
    analytics: PreviewAnalytics()
  )
  NavigationStack {
    MyMoviesView(viewModel: viewModel)
      .navigationTitle("My Movies")
  }
}
#endif
