import SwiftUI
import UIKit
import MovieStore
import MovieUI
import Protocols

@MainActor
final class MovieDetailViewController: UIViewController, ViewModelBindable {

  typealias ViewModelType = MovieDetailViewModel

  private var viewModel: MovieDetailViewModel?
  private var collectionItems: [UIBarButtonItem] = []

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func bind(viewModel: MovieDetailViewModel) {
    self.viewModel = viewModel
		self.viewModel?.delegate = self

    let hostingController = UIHostingController(rootView: MovieDetailView(viewModel: viewModel))
    addChild(hostingController)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    hostingController.didMove(toParent: self)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    navigationItem.largeTitleDisplayMode = .never

    // See-through at the top so the hero image runs under the bar; the standard
    // appearance stays default, so the bar turns opaque once the user scrolls.
    let scrollEdge = UINavigationBarAppearance()
    scrollEdge.configureWithTransparentBackground()
    navigationItem.scrollEdgeAppearance = scrollEdge

    collectionItems = MovieCollection.allCases.enumerated().map { index, collection in
      let item = UIBarButtonItem(
        image: UIImage(systemName: collection.systemImage),
        style: .plain,
        target: self,
        action: #selector(collectionTapped(_:))
      )
      item.tag = index
      item.accessibilityLabel = collection.title
      return item
    }
    navigationItem.rightBarButtonItems = collectionItems
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewModel?.onAppear()
  }

  // MARK: - Collections

  @objc private func collectionTapped(_ sender: UIBarButtonItem) {
    viewModel?.toggle(MovieCollection.allCases[sender.tag])
  }

  private func renderCollections() {
    guard let viewModel else { return }
    for (item, collection) in zip(collectionItems, MovieCollection.allCases) {
      let selected = viewModel.isIn(collection)
      item.image = UIImage(systemName: selected ? collection.selectedSystemImage : collection.systemImage)
      item.accessibilityValue = selected ? "On" : "Off"
    }
  }
}

extension MovieDetailViewController: MovieDetailViewModelDelegate {
	func viewModel(_ viewModel: MovieDetailViewModel, didUpdate collections: Set<MovieCollection>) {
		self.renderCollections()
	}
}
