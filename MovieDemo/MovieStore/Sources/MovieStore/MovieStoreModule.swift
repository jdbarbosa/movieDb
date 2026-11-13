import Locator

public enum MovieStoreModule {

  /// Kinds this module resolves from the locator. None: it is a leaf.
  public static let requiredKinds: [AnyLocatorKind] = []

  @MainActor
  public static func registerServices(in locator: any DependencyLocator) {
    locator.register(.movieStore) { _ in
      LocalMovieStore(persistence: FileMovieStorePersistence.applicationSupport())
    }
  }
}

extension Locator.Kind {
  public static var movieStore: Locator.Kind<any MovieStore> { Locator.Kind("MovieStore") }
}

extension AnyLocatorKind {
  public static let movieStore = Locator.Kind<any MovieStore>.movieStore.erased
}
