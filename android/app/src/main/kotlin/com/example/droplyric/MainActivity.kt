package com.example.droplyric

import com.spotify.android.appremote.api.ConnectionParams
import com.spotify.android.appremote.api.Connector
import com.spotify.android.appremote.api.SpotifyAppRemote
import com.spotify.android.appremote.api.error.*
import com.spotify.protocol.client.Subscription
import com.spotify.protocol.types.PlayerState
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var currentUri = ""
    private var remote: SpotifyAppRemote? = null
    private var subscription: Subscription<PlayerState>? = null
    private var events: EventChannel.EventSink? = null
    private val pending = mutableListOf<(SpotifyAppRemote?, Throwable?) -> Unit>()

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger, "droplyric/spotify/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { events = sink }
                override fun onCancel(arguments: Any?) { events = null }
            })
        MethodChannel(engine.dartExecutor.binaryMessenger, "droplyric/spotify")
            .setMethodCallHandler { call, result ->
                if (call.method == "disconnect") {
                    disconnect()
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method == "initialize" || call.method == "reconnect") {
                    // Connect on app start as well as on explicit reconnect. This
                    // subscribes to the player that Spotify is already playing;
                    // it must not issue play(), which would restart the track.
                    connect { _, failure ->
                        if (failure != null) {
                            result.error("spotify_connection", connectionError(failure), null)
                        } else {
                            result.success(null)
                        }
                    }
                    return@setMethodCallHandler
                }
                if (call.method !in listOf("play", "pause", "seek")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                connect { appRemote, failure ->
                    if (appRemote == null) {
                        result.error("spotify_connection", connectionError(failure), null)
                    } else {
                        val request = when (call.method) {
                            "play" -> if (currentUri == call.arguments) appRemote.playerApi.resume() else appRemote.playerApi.play(call.arguments as String)
                            "pause" -> appRemote.playerApi.pause()
                            else -> appRemote.playerApi.seekTo((call.arguments as String).toLong())
                        }
                        request.setResultCallback { result.success(null) }
                            .setErrorCallback { result.error("spotify_playback", it.message, null) }
                    }
                }
            }
    }

    private fun connectionError(error: Throwable?): String {
        val description = when (error) {
            is CouldNotFindSpotifyApp -> "Instale o aplicativo oficial do Spotify neste Android e entre na sua conta antes de tocar. O login no navegador não instala o player."
            is NotLoggedInException -> "Abra o aplicativo Spotify neste Android e entre com a mesma conta usada no Droplyric."
            is UserNotAuthorizedException -> "Autorize o Droplyric a controlar o Spotify quando a tela de permissão aparecer. Depois tente tocar novamente."
            is AuthenticationFailedException -> "O Spotify recusou a identificação do aplicativo. Confira o pacote com.example.droplyric e o SHA-1 do APK no painel Spotify Developers."
            is OfflineModeException -> "Desative o modo offline no aplicativo Spotify e conecte o Android à internet."
            is UnsupportedFeatureVersionException -> "Atualize o aplicativo oficial do Spotify neste Android para usar a reprodução."
            is SpotifyRemoteServiceException -> "O Android não conseguiu acessar o serviço do Spotify. Abra o Spotify e retorne ao Droplyric para tentar novamente."
            else -> "Não foi possível conectar ao player Spotify. Abra o aplicativo Spotify e tente novamente."
        }
        // Keep a stable diagnostic even when the SDK provides no message.
        return "$description [${error?.javaClass?.simpleName ?: "UnknownConnectionError"}]"
    }

    private fun connect(callback: (SpotifyAppRemote?, Throwable?) -> Unit) {
        remote?.takeIf { it.isConnected }?.let { callback(it, null); return }
        pending.add(callback)
        if (pending.size > 1) return
        val params = ConnectionParams.Builder("1bdc621fcaa74a21a2c2f90b5b5f0cbc")
            .setRedirectUri("droplyric://callback").showAuthView(true).build()
        SpotifyAppRemote.connect(this, params, object : Connector.ConnectionListener {
            override fun onConnected(value: SpotifyAppRemote) {
                remote = value
                subscription?.cancel()
                subscription = value.playerApi.subscribeToPlayerState()
                subscription?.setEventCallback { state ->
                    currentUri = state.track?.uri ?: ""
                    events?.success(mapOf("ready" to true, "uri" to (state.track?.uri ?: ""),
                        "paused" to state.isPaused, "position" to state.playbackPosition,
                        "duration" to (state.track?.duration ?: 0L), "error" to ""))
                }
                subscription?.setErrorCallback {
                    events?.success(mapOf("ready" to false, "paused" to true, "error" to (it.message ?: "Falha no Spotify.")))
                }
                val callbacks = pending.toList(); pending.clear()
                callbacks.forEach { it(value, null) }
            }
            override fun onFailure(error: Throwable) {
                val callbacks = pending.toList(); pending.clear()
                callbacks.forEach { it(null, error) }
            }
        })
    }

    private fun disconnect() {
        currentUri = ""
        subscription?.cancel(); subscription = null
        remote?.let { SpotifyAppRemote.disconnect(it) }; remote = null
        events?.success(mapOf("ready" to false, "paused" to true, "uri" to "", "position" to 0, "duration" to 0))
    }

    override fun onDestroy() {
        disconnect()
        super.onDestroy()
    }
}
