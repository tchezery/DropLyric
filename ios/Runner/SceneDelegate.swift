import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    forwardLinks(connectionOptions.urlContexts)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    forwardLinks(URLContexts)
  }

  private func forwardLinks(_ contexts: Set<UIOpenURLContext>) {
    // app_links 6.x only registers UIApplicationDelegate callbacks. With the
    // scene lifecycle, Safari delivers the Spotify callback here instead.
    for context in contexts {
      if SpotifyAuthBridge.shared.handleCallback(context.url) { continue }
      if SpotifyRemoteBridge.shared.handleCallback(context.url) { continue }
      AppLinks.shared.handleLink(url: context.url)
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    SpotifyAuthBridge.shared.becomeActive()
    SpotifyRemoteBridge.shared.becomeActive()
  }

  override func sceneWillResignActive(_ scene: UIScene) {
    SpotifyRemoteBridge.shared.resignActive()
    super.sceneWillResignActive(scene)
  }
}
