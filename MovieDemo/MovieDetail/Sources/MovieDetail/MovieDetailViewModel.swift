import Foundation
import Observation
import AnalyticsClient
import Models
import MovieStore
import Protocols

@MainActor
protocol MovieDetailViewModelDelegate: AnyObject {
	func viewModel(_ viewModel: MovieDetailViewModel, didUpdate collections: Set<MovieCollection>)
}

@MainActor
@Observable
final class MovieDetailViewModel: ViewModel {

  typealias ViewControllerType = MovieDetailViewController

  enum State: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  private(set) var movie: Movie
  private(set) var state: State = .idle
	private(set) var collections: Set<MovieCollection> = [] {
		didSet {
			self.delegate?.viewModel(
				self,
				didUpdate: collections
			)
		}
	}

  private(set) var currentTask: Task<Void, Never>?
  private(set) var collectionsTask: Task<Void, Never>?

  /// Not observed by anyone, so it stays a plain stored property. That is also what
  /// lets the nonisolated `deinit` reach it: an `@Observable`-tracked property's
  /// getter is main-actor isolated, a plain Sendable stored property is not.
  @ObservationIgnored private(set) var observationTask: Task<Void, Never>?

  @ObservationIgnored private let repository: any MovieDetailRepository
  @ObservationIgnored private let analytics: any AnalyticsClient
  @ObservationIgnored private var hasLoadedCollections = false
	
	weak var delegate: MovieDetailViewModelDelegate?

  init(movie: Movie, repository: any MovieDetailRepository, analytics: any AnalyticsClient) {
    self.movie = movie
    self.repository = repository
    self.analytics = analytics
  }

  deinit {
    // Ends the `for await` in observeChanges; the stream's onTermination then
    // tells the store to drop this subscriber.
    observationTask?.cancel()
  }

  // MARK: - Intents

  /// Loads the full detail once. Later appearances (e.g. after a pop) are no-ops.
  func onAppear() {
    if state == .idle {
      load()
    }
    if !hasLoadedCollections {
      hasLoadedCollections = true
      loadCollections()
      observeChanges()
    }
  }

  func retry() {
    guard case .failed = state else { return }
    load()
  }

  func isIn(_ collection: MovieCollection) -> Bool {
    collections.contains(collection)
  }

  /// Flips membership immediately and persists in the background. On failure
  /// the flip is undone, so the icon never shows a state the disk does not have.
  func toggle(_ collection: MovieCollection) {
    let adding = !isIn(collection)
    if adding {
      collections.insert(collection)
    } else {
      collections.remove(collection)
    }
    analytics.track(AnalyticsEvent(
      name: "movie_collection_toggled",
      parameters: ["movie_id": "\(movie.id)", "collection": collection.rawValue, "action": adding ? "added" : "removed"]
    ))

    let movie = movie
    collectionsTask = Task { [weak self] in
      guard let self else { return }
      do {
        if adding {
          try await repository.add(movie, to: collection)
        } else {
          try await repository.remove(movieID: movie.id, from: collection)
        }
      } catch {
        if adding {
          collections.remove(collection)
        } else {
          collections.insert(collection)
        }
        trackError(error)
      }
    }
  }

  // MARK: - Loading

  private func load() {
    state = .loading
    let id = movie.id
    currentTask = Task { [weak self] in
      guard let self else { return }
      do {
        let detail = try await repository.movieDetails(id: id)
        movie = detail
        state = .loaded
        analytics.track(AnalyticsEvent(name: "movie_detail_viewed", parameters: ["movie_id": "\(id)"]))
      } catch is CancellationError {
        state = .idle
      } catch {
        let message = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
        state = .failed(message)
        analytics.track(AnalyticsEvent(name: "error_shown", parameters: ["screen": "movie_detail", "message": message]))
      }
    }
  }

  private func loadCollections() {
    let id = movie.id
    collectionsTask = Task { [weak self] in
      guard let self else { return }
      do {
        collections = try await repository.collections(containing: id)
      } catch {
        trackError(error)
      }
    }
  }

  /// Keeps `collections` in step with changes made elsewhere, such as a swipe
  /// to remove on the My Movies tab. `self` is captured weakly and re-acquired
  /// per iteration, so between changes this task holds nothing: when the
  /// screen goes away the view model deallocates and `deinit` cancels the task.
  private func observeChanges() {
    let id = movie.id
    observationTask = Task { [weak self] in
      guard let stream = await self?.repository.changes() else { return }
      for await change in stream where change.movieID == id {
        guard let self else { return }
        switch change.kind {
        case .added: collections.insert(change.collection)
        case .removed: collections.remove(change.collection)
        }
      }
    }
  }

  private func trackError(_ error: Error) {
    let message = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
    analytics.track(AnalyticsEvent(name: "error_shown", parameters: ["screen": "movie_detail", "message": message]))
  }
}
