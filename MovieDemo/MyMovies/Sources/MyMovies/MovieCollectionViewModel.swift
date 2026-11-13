import Foundation
import Observation
import AnalyticsClient
import Models
import MovieStore
import Protocols

/// One collection's list. The list is never edited locally: every mutation goes
/// to the store, and the store's change stream triggers a reload.
@MainActor
@Observable
final class MovieCollectionViewModel: ViewModel {

  typealias ViewControllerType = MovieCollectionViewController

  let collection: MovieCollection

  private(set) var movies: [StoredMovie] = []
  private(set) var isLoading = false
  private(set) var errorMessage: String?
  private(set) var loadTask: Task<Void, Never>?
  private(set) var removeTask: Task<Void, Never>?

  /// Not observed by anyone, so it stays a plain stored property, which is also
  /// what lets the nonisolated `deinit` reach it.
  @ObservationIgnored private(set) var observationTask: Task<Void, Never>?

  @ObservationIgnored private let repository: any MyMoviesRepository
  @ObservationIgnored private let router: any MyMoviesRouter
  @ObservationIgnored private let analytics: any AnalyticsClient
  @ObservationIgnored private var hasAppeared = false

  init(
    collection: MovieCollection,
    repository: any MyMoviesRepository,
    router: any MyMoviesRouter,
    analytics: any AnalyticsClient
  ) {
    self.collection = collection
    self.repository = repository
    self.router = router
    self.analytics = analytics
  }

  deinit {
    // Ends the `for await` in observeChanges; the stream's onTermination then
    // tells the store to drop this subscriber.
    observationTask?.cancel()
  }

  var emptyMessage: String {
    switch collection {
    case .watchlist: return "Nothing in your watchlist yet"
    case .seen: return "Nothing marked as seen yet"
    case .favourites: return "No favourites yet"
    }
  }

  // MARK: - Intents

  func onAppear() {
    if !hasAppeared {
      hasAppeared = true
      analytics.track(AnalyticsEvent(name: "movie_collection_viewed", parameters: ["collection": collection.rawValue]))
      observeChanges()
    }
    if loadTask == nil {
      reload()
    }
  }

  func reload() {
    isLoading = true
    errorMessage = nil
    loadTask = Task { [weak self] in
      guard let self else { return }
      defer {
        isLoading = false
        loadTask = nil
      }
      do {
        movies = try await repository.movies(in: collection)
      } catch {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
      }
    }
  }

  /// Asks the store to drop the movie. The row disappears when the store's
  /// change comes back through `observeChanges`, not here. The store call runs
  /// even if this screen goes away mid-write; only the error report needs `self`.
  func remove(_ movie: Movie) {
    analytics.track(AnalyticsEvent(
      name: "movie_collection_removed",
      parameters: ["movie_id": "\(movie.id)", "collection": collection.rawValue]
    ))
    let collection = collection
    removeTask = Task { [weak self, repository] in
      do {
        try await repository.remove(movieID: movie.id, from: collection)
      } catch {
        guard let self else { return }
        errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        analytics.track(AnalyticsEvent(name: "error_shown", parameters: ["screen": "movie_collection", "message": errorMessage ?? ""]))
      }
    }
  }

  func movieWasTapped(_ movie: Movie) {
    analytics.track(AnalyticsEvent(name: "movie_selected", parameters: ["movie_id": "\(movie.id)"]))
    router.routeToMovieDetails(movie: movie)
  }

  // MARK: - Observation

  /// Same shape as the detail screen: weak `self`, re-acquired per change, so the
  /// task holds nothing between changes and `deinit` can cancel it.
  private func observeChanges() {
    let collection = collection
    observationTask = Task { [weak self] in
      guard let stream = await self?.repository.changes() else { return }
      for await change in stream where change.collection == collection {
        guard let self else { return }
        reload()
      }
    }
  }
}
