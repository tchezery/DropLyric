import Flutter
import SpotifyiOS
import UIKit

/// Controls the installed Spotify app; the Web API PKCE login stays in Dart.
final class SpotifyRemoteBridge: NSObject, FlutterStreamHandler,
  SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
  static let shared = SpotifyRemoteBridge()
  private lazy var remote: SPTAppRemote = {
    let config = SPTConfiguration(clientID: "1bdc621fcaa74a21a2c2f90b5b5f0cbc",
      redirectURL: URL(string: "droplyric://callback")!)
    let remote = SPTAppRemote(configuration: config, logLevel: .none)
    remote.delegate = self
    return remote
  }()
  private var events: FlutterEventSink?
  private var state: [String: Any] = [
    "ready": false, "paused": true, "error": "", "appRemoteAuthorized": false,
  ]
  private var pendingURI: String?
  private var pendingResult: FlutterResult?
  private var timeout: Timer?
  private var connectionTimeout: Timer?
  private var awaitingAuthorization = false
  private var didWakeSpotify = false
  private var connecting = false
  private var active = false
  private var wantsConnection = false
  private var appRemoteAuthorized = false

  func register(messenger: FlutterBinaryMessenger) {
    if let token = UserDefaults.standard.string(forKey: "droplyric.spotify.appRemoteToken") {
      remote.connectionParameters.accessToken = token
      appRemoteAuthorized = true
      wantsConnection = true
    }
    FlutterMethodChannel(name: "droplyric/spotify", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
    FlutterEventChannel(name: "droplyric/spotify/events", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "play":
      guard let uri = call.arguments as? String,
        uri.range(of: "^spotify:track:[a-zA-Z0-9]{22}$", options: .regularExpression) != nil
      else {
        result(FlutterError(code: "spotify_track", message: "Faixa Spotify inválida.", details: nil))
        return
      }
      guard pendingResult == nil else {
        result(FlutterError(code: "spotify_busy", message: "Aguarde a conexão com o Spotify.", details: nil))
        return
      }
      guard UIApplication.shared.canOpenURL(URL(string: "spotify:")!) else {
        fail("Instale o aplicativo Spotify neste iPhone e entre na sua conta.", result: result)
        return
      }
      wantsConnection = true
      if remote.isConnected { play(uri, result: result); return }
      pendingURI = uri
      pendingResult = result
      didWakeSpotify = false
      awaitingAuthorization = false
      state = ["ready": false, "paused": true, "uri": uri, "error": ""]
      emit()
      timeout?.invalidate()
      timeout = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self] _ in
        self?.failPending("A conexão com o Spotify expirou. Toque na música para tentar novamente.")
      }
      if remote.connectionParameters.accessToken != nil {
        connectIfNeeded()
      } else { wakeSpotify(uri) }
    case "pause":
      if pendingResult != nil { failPending("Reprodução cancelada.") }
      guard let player = remote.playerAPI, remote.isConnected else { result(nil); return }
      player.pause { [weak self] _, error in self?.complete(result, error: error) }
    case "seek":
      guard let value = call.arguments as? String, let position = Int(value), position >= 0 else {
        result(FlutterError(code: "spotify_seek", message: "Posição inválida.", details: nil))
        return
      }
      guard let player = remote.playerAPI, remote.isConnected else {
        fail("Reconecte o player tocando na música novamente.", result: result)
        return
      }
      player.seek(toPosition: position) { [weak self] _, error in self?.complete(result, error: error) }
    case "disconnect":
      clearSession()
      result(nil)
    case "reconnect":
      state["error"] = ""
      if let uri = pendingURI, pendingResult != nil {
        if appRemoteAuthorized {
          appRemoteAuthorized = false
          remote.connectionParameters.accessToken = nil
          UserDefaults.standard.removeObject(forKey: "droplyric.spotify.appRemoteToken")
        }
        awaitingAuthorization = false
        didWakeSpotify = false
        wakeSpotify(uri)
      } else {
        wantsConnection = true
        connectIfNeeded()
      }
      emit()
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  func useAccessToken(_ token: String) {
    // The Web API token is also accepted for the first connection, but once
    // App Remote returns its own token it must not be overwritten on resume.
    if !appRemoteAuthorized {
      remote.connectionParameters.accessToken = token
    }
    wantsConnection = true
    connectIfNeeded()
  }

  func clearSession() {
    wantsConnection = false
    connectionTimeout?.invalidate()
    connectionTimeout = nil
    connecting = false
    if pendingResult != nil { failPending("Conexão com o Spotify encerrada.") }
    remote.disconnect()
    remote.connectionParameters.accessToken = nil
    appRemoteAuthorized = false
    UserDefaults.standard.removeObject(forKey: "droplyric.spotify.appRemoteToken")
    state = [
      "ready": false, "paused": true, "error": "", "appRemoteAuthorized": false,
    ]
    emit()
  }

  private func wakeSpotify(_ uri: String) {
    guard !appRemoteAuthorized else {
      // An App Remote token is already authorized; reconnect without opening Spotify.
      failPending("Não foi possível reconectar ao Spotify sem abrir o aplicativo.")
      return
    }
    guard !awaitingAuthorization else { return }
    guard !didWakeSpotify else {
      failPending("Não foi possível reconectar ao Spotify. Tente tocar novamente.")
      return
    }
    didWakeSpotify = true
    connectionTimeout?.invalidate()
    connectionTimeout = nil
    connecting = false
    awaitingAuthorization = true
    // Only a user play request may open Spotify; resuming the app never does.
    // Existing app-remote-control consent is reused by the SDK.
    remote.authorizeAndPlayURI(uri, asRadio: false) { [weak self] opened in
      if !opened { self?.failPending("Não foi possível abrir o Spotify neste iPhone.") }
    }
  }

  func handleCallback(_ url: URL) -> Bool {
    guard url.scheme == "droplyric", url.host == "callback" else { return false }
    // While playback authorization is pending, consume every callback shape
    // here so app_links cannot turn it into a Home/Search navigation route.
    guard awaitingAuthorization else { return false }
    let parameters = remote.authorizationParameters(from: url)
    if let token = parameters?[SPTAppRemoteAccessTokenKey], !token.isEmpty {
      awaitingAuthorization = false
      appRemoteAuthorized = true
      remote.connectionParameters.accessToken = token
      UserDefaults.standard.set(token, forKey: "droplyric.spotify.appRemoteToken")
      connectIfNeeded()
    } else {
      failPending("O Spotify não autorizou o player. Tente novamente e permita o acesso ao Spotify.")
    }
    return true
  }

  func becomeActive() { active = true; connectIfNeeded() }
  func resignActive() {
    active = false
    connecting = false
    connectionTimeout?.invalidate()
    connectionTimeout = nil
    if remote.isConnected { remote.disconnect() }
    state["ready"] = false
    emit()
  }
  private func connectIfNeeded() {
    guard active, wantsConnection, !awaitingAuthorization, !connecting,
      !remote.isConnected, remote.connectionParameters.accessToken != nil else { return }
    connecting = true
    connectionTimeout?.invalidate()
    connectionTimeout = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
      guard let self = self, !self.remote.isConnected else { return }
      self.connecting = false
      if let uri = self.pendingURI, !self.awaitingAuthorization {
        self.wakeSpotify(uri)
      }
    }
    remote.connect()
  }

  func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
    connecting = false
    connectionTimeout?.invalidate()
    connectionTimeout = nil
    guard wantsConnection, active else { appRemote.disconnect(); return }
    state["ready"] = true
    state["error"] = ""
    emit()
    appRemote.playerAPI?.delegate = self
    appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] _, error in
      if error != nil { self?.fail("Não foi possível acompanhar a reprodução do Spotify.") }
    })
    if let uri = pendingURI, let result = pendingResult {
      clearPending()
      // Authorization can leave the previous track playing: explicitly select ours.
      play(uri, result: result)
    } else { refreshState() }
  }

  private func play(_ uri: String, result: @escaping FlutterResult) {
    guard let userAPI = remote.userAPI else {
      fail("Não foi possível verificar a conta Spotify. Tente novamente.", result: result)
      return
    }
    userAPI.fetchCapabilities { [weak self] value, error in
      guard let self = self else { return }
      guard error == nil, let capabilities = value as? SPTAppRemoteUserCapabilities else {
        self.fail("Não foi possível verificar a conta Spotify. Tente novamente.", result: result)
        return
      }
      guard capabilities.canPlayOnDemand else {
        self.remote.playerAPI?.pause(nil)
        self.fail("É necessário Spotify Premium para tocar a música escolhida.", result: result)
        return
      }
      self.playSelectedTrack(uri, result: result)
    }
  }

  private func playSelectedTrack(_ uri: String, result: @escaping FlutterResult) {
    guard let player = remote.playerAPI else {
      fail("Não foi possível acessar o player Spotify.", result: result)
      return
    }
    player.getPlayerState { [weak self] value, error in
      guard let self = self else { return }
      guard error == nil, let current = value as? SPTAppRemotePlayerState else {
        self.fail("Não foi possível consultar o player Spotify. Tente novamente.", result: result)
        return
      }
      let callback: SPTAppRemoteCallback = { [weak self] _, error in
        self?.complete(result, error: error)
      }
      if current.track.uri == uri { player.resume(callback) }
      else { player.play(uri, callback: callback) }
    }
  }

  func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
    state = ["ready": remote.isConnected && active, "paused": playerState.isPaused,
      "uri": playerState.track.uri, "position": playerState.playbackPosition,
      "duration": playerState.track.duration, "error": ""]
    emit()
  }
  private func refreshState() {
    remote.playerAPI?.getPlayerState { [weak self] value, _ in
      if let value = value as? SPTAppRemotePlayerState { self?.playerStateDidChange(value) }
    }
  }

  func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
    connecting = false
    connectionTimeout?.invalidate()
    connectionTimeout = nil
    if active {
      if let uri = pendingURI, !awaitingAuthorization {
        if appRemoteAuthorized {
          // A persisted App Remote token can expire. Allow one fresh authorization.
          appRemoteAuthorized = false
          remote.connectionParameters.accessToken = nil
          UserDefaults.standard.removeObject(forKey: "droplyric.spotify.appRemoteToken")
        }
        wakeSpotify(uri)
      } else if pendingResult != nil {
        failPending("Não foi possível conectar ao Spotify. Tente tocar novamente.")
      } else {
        // A suspended/paused Spotify app is not a lost account session.
        state["ready"] = false
        state["paused"] = true
        state["error"] = ""
        emit()
      }
    }
  }
  
  func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
    connecting = false
    state["ready"] = false
    emit()
    if active && error != nil {
      failPending("A conexão com o Spotify foi interrompida. Toque na música para reconectar.")
    }
  }
  private func clearPending() {
    timeout?.invalidate()
    timeout = nil
    pendingURI = nil
    pendingResult = nil
    awaitingAuthorization = false
  }
  private func failPending(_ message: String) {
    let result = pendingResult
    clearPending()
    fail(message, result: result)
  }
  private func fail(_ message: String, result: FlutterResult? = nil) {
    state["ready"] = false
    state["paused"] = true
    state["error"] = message
    emit()
    result?(FlutterError(code: "spotify_playback", message: message, details: nil))
  }
  private func complete(_ result: @escaping FlutterResult, error: Error?) {
    if let error = error {
      fail(error.localizedDescription, result: result)
      return
    }
    clearPending()
    state["error"] = ""
    emit()
    result(nil)
  }
  private func emit() {
    state["appRemoteAuthorized"] = appRemoteAuthorized
    events?(state)
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.events = events
    emit()
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { events = nil; return nil }
}
