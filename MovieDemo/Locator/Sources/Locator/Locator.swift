@MainActor
public final class Locator: DependencyLocator {

  /// A typed key. `T` is the type `resolve` returns; `id` identifies the entry.
  public struct Kind<T>: Hashable, Sendable, CustomStringConvertible {
    public let id: String

    public init(_ id: String = String(describing: T.self)) {
      self.id = id
    }

    public var erased: AnyLocatorKind { AnyLocatorKind(id) }
    public var description: String { id }
  }

  private struct LazyEntry {
    let make: @MainActor (any DependencyLocator) -> Any
  }

  private enum Entry {
    case value(Any)
    case lazy(LazyEntry)
  }

  private var storage: [AnyLocatorKind: Entry] = [:]

  public init() {}

  public func register<T>(_ kind: Kind<T>, make: @escaping @MainActor (any DependencyLocator) -> T) {
    store(.lazy(LazyEntry(make: { make($0) })), for: kind)
  }

  public func register<T>(_ kind: Kind<T>, _ value: T) {
    store(.value(value), for: kind)
  }

  public func resolve<T>(_ kind: Kind<T>) -> T {
    let key = kind.erased
    guard let entry = storage[key] else {
      fatalError("Locator: no registration for \(kind). Registered: \(registeredIds)")
    }
    let raw: Any
    switch entry {
    case .value(let value):
      raw = value
    case .lazy(let lazy):
      raw = lazy.make(self)
      storage[key] = .value(raw)
    }
    guard let typed = raw as? T else {
      fatalError("Locator: registration for \(kind) is \(type(of: raw)), expected \(T.self)")
    }
    return typed
  }

  public func isRegistered(_ kind: AnyLocatorKind) -> Bool {
    storage[kind] != nil
  }

  public func missing(from required: [AnyLocatorKind]) -> [AnyLocatorKind] {
    required.filter { storage[$0] == nil }
  }

  public func verify(allOf required: [AnyLocatorKind]) {
    let missing = missing(from: required)
    precondition(missing.isEmpty, "Locator: missing registrations: \(missing)")
  }

  private func store<T>(_ entry: Entry, for kind: Kind<T>) {
    precondition(storage[kind.erased] == nil, "Locator: \(kind) is already registered")
    storage[kind.erased] = entry
  }

  private var registeredIds: [String] {
    storage.keys.map(\.id).sorted()
  }
}
