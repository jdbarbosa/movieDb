import UIKit

/// Implemented by view controllers that receive their view model after construction.
public protocol ViewModelBindable {

  /// The view model type the implementer binds to.
  associatedtype ViewModelType

  @MainActor
  func bind(viewModel: ViewModelType)
}

/// Implemented by view models to name the view controller they drive.
public protocol ViewModel {

  /// The concrete view controller type that binds to this view model.
  associatedtype ViewControllerType: UIViewController & ViewModelBindable
    where ViewControllerType.ViewModelType == Self
}
