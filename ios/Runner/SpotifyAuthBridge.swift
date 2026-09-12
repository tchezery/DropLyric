import Flutter
import Security
import SpotifyiOS
import UIKit

/// One renewable authorization for both catalog access and App Remote.
final class SpotifyAuthBridge: NSObject, SPTSessionManagerDelegate {
  static let shared = SpotifyAuthBridge()
  private lazy var manager = makeManager()
  private var restored = false
  private var loginResult: FlutterResult?
  private var renewalResults: [FlutterResult] = []
  private var timeout: Timer?
  private let keychainQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "droplyric.spotify.session",
    kSecAttrAccount as String: "spotify",
  ]

  private func makeManager() -> SPTSessionManager {
    let configuration = SPTConfiguration(
      clientID: "1bdc621fcaa74a21a2c2f90b5b5f0cbc",
      redirectURL: URL(string: "droplyric://callback")!)
    // Logging in must not start an arbitrary song.
    let manager = SPTSessionManager(configuration: configuration, delegate: self)
    manager.alwaysShowAuthorizationDialog = false
    return manager
  }

  func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "droplyric/spotify-auth", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        do {
          try self.restore()
          switch call.method {
          case "restore": result(self.payload())
          case "login": self.login(result)
          case "refresh": self.validSession(forceRefresh: true, result: result)
          case "session": self.validSession(result: result)
          case "setAccessToken":
            if let token = call.arguments as? String, !token.isEmpty {
              SpotifyRemoteBridge.shared.useAccessToken(token)
            }
            result(nil)
          case "logout": try self.logout(); result(nil)
          default: result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "spotify_storage",
            message: "Não foi possível acessar a sessão salva. Desbloqueie o iPhone e tente novamente.", details: nil))
        }
      }
  }

  private func restore() throws {
    guard !restored else { return }
    var query = keychainQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var value: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &value)
    if status == errSecSuccess, let data = value as? Data {
      manager.session = try NSKeyedUnarchiver.unarchivedObject(ofClass: SPTSession.self, from: data)
    } else if status != errSecItemNotFound {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
    if let token = manager.session?.accessToken {
      SpotifyRemoteBridge.shared.useAccessToken(token)
    }
    restored = true
  }

  private func save(_ session: SPTSession) throws {
    let data = try NSKeyedArchiver.archivedData(withRootObject: session, requiringSecureCoding: true)
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    var status = SecItemUpdate(keychainQuery as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(keychainQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
  }

  private func payload() -> [String: Any]? {
    guard let session = manager.session else { return nil }
    return ["access_token": session.accessToken, "refresh_token": session.refreshToken,
      "expires_at": Int64(session.expirationDate.timeIntervalSince1970 * 1000)]
  }

  private func login(_ result: @escaping FlutterResult) {
    guard loginResult == nil, renewalResults.isEmpty else {
      result(FlutterError(code: "spotify_busy", message: "Aguarde a conexão com o Spotify.", details: nil))
      return
    }
    if manager.session != nil { validSession(result: result); return }
      // Prefer the Spotify app, with Safari as the supported fallback.
    loginResult = result
    startTimeout(seconds: 120)
    let scopes: SPTScope = [.appRemoteControl, .userReadEmail, .userReadPrivate,
      .userReadPlaybackState, .userModifyPlaybackState]
    manager.initiateSession(with: scopes, options: .clientOnly, campaign: nil)
  }

  private func validSession(forceRefresh: Bool = false, result: @escaping FlutterResult) {
    guard let session = manager.session else { result(nil); return }
    if !forceRefresh && session.expirationDate.timeIntervalSinceNow > 60 {
      SpotifyRemoteBridge.shared.useAccessToken(session.accessToken)
      result(payload())
      return
    }
    renewalResults.append(result)
    if renewalResults.count == 1 {
      startTimeout(seconds: 25)
      manager.renewSession()
    }
  }

  func handleCallback(_ url: URL) -> Bool {
    // Catalog login uses Dart PKCE; only consume callbacks for native login.
    guard loginResult != nil, url.scheme == "droplyric", url.host == "callback" else {
      return false
    }
    return manager.application(UIApplication.shared, open: url, options: [:])
  }

  func becomeActive() {
    do {
      try restore()
      guard loginResult == nil, manager.session != nil else { return }
      validSession { _ in /* Renewal is silent; network failures retain the session. */ }
    } catch { /* Keychain can be unavailable while locked; retry on next access. */ }
  }

  private func logout() throws {
    let status = SecItemDelete(keychainQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
    manager.delegate = nil
    manager = makeManager()
    restored = true
    finish(FlutterError(code: "spotify_cancelled", message: "Sessão encerrada.", details: nil))
    SpotifyRemoteBridge.shared.clearSession()
  }

  private func startTimeout(seconds: TimeInterval) {
    timeout?.invalidate()
    timeout = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      let session = self.manager.session
      self.manager.delegate = nil
      self.manager = self.makeManager()
      self.manager.session = session
      self.finish(FlutterError(code: "spotify_timeout",
        message: "O Spotify demorou para responder. Tente novamente.", details: nil))
    }
  }

  private func finish(_ value: Any?) {
    timeout?.invalidate()
    timeout = nil
    let callbacks = renewalResults
    let login = loginResult
    renewalResults = []
    loginResult = nil
    login?(value)
    callbacks.forEach { $0(value) }
  }

  private func accept(_ session: SPTSession, from source: SPTSessionManager) {
    DispatchQueue.main.async {
      guard source === self.manager else { return }
      do {
        try self.save(session)
        SpotifyRemoteBridge.shared.useAccessToken(session.accessToken)
        self.finish(self.payload())
      } catch {
        self.finish(FlutterError(code: "spotify_storage",
          message: "Conectado, mas não foi possível salvar a sessão no iPhone. Tente novamente.", details: nil))
      }
    }
  }
  func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
    accept(session, from: manager)
  }
  func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
    accept(session, from: manager)
  }
  func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
    DispatchQueue.main.async {
      guard manager === self.manager else { return }
      // Do not discard saved credentials on a timeout or temporary network error.
      self.finish(FlutterError(code: "spotify_auth",
        message: "Não foi possível conectar ao Spotify. Verifique a conexão e tente novamente. Se o acesso foi revogado, desconecte e conecte a conta.",
        details: nil))
    }
  }
}
