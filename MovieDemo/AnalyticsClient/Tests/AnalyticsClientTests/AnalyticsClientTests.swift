import Testing
import Locator
@testable import AnalyticsClient
import AnalyticsClientTesting

@Suite("AnalyticsClient")
struct AnalyticsClientTests {

  @Test func spyRecordsEventsInOrder() {
    let spy = SpyAnalyticsClient()
    spy.track(AnalyticsEvent(name: "first"))
    spy.track(AnalyticsEvent(name: "second", parameters: ["k": "v"]))
    #expect(spy.events == [AnalyticsEvent(name: "first"), AnalyticsEvent(name: "second", parameters: ["k": "v"])])
  }

  @Test func spyFiltersByName() {
    let spy = SpyAnalyticsClient()
    spy.track(AnalyticsEvent(name: "a"))
    spy.track(AnalyticsEvent(name: "b"))
    spy.track(AnalyticsEvent(name: "a", parameters: ["n": "2"]))
    #expect(spy.events(named: "a").count == 2)
    #expect(spy.events(named: "b").count == 1)
    #expect(spy.events(named: "c").isEmpty)
  }

  @Test func consoleClientTracksWithoutCrashing() {
    ConsoleAnalyticsClient().track(AnalyticsEvent(name: "smoke", parameters: ["x": "1"]))
  }

  @Test @MainActor func moduleRegistersConsoleClient() {
    let locator = Locator()
    AnalyticsClientModule.registerServices(in: locator)
    #expect(locator.isRegistered(.analyticsClient))
    #expect(AnalyticsClientModule.requiredKinds.isEmpty)
    #expect(locator.resolve(.analyticsClient) is ConsoleAnalyticsClient)
  }
}
