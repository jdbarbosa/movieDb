import SwiftUI
import UIKit
import Protocols

@MainActor
final class MovieListViewController: UIViewController, ViewModelBindable, UISearchResultsUpdating {

  typealias ViewModelType = MovieListViewModel

  private var viewModel: MovieListViewModel?

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func bind(viewModel: MovieListViewModel) {
    self.viewModel = viewModel

    let hostingController = UIHostingController(rootView: MovieListView(viewModel: viewModel))
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
    title = "Discover"
    view.backgroundColor = .systemBackground
    navigationItem.largeTitleDisplayMode = .always

    let searchController = UISearchController(searchResultsController: nil)
    searchController.searchResultsUpdater = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search movies"
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    definesPresentationContext = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewModel?.onAppear()
  }

  func updateSearchResults(for searchController: UISearchController) {
    viewModel?.queryChanged(searchController.searchBar.text ?? "")
  }
}
