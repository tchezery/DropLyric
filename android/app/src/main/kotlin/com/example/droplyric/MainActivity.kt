package com.example.droplyric

import com.spotify.android.appremote.api.ContentApi
import com.spotify.protocol.types.ListItem
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
    private val contentItems = mutableMapOf<String, ListItem>()
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
                if (call.method == "initialize") {
                    // Restore only previously authorized connections, without a consent screen.
                    if (getPreferences(MODE_PRIVATE).getBoolean("remote_authorized", false)) {
                        connect(showAuth = false) { _, _ -> result.success(null) }
                    } else result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method == "content" || call.method == "playContent") {
                    connect { appRemote, failure ->
                        if (appRemote == null) {
                            result.error("spotify_connection", connectionError(failure), null)
                        } else {
                            val key = call.arguments as? String ?: ""
                            val item = contentItems[key]
                            if (call.method == "playContent") {
                                if (item == null || !item.playable) result.error("spotify_content", "Atualize a lista do Spotify.", null)
                                else appRemote.contentApi.playContentItem(item)
                                    .setResultCallback { result.success(null) }
                                    .setErrorCallback { result.error("spotify_content", it.message, null) }
                            } else if (key.isNotEmpty() && item == null) {
                                result.error("spotify_content", "Atualize a lista do Spotify.", null)
                            } else {
                                fun fetch(offset: Int, collected: List<ListItem>) {
                                    val request = if (item == null) appRemote.contentApi.getRecommendedContentItems(ContentApi.ContentType.DEFAULT)
                                        else appRemote.contentApi.getChildrenOfItem(item, 50, offset)
                                    request.setResultCallback { page ->
                                        val all = collected + page.items.toList()
                                        if (item != null && page.items.isNotEmpty() && all.size < page.total) fetch(all.size, all)
                                        else result.success(all.map { entry ->
                                            contentItems[entry.id] = entry
                                            mapOf("id" to entry.id, "uri" to entry.uri, "title" to entry.title,
                                                "subtitle" to entry.subtitle, "playable" to entry.playable, "children" to entry.hasChildren)
                                        })
                                    }.setErrorCallback { result.error("spotify_content", it.message, null) }
                                }
                                fetch(0, emptyList())
                            }
                        }
                    }
                    return@setMethodCallHandler
                }
                if (call.method == "connect" || call.method == "reconnect") {
                    // An explicit connection request observes the current player. This
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
                if (call.method !in listOf("play", "pause", "seek", "next", "previous")) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                connect { appRemote, failure ->
                    if (appRemote == null) {
                        result.error("spotify_connection", connectionError(failure), null)
                    } else {
                        val request = when (call.method) {
                            "play" -> if (currentUri == call.arguments) appRemote.playerApi.resume() else appRemote.playerApi.play(call.arguments as String)
                            "next" -> appRemote.playerApi.skipNext()
                            "previous" -> appRemote.playerApi.skipPrevious()
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

    private fun connect(showAuth: Boolean = true, callback: (SpotifyAppRemote?, Throwable?) -> Unit) {
        remote?.takeIf { it.isConnected }?.let { callback(it, null); return }
        pending.add(callback)
        if (pending.size > 1) return
        val params = ConnectionParams.Builder("1bdc621fcaa74a21a2c2f90b5b5f0cbc")
            .setRedirectUri("droplyric://callback").showAuthView(showAuth).build()
        SpotifyAppRemote.connect(this, params, object : Connector.ConnectionListener {
            override fun onConnected(value: SpotifyAppRemote) {
                remote = value
                getPreferences(MODE_PRIVATE).edit().putBoolean("remote_authorized", true).apply()
                subscription?.cancel()
                subscription = value.playerApi.subscribeToPlayerState()
                subscription?.setEventCallback { state ->
                    currentUri = state.track?.uri ?: ""
                    events?.success(mapOf("ready" to true, "uri" to (state.track?.uri ?: ""),
                        "appRemoteAuthorized" to true,
                        "title" to (state.track?.name ?: ""), "artist" to (state.track?.artist?.name ?: ""),
                        "album" to (state.track?.album?.name ?: ""),
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

    private fun disconnect(clearConsent: Boolean = true) {
        if (clearConsent) getPreferences(MODE_PRIVATE).edit().putBoolean("remote_authorized", false).apply()
        currentUri = ""
        contentItems.clear()
        subscription?.cancel(); subscription = null
        remote?.let { SpotifyAppRemote.disconnect(it) }; remote = null
        events?.success(mapOf("ready" to false, "paused" to true, "uri" to "", "position" to 0, "duration" to 0))
    }

    override fun onDestroy() {
        disconnect(clearConsent = false)
        super.onDestroy()
    }
}
