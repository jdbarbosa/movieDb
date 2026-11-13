/// Stores dependencies by typed key and resolves them later.
///
/// All registration and resolution happens on the main actor: the app
/// registers at launch and resolves when building screens.
@MainActor
public protocol DependencyLocator: AnyObject {

  /// Registers a lazy factory. The closure runs on first `resolve` and its
  /// result is cached for subsequent calls.
  func register<T>(_ kind: Locator.Kind<T>, make: @escaping @MainActor (any DependencyLocator) -> T)

  /// Registers an already-built value.
  func register<T>(_ kind: Locator.Kind<T>, _ value: T)

  /// Returns the value for `kind`, building it on first use.
  /// Traps if nothing was registered for `kind`.
  func resolve<T>(_ kind: Locator.Kind<T>) -> T

  func isRegistered(_ kind: AnyLocatorKind) -> Bool

  /// Every kind in `required` that has no registration. Empty means OK.
  func missing(from required: [AnyLocatorKind]) -> [AnyLocatorKind]

  /// Traps unless every kind in `required` is registered.
  func verify(allOf required: [AnyLocatorKind])
}
