/// A location expressed as coordinates `x` and `y`, and defaults to `unknown`.
public struct Location:
 Sendable,
 Equatable, ExpressibleByNilLiteral, CustomStringConvertible {
 public var x: Double
 public var y: Double

 public var latitude: Double { x }
 public var longitude: Double { y }
 
 private init(unchecked x: Double, _ y: Double) {
  self.x = x
  self.y = y
 }
 
 public init(x: Double, y: Double) {
  assert(
   Self.checkCoordinates(x, y),
   "Invalid coordinates for location: \(x), \(y) with `\(#function)`"
  )
  self.x = x
  self.y = y
 }
 
 public init(nilLiteral: ()) { self = .unknown }

 /// A checked location that returns `unknown` if invalid.
 public static func checked(x: Double, y: Double) -> Self {
  guard checkCoordinates(x, y) else { return nil }
  return unchecked(x: x, y: y)
 }

 public static func unchecked(x: Double, y: Double) -> Self {
  self.init(unchecked: x, y)
 }

 ///
 public static func coordinates(x: Double, y: Double) -> Self {
  Self(x: x, y: y)
 }

 public static let unknown: Self = unchecked(x: .infinity, y: .infinity)
 public static let denied: Self = unchecked(x: .nan, y: .nan)
 public static let invalid: Self = unchecked(x: -.infinity, y: -.infinity)

 public var isValid: Bool {
  x >= -90 && x <= 90 && y >= -180 && y <= 180 && !x.isNaN && !y.isNaN
 }

 public var isInvalid: Bool {
  x < -90 || x > 90 || y < -180 || y > 180 || x.isNaN || y.isNaN
 }

 private static func checkCoordinates(_ x: Double, _ y: Double) -> Bool {
  x >= -90 && x <= 90 && y >= -180 && y <= 180 && !x.isNaN && !y.isNaN
 }

 public func hash(into hasher: inout Hasher) {
  hasher.combine(x)
  hasher.combine(y)
 }

 public static func == (lhs: Self, rhs: Self) -> Bool {
  if
   (
    lhs.x == .infinity && rhs.x == .infinity && lhs.y == .infinity &&
     rhs.y == .infinity
   ) ||
   (
    lhs.x == -.infinity && rhs.x == -.infinity && lhs.y == -.infinity &&
     rhs.y == -.infinity
   ) ||
   (
    lhs.x.isNaN && rhs.x.isNaN && lhs.y.isNaN &&
     rhs.y.isNaN
   ) {
   return true
  }

  return lhs.x == rhs.x && lhs.y == rhs.y
 }

 public static func ~= (lhs: Self, rhs: Self) -> Bool {
  if lhs == .unknown || lhs == .denied || lhs == .invalid { return lhs == rhs }
  return lhs.isApproximatelyEqual(to: rhs, precision: .leastNonzeroMagnitude)
 }

 @inline(__always)
 public func isApproximatelyEqual(to other: Self, precision: Double) -> Bool {
  assert(precision > 0, "precision must be greater than zero")

  if self == .unknown || self == .denied || self == .invalid { return false }

  let lhsX = x
  let rhsX = other.x
  let lhsY = y
  let rhsY = other.y
  return lhsX == rhsX
   ? true
   : (lhsX > rhsX ? lhsX - rhsX : rhsX - lhsX) < precision &&
   lhsY == rhsY ? true : (lhsY > rhsY ? lhsY - rhsY : rhsY - lhsY) < precision
 }

 public var description: String {
  if self == .unknown { return "unknown" }
  else if self == .denied { return "denied" }
  else if self == .invalid { return "invalid" }

  return "\(x), \(y)"
 }
}

extension Location: LosslessStringConvertible {
 public init?(_ description: String) {
  let split =
   description.split(separator: ",", omittingEmptySubsequences: false)
  guard split.count == 2 else { return nil }
  guard
   let x = Double(split[0].trimmingCharacters(in: .whitespaces)),
   let y = Double(split[1].trimmingCharacters(in: .whitespaces))
  else { return nil }
  self.init(unchecked: x, y)
 }
}

