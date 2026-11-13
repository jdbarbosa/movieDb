import SwiftUI
import UIKit
import Protocols

@MainActor
final class MyMoviesViewController: UIViewController, ViewModelBindable {

  typealias ViewModelType = MyMoviesViewModel

  private var viewModel: MyMoviesViewModel?

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func bind(viewModel: MyMoviesViewModel) {
    self.viewModel = viewModel

    let hostingController = UIHostingController(rootView: MyMoviesView(viewModel: viewModel))
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
    title = "My Movies"
    view.backgroundColor = .systemBackground
    navigationItem.largeTitleDisplayMode = .always
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewModel?.onAppear()
  }
}
