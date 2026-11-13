import Locator
import MovieDetail
import MovieStore

public enum MyMoviesModule {

  /// Kinds this module resolves from the locator.
  public static let requiredKinds: [AnyLocatorKind] = [.analyticsClient, .movieStore, .movieDetailProvider]

  @MainActor
  public static func registerServices(in locator: any DependencyLocator) {
    locator.register(.myMoviesProvider) { locator in
      MyMoviesProviderImpl(locator: locator)
    }
  }
}

extension Locator.Kind {
  public static var myMoviesProvider: Locator.Kind<any MyMoviesProvider> { Locator.Kind("MyMoviesProvider") }
}

extension AnyLocatorKind {
  public static let myMoviesProvider = Locator.Kind<any MyMoviesProvider>.myMoviesProvider.erased
}
