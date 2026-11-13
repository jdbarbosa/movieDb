import os
import AnalyticsClient

/// Records every tracked event so tests can assert on names and parameters.
public final class SpyAnalyticsClient: AnalyticsClient, Sendable {

  private let storage = OSAllocatedUnfairLock<[AnalyticsEvent]>(initialState: [])

  public init() {}

  public var events: [AnalyticsEvent] {
    storage.withLock { $0 }
  }

  public func events(named name: String) -> [AnalyticsEvent] {
    events.filter { $0.name == name }
  }

  public func track(_ event: AnalyticsEvent) {
    storage.withLock { $0.append(event) }
  }
}
