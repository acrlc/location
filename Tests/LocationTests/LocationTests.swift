@testable import Location
import XCTest

final class LocationTests: XCTestCase {
 func testLocation() throws {
  let validString = try XCTUnwrap(Location("-90, 180"))
  XCTAssertNil(Location("0 0"))
  XCTAssertNil(Location("0 ,,0"))

  XCTAssertEqual(validString, Location.unchecked(x: -90, y: 180))
  XCTAssertEqual(validString.description, "-90.0, 180.0")
  XCTAssert(validString.isValid)
  XCTAssert(!validString.isInvalid)

  let invalidString = try XCTUnwrap(Location("-90.1, 180.1"))
  XCTAssert(invalidString.isInvalid)
  XCTAssert(!invalidString.isValid)
  
  let invalid = Location.unchecked(x: -.infinity, y: -.infinity)
  XCTAssertEqual(invalid, .invalid)
  XCTAssert(invalid.isInvalid)
  XCTAssert(!invalid.isValid)

  let unknown = Location.unchecked(x: .infinity, y: .infinity)
  XCTAssertEqual(unknown, .unknown)
  XCTAssert(unknown.isInvalid)
  XCTAssert(!unknown.isValid)

  let denied = Location.unchecked(x: .nan, y: .nan)
  XCTAssertEqual(denied, .denied)
  XCTAssert(denied.isInvalid)
  XCTAssert(!denied.isValid)

 }
 
 func testRequestInterface() async throws {
  #if os(macOS) || os(iOS)
  do {
   try await _ = Location.requestAsync(.authorizedOnDemand)
  } catch {
   XCTFail(error.localizedDescription)
  }
  #else
  XCTSkip("Platform not supported.")
  #endif
 }
}
