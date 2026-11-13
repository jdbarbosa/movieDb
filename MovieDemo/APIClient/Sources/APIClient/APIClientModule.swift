import Locator

public enum APIClientModule {

  /// Kinds this module resolves from the locator. None: it is a leaf.
  public static let requiredKinds: [AnyLocatorKind] = []

  @MainActor
  public static func registerServices(in locator: any DependencyLocator, configuration: APIConfiguration) {
    locator.register(.apiClient) { _ in
      MovieDatabaseAPIClient(configuration: configuration)
    }
  }
}

extension Locator.Kind {
  public static var apiClient: Locator.Kind<any APIClient> { Locator.Kind("APIClient") }
}

extension AnyLocatorKind {
  public static let apiClient = Locator.Kind<any APIClient>.apiClient.erased
}
