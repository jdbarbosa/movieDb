import os

/// Logs events to the unified logging system. The demo's only "real" backend.
public struct ConsoleAnalyticsClient: AnalyticsClient {

  private let logger = Logger(subsystem: "com.glazedsolutions.MovieDemo", category: "Analytics")

  public init() {}

  public func track(_ event: AnalyticsEvent) {
    let parameters = event.parameters
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value)" }
      .joined(separator: " ")
    logger.info("\(event.name, privacy: .public) \(parameters, privacy: .public)")
  }
}
