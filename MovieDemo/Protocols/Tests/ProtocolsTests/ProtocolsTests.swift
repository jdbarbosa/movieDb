import Testing
import UIKit
@testable import Protocols

@MainActor
@Observable
private final class FakeViewModel: ViewModel {
  typealias ViewControllerType = FakeViewController
}

@MainActor
private final class FakeViewController: UIViewController, ViewModelBindable {
  typealias ViewModelType = FakeViewModel
  var bound: FakeViewModel?

  func bind(viewModel: FakeViewModel) {
    bound = viewModel
  }
}

@Suite("Protocols")
@MainActor
struct ProtocolsTests {

  @Test func bindStoresViewModel() {
    let viewModel = FakeViewModel()
    let viewController = FakeViewController()
    viewController.bind(viewModel: viewModel)
    #expect(viewController.bound === viewModel)
  }
}
