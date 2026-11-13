/// A type-erased locator key. Used to declare a module's required
/// dependencies and to verify registrations without knowing the value type.
public struct AnyLocatorKind: Hashable, Sendable, CustomStringConvertible {
  public let id: String

  public init(_ id: String) {
    self.id = id
  }

  public var description: String { id }
}