extension Location: Codable {
 enum CodingKeys: CodingKey {
  case x
  case y
 }

 struct LocationError: LocalizedError, CustomStringConvertible {
  let x: Double
  let y: Double
  var description: String {
   "Invalid coordinates for location: \(x), \(y)"
  }
 }

 /// Note: Custom implementation throws when invalid so the value can be
 /// unwrapped to unknown or expressed as an error.
 /// Invalid coordinates aren't meant to be persistent by default.
 public init(from decoder: any Decoder) throws {
  let container = try decoder.container(keyedBy: CodingKeys.self)
  let x = try container.decode(Double.self, forKey: .x)
  let y = try container.decode(Double.self, forKey: .y)
  guard Self.checkCoordinates(x, y) else { throw LocationError(x: x, y: y) }
  self.init(unchecked: x, y)
 }
}

extension Location {
 struct Degrees: CustomStringConvertible {
  // TODO: Provide actual conversions with minutes and seconds
  // https://www.britannica.com/science/latitude
  public var description: String {
   "\(north)° N \(west)° W"
  }
  
  let north: Double
  let west: Double
 }
 
 var degress: Degrees { Degrees(north: x, west: -y) }
}

// MARK: - Request Interface
#if canImport(CoreLocation)
@_exported import CoreLocation

@available(macOS 11.0, iOS 14.0, *)
extension Location {
 @usableFromInline
 final class Delegate: NSObject, CLLocationManagerDelegate {
  public func locationManager(
   _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {}

  public func locationManager(
   _ manager: CLLocationManager, didFailWithError error: any Error
  ) {}
 }

 @usableFromInline
 typealias Manager = CLLocationManager
 public enum AuthorizationLevel: Int32, Sendable {
  case authorizedOnDemand = -1
  case authorizedAlways = 3
  case authorizedWhenInUse = 4

  public var status: CLAuthorizationStatus? {
   CLAuthorizationStatus(rawValue: Int32(rawValue))
  }
 }

 @usableFromInline
 static let delegate = Delegate()
 @usableFromInline
 static let manager = {
  let manager = Manager()
  manager.delegate = delegate
  return manager
 }()

 @inlinable
 public static func checkAuthorization(_ level: AuthorizationLevel) {
  switch level {
  case .authorizedAlways:
   manager.requestAlwaysAuthorization()
  case .authorizedWhenInUse:
   #if !DEBUG
   assert(
    (Bundle.main.infoDictionary?[
     "NSLocationWhenInUseUsageDescription"
    ] as? String)?.isEmpty == false,
    """
    The app's Info.plist must contain an “NSLocationWhenInUseUsageDescription” \
    key with a string value explaining to the user how the app uses this data
    """
   )
   #else
   if
    (Bundle.main.infoDictionary?[
     "NSLocationWhenInUseUsageDescription"
    ] as? String) == nil {
    print(
     """
     The app's Info.plist must contain an “NSLocationWhenInUseUsageDescription” \
     key with a string value explaining to the user how the app uses this data
     """
    )
   }
   #endif
   manager.requestWhenInUseAuthorization()
  case .authorizedOnDemand:
   manager.requestLocation()
  }
 }

 @inlinable
 public static func request(_ level: AuthorizationLevel) -> Self {
  checkAuthorization(level)
  guard let location = manager.location else {
   if manager.authorizationStatus == .denied {
    return .denied
   }
   return .unknown
  }
  return Self(
   x: location.coordinate.latitude,
   y: location.coordinate.longitude
  )
 }

 @available(macOS 13.0, iOS 16.0, *)
 @inlinable
 public static func requestAsync(
  _ level: AuthorizationLevel
 ) async throws -> Self {
  switch manager.authorizationStatus {
  case .notDetermined:
   checkAuthorization(level)
   try await Task.sleep(for: .seconds(0.5))
   if manager.authorizationStatus == .notDetermined {
    return try await requestAsync(level)
   } else {
    return request(level)
   }
  case .denied: return .denied
  case .restricted, .authorizedAlways, .authorizedWhenInUse, .authorized:
   return request(level)
  @unknown default: fatalError("location authorization status unknown")
  }
 }
}
#endif
