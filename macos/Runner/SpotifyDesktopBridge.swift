import Cocoa
import FlutterMacOS

/// Local automation only: no Spotify developer credentials or Web API session.
final class SpotifyDesktopBridge: NSObject, FlutterStreamHandler {
  private let bundleID = "com.spotify.client"
  private let consentKey = "spotify.desktop.enabled"
  private var events: FlutterEventSink?
  private var timer: Timer?
  private var enabled = false
  private var generation = 0
  private var state: [String: Any] = ["ready": false, "paused": true, "error": ""]

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "droplyric/spotify", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    FlutterEventChannel(name: "droplyric/spotify/events", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  private var running: Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      enabled = UserDefaults.standard.bool(forKey: consentKey)
      if enabled { startObserving() }
      result(nil)
    case "disconnect":
      generation += 1
      enabled = false
      UserDefaults.standard.set(false, forKey: consentKey)
      timer?.invalidate()
      timer = nil
      state = ["ready": false, "paused": true, "appRemoteAuthorized": false, "error": ""]
      emit()
      result(nil)
    case "connect", "reconnect":
      withSpotify(result: result) { [weak self] in
        guard let self = self else { return }
        if self.refresh() { self.startObserving(); result(nil) }
        else { result(self.currentError) }
      }
    case "play", "pause", "seek", "next", "previous":
      guard let command = Self.command(call.method, argument: call.arguments as? String ?? "") else {
        result(FlutterError(code: "spotify_argument", message: "Link de música ou posição inválida.", details: nil))
        return
      }
      withSpotify(result: result) { [weak self] in
        guard let self = self else { return }
        guard self.execute(command) != nil else { result(self.currentError); return }
        _ = self.refresh()
        self.startObserving()
        result(nil)
      }
    case "content", "playContent":
      result(FlutterError(code: "spotify_unsupported", message: "No Mac, escolha a música por link, pelo histórico ou no app Spotify.", details: nil))
    default: result(FlutterMethodNotImplemented)
    }
  }

  /// Only validated identifiers/numbers enter AppleScript source.
  static func command(_ action: String, argument: String) -> String? {
    switch action {
    case "play":
      guard argument.range(of: "^spotify:track:[a-zA-Z0-9]{22}$", options: .regularExpression) != nil else { return nil }
      return """
      if player state is not stopped and id of current track is "\(argument)" then
        play
      else
        play track "\(argument)"
      end if
      """
    case "pause": return "pause"
    case "next": return "next track"
    case "previous": return "previous track"
    case "seek":
      guard let milliseconds = Int64(argument), milliseconds >= 0,
        milliseconds <= 86_400_000 else { return nil }
      return "set player position to (\(milliseconds) / 1000)"
    default: return nil
    }
  }

  private func withSpotify(result: @escaping FlutterResult, action: @escaping () -> Void) {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
      fail("Instale o aplicativo Spotify no Mac e entre na sua conta.")
      result(currentError)
      return
    }
    enabled = true
    if running { action(); return }
    let requestGeneration = generation
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
      DispatchQueue.main.async {
        guard let self = self, self.generation == requestGeneration else {
          result(FlutterError(code: "spotify_cancelled", message: "Conexão cancelada.", details: nil)); return
        }
        if error != nil {
          self.fail("Não foi possível abrir o Spotify. Abra o aplicativo e tente novamente.")
          result(self.currentError)
        } else { action() }
      }
    }
  }

  private func startObserving() {
    guard enabled else { return }
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      guard let self = self, self.enabled else { return }
      _ = self.refresh()
    }
  }

  @discardableResult private func refresh() -> Bool {
    guard running else {
      state = ["ready": false, "paused": true, "appRemoteAuthorized": enabled,
        "error": "Abra o Spotify para acompanhar a reprodução."]
      emit()
      return false
    }
    guard let value = execute(Self.snapshot) else { return false }
    state = Self.decode(value)
    state["appRemoteAuthorized"] = true
    UserDefaults.standard.set(true, forKey: consentKey)
    emit()
    return true
  }

  // A list descriptor preserves punctuation/newlines in track metadata.
  static let snapshot = """
    if player state is stopped then return {false, "", "", "", "", 0, 0}
    set song to current track
    return {player state is playing, id of song, name of song, artist of song, album of song, player position, duration of song}
    """

  static func decode(_ value: NSAppleEventDescriptor) -> [String: Any] {
    guard value.numberOfItems == 7 else {
      return ["ready": false, "paused": true, "error": "O Spotify retornou um estado inválido."]
    }
    let seconds = Double(value.atIndex(6)?.stringValue ?? "0") ?? 0
    // Spotify reports track duration in milliseconds (despite its sdef description).
    let duration = Double(value.atIndex(7)?.stringValue ?? "0") ?? 0
    return ["ready": true, "paused": !(value.atIndex(1)?.booleanValue ?? false),
      "uri": value.atIndex(2)?.stringValue ?? "", "title": value.atIndex(3)?.stringValue ?? "",
      "artist": value.atIndex(4)?.stringValue ?? "", "album": value.atIndex(5)?.stringValue ?? "",
      "position": max(0, min(seconds * 1000, duration)), "duration": max(0, duration), "error": ""]
  }

  private func execute(_ body: String) -> NSAppleEventDescriptor? {
    // AppleScript runs on the main thread; bound each IPC call so a hung player
    // cannot accumulate polling requests. Only explicit actions launch Spotify.
    let source = """
    with timeout of 2 seconds
      tell application id "com.spotify.client"
        \(body)
      end tell
    end timeout
    """
    var error: NSDictionary?
    guard let script = NSAppleScript(source: source) else {
      fail("Não foi possível preparar a conexão com o Spotify.")
      return nil
    }
    let response = script.executeAndReturnError(&error)
    if let error = error {
      let code = error[NSAppleScript.errorNumber] as? Int ?? 0
      if code == -1743 || code == -10004 {
        enabled = false
        UserDefaults.standard.set(false, forKey: consentKey)
        timer?.invalidate()
        timer = nil
        fail("Permita que o DropLyric controle o Spotify em Ajustes do Sistema > Privacidade e Segurança > Automação. Depois conecte novamente.")
      } else {
        fail("Não foi possível acessar o Spotify. Abra o aplicativo e tente novamente. (\(code))")
      }
      return nil
    }
    return response
  }

  private var currentError: FlutterError {
    FlutterError(code: "spotify_desktop", message: state["error"] as? String, details: nil)
  }
  private func fail(_ message: String) {
    state = ["ready": false, "paused": true, "appRemoteAuthorized": enabled, "error": message]
    emit()
  }
  private func emit() { events?(state) }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.events = events
    emit()
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { events = nil; return nil }
  deinit { timer?.invalidate() }
}
