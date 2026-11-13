import Foundation
import Observation
import AnalyticsClient
import Models
import Protocols

@MainActor
@Observable
final class MovieListViewModel: ViewModel {

  typealias ViewControllerType = MovieListViewController

  enum Mode: Equatable {
    case popular
    case search(String)

    var analyticsName: String {
      switch self {
      case .popular: return "popular"
      case .search: return "search"
      }
    }
  }

  private(set) var movies: [Movie] = []
  private(set) var mode: Mode = .popular
  private(set) var isLoadingFirstPage = false
  private(set) var isLoadingNextPage = false
  private(set) var errorMessage: String?
  private(set) var canLoadMore = false

  private(set) var debounceTask: Task<Void, Never>?
  /// Assigning a new task (or nil) cancels the one it replaces, so a task is
  /// cancelled exactly when it is superseded and `Task.isCancelled` means stale.
  private(set) var currentTask: Task<Void, Never>? {
    willSet { currentTask?.cancel() }
  }

  @ObservationIgnored private let router: any MovieListRouter
  @ObservationIgnored private let repository: any MovieListRepository
  @ObservationIgnored private let analytics: any AnalyticsClient
  @ObservationIgnored private let debounce: Duration

  @ObservationIgnored private var page = 0
  @ObservationIgnored private var totalPages = 0
  @ObservationIgnored private var hasAppeared = false
  @ObservationIgnored private var hasLoadedOnce = false

  private static let nextPageThreshold = 5

  init(
    router: any MovieListRouter,
    repository: any MovieListRepository,
    analytics: any AnalyticsClient,
    debounce: Duration = .milliseconds(300)
  ) {
    self.router = router
    self.repository = repository
    self.analytics = analytics
    self.debounce = debounce
  }

  // MARK: - Intents

  /// Loads the first page of popular movies on the first appearance only, so
  /// returning from a detail screen keeps the current list and search.
  func onAppear() {
    if !hasAppeared {
      hasAppeared = true
      analytics.track(AnalyticsEvent(name: "movie_list_viewed"))
    }
    guard !hasLoadedOnce, currentTask == nil, debounceTask == nil else { return }
    loadFirstPage()
  }

  /// Called on every keystroke. Debounces, then reloads page 1 in the new mode.
  func queryChanged(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let newMode: Mode = trimmed.isEmpty ? .popular : .search(trimmed)
    guard newMode != mode || !hasLoadedOnce else { return }

    mode = newMode
    debounceTask?.cancel()
    // Cancel whatever is in flight now, not when the debounce fires: a task
    // that completes during the window must not touch the new mode's state.
    currentTask = nil
    isLoadingNextPage = false
    errorMessage = nil
    isLoadingFirstPage = movies.isEmpty

    debounceTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await Task.sleep(for: debounce)
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      debounceTask = nil
      loadFirstPage()
      await currentTask?.value
    }
  }

  func loadNextPageIfNeeded(currentItem: Movie) {
    guard canLoadMore, currentTask == nil, debounceTask == nil else { return }
    guard let index = movies.firstIndex(where: { $0.id == currentItem.id }) else { return }
    guard index >= movies.count - Self.nextPageThreshold else { return }
    loadNextPage()
  }

  func retry() {
    guard currentTask == nil, debounceTask == nil else { return }
    errorMessage = nil
    if movies.isEmpty {
      loadFirstPage()
    } else {
      loadNextPage()
    }
  }

  func movieWasTapped(_ movie: Movie) {
    analytics.track(AnalyticsEvent(name: "movie_selected", parameters: ["movie_id": "\(movie.id)"]))
    router.routeToMovieDetails(movie: movie)
  }

  // MARK: - Loading

  private func loadFirstPage() {
    let mode = mode
    movies = []
    page = 0
    totalPages = 0
    canLoadMore = false
    errorMessage = nil
    isLoadingFirstPage = true
    isLoadingNextPage = false

    if case .search(let query) = mode {
      analytics.track(AnalyticsEvent(name: "movie_search_performed", parameters: ["query": query]))
    }

    currentTask = Task { [weak self] in
      guard let self else { return }
      defer { if !Task.isCancelled { isLoadingFirstPage = false; currentTask = nil } }
      do {
        let response = try await fetch(mode: mode, page: 1)
        guard !Task.isCancelled else { return }
        apply(response, mode: mode, replacing: true)
      } catch {
        guard !Task.isCancelled else { return }
        handle(error)
      }
    }
  }

  private func loadNextPage() {
    guard canLoadMore else { return }
    let mode = mode
    let nextPage = page + 1
    isLoadingNextPage = true
    errorMessage = nil

    currentTask = Task { [weak self] in
      guard let self else { return }
      defer { if !Task.isCancelled { isLoadingNextPage = false; currentTask = nil } }
      do {
        let response = try await fetch(mode: mode, page: nextPage)
        guard !Task.isCancelled else { return }
        apply(response, mode: mode, replacing: false)
      } catch {
        guard !Task.isCancelled else { return }
        handle(error)
      }
    }
  }

  private func fetch(mode: Mode, page: Int) async throws -> MovieListResponse {
    switch mode {
    case .popular:
      return try await repository.popularMovies(page: page)
    case .search(let query):
      return try await repository.searchMovies(query: query, page: page)
    }
  }

  private func apply(_ response: MovieListResponse, mode: Mode, replacing: Bool) {
    var seen = Set(replacing ? [] : movies.map(\.id))
    let fresh = response.results.filter { seen.insert($0.id).inserted }
    movies = replacing ? fresh : movies + fresh
    page = response.page
    totalPages = response.totalPages
    canLoadMore = response.page < response.totalPages
    hasLoadedOnce = true
    analytics.track(AnalyticsEvent(
      name: "movie_list_page_loaded",
      parameters: ["page": "\(response.page)", "mode": mode.analyticsName]
    ))
  }

  private func handle(_ error: Error) {
    if error is CancellationError { return }
    let message = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
    errorMessage = message
    analytics.track(AnalyticsEvent(name: "error_shown", parameters: ["screen": "movie_list", "message": message]))
  }
}
