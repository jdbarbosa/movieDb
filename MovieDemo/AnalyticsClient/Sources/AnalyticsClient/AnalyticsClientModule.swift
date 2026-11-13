import Locator

public enum AnalyticsClientModule {

  public static let requiredKinds: [AnyLocatorKind] = []

  @MainActor
  public static func registerServices(in locator: any DependencyLocator) {
    locator.register(.analyticsClient) { _ in ConsoleAnalyticsClient() }
  }
}

extension Locator.Kind {
  public static var analyticsClient: Locator.Kind<any AnalyticsClient> { Locator.Kind("AnalyticsClient") }
}

extension AnyLocatorKind {
  public static let analyticsClient = Locator.Kind<any AnalyticsClient>.analyticsClient.erased
}
