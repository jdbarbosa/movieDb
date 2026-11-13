import Testing
@testable import Locator

@MainActor
private final class Counter {
  var count = 0
}

@MainActor
private final class Service {}

@Suite("Locator")
@MainActor
struct LocatorTests {

  @Test func resolvesRegisteredValue() {
    let locator = Locator()
    locator.register(Locator.Kind<Int>("Int"), 42)
    #expect(locator.resolve(Locator.Kind<Int>("Int")) == 42)
  }

  @Test func lazyClosureRunsOnceOnFirstResolve() {
    let locator = Locator()
    let counter = Counter()
    let kind = Locator.Kind<Service>("Service")
    locator.register(kind) { _ in
      counter.count += 1
      return Service()
    }
    #expect(counter.count == 0)
    let first = locator.resolve(kind)
    let second = locator.resolve(kind)
    #expect(counter.count == 1)
    #expect(first === second)
  }

  @Test func isRegisteredReflectsState() {
    let locator = Locator()
    let kind = Locator.Kind<Int>("Int")
    #expect(locator.isRegistered(kind.erased) == false)
    locator.register(kind, 1)
    #expect(locator.isRegistered(kind.erased) == true)
  }

  @Test func missingReportsExactlyUnregisteredKinds() {
    let locator = Locator()
    locator.register(Locator.Kind<Int>("A"), 1)
    let missing = locator.missing(from: [AnyLocatorKind("A"), AnyLocatorKind("B"), AnyLocatorKind("C")])
    #expect(missing == [AnyLocatorKind("B"), AnyLocatorKind("C")])
  }

  @Test func verifyPassesWhenAllPresent() {
    let locator = Locator()
    locator.register(Locator.Kind<Int>("A"), 1)
    locator.register(Locator.Kind<String>("B"), "b")
    locator.verify(allOf: [AnyLocatorKind("A"), AnyLocatorKind("B")])
  }

  @Test func distinctKindsDoNotCollide() {
    let locator = Locator()
    locator.register(Locator.Kind<Int>("one"), 1)
    locator.register(Locator.Kind<Int>("two"), 2)
    #expect(locator.resolve(Locator.Kind<Int>("one")) == 1)
    #expect(locator.resolve(Locator.Kind<Int>("two")) == 2)
  }

  @Test func erasedKindSharesId() {
    #expect(Locator.Kind<Int>("x").erased == AnyLocatorKind("x"))
  }
}
