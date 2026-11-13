import Locator
import MovieStore

public enum MovieDetailModule {

  /// Kinds this module resolves from the locator.
  public static let requiredKinds: [AnyLocatorKind] = [.apiClient, .analyticsClient, .movieStore]

  @MainActor
  public static func registerServices(in locator: any DependencyLocator) {
    locator.register(.movieDetailProvider) { locator in
      MovieDetailProviderImpl(locator: locator)
    }
  }
}

extension Locator.Kind {
  public static var movieDetailProvider: Locator.Kind<any MovieDetailProvider> { Locator.Kind("MovieDetailProvider") }
}

extension AnyLocatorKind {
  public static let movieDetailProvider = Locator.Kind<any MovieDetailProvider>.movieDetailProvider.erased
}
