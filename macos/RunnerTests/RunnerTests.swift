import Cocoa
import FlutterMacOS
import XCTest
@testable import droplyric

class RunnerTests: XCTestCase {
  func testCommandsRejectScriptInjectionAndInvalidPositions() {
    XCTAssertNil(SpotifyDesktopBridge.command("play", argument: "spotify:track:invalid\"\nquit"))
    XCTAssertNil(SpotifyDesktopBridge.command("seek", argument: "1\nquit"))
    XCTAssertNil(SpotifyDesktopBridge.command("seek", argument: "-1"))
    XCTAssertNil(SpotifyDesktopBridge.command("seek", argument: "86400001"))
    XCTAssertEqual(SpotifyDesktopBridge.command("seek", argument: "45250"), "set player position to (45250 / 1000)")
    XCTAssertNotNil(SpotifyDesktopBridge.command("play", argument: "spotify:track:7qiZfU4dY1lWllzX7mPBI3"))
  }

  func testMetadataAndPlaybackUnitsFromAppleScriptDescriptors() {
    // Executes only a literal list, without contacting Spotify or asking consent.
    var error: NSDictionary?
    let value = NSAppleScript(source: "return {true, \"spotify:track:7qiZfU4dY1lWllzX7mPBI3\", \"Song, with punctuation\", \"Artist\", \"Album\", 12.5, 263000}")!
      .executeAndReturnError(&error)
    XCTAssertNil(error)
    let state = SpotifyDesktopBridge.decode(value)
    XCTAssertEqual(state["position"] as? Double, 12500)
    XCTAssertEqual(state["duration"] as? Double, 263000)
    XCTAssertEqual(state["paused"] as? Bool, false)
    XCTAssertEqual(state["title"] as? String, "Song, with punctuation")
  }

  func testScriptsCompileAgainstInstalledSpotifyDictionary() throws {
    guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil else {
      throw XCTSkip("Spotify dictionary is not installed on this machine")
    }
    let commands = [SpotifyDesktopBridge.snapshot,
      SpotifyDesktopBridge.command("play", argument: "spotify:track:7qiZfU4dY1lWllzX7mPBI3")!,
      SpotifyDesktopBridge.command("seek", argument: "12500")!, "pause", "next track", "previous track"]
    for command in commands {
      var error: NSDictionary?
      let script = NSAppleScript(source: "tell application id \"com.spotify.client\"\n\(command)\nend tell")!
      XCTAssertTrue(script.compileAndReturnError(&error), "\(String(describing: error))")
    }
  }

  func testStoppedAndInvalidState() {
    var error: NSDictionary?
    let value = NSAppleScript(source: "return {false, \"\", \"\", \"\", \"\", 0, 0}")!
      .executeAndReturnError(&error)
    XCTAssertEqual(SpotifyDesktopBridge.decode(value)["paused"] as? Bool, true)
    XCTAssertEqual(SpotifyDesktopBridge.decode(value)["uri"] as? String, "")
    XCTAssertEqual(SpotifyDesktopBridge.decode(NSAppleEventDescriptor(string: "bad"))["ready"] as? Bool, false)
  }
}
