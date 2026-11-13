import Locator

public enum MovieListModule {

  /// Kinds this module resolves from the locator.
  public static let requiredKinds: [AnyLocatorKind] = [.apiClient, .analyticsClient, .movieDetailProvider]

  @MainActor
  public static func registerServices(in locator: any DependencyLocator) {
    locator.register(.movieListProvider) { locator in
      MovieListProviderImpl(locator: locator)
    }
  }
}

extension Locator.Kind {
  public static var movieListProvider: Locator.Kind<any MovieListProvider> { Locator.Kind("MovieListProvider") }
}

extension AnyLocatorKind {
  public static let movieListProvider = Locator.Kind<any MovieListProvider>.movieListProvider.erased
}
