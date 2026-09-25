package fr.vjm.vjing_master

import android.content.Context
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import com.google.android.gms.cast.CastMediaControlIntent
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import com.google.android.gms.cast.framework.SessionManagerListener
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Découverte des Chromecast (MediaRouter) et session Cast avec messages sur
 * le namespace custom. Piloté par Flutter via le channel `fr.vjm/cast` :
 *  - startDiscovery / stopDiscovery
 *  - connect(routeId) / disconnect
 *  - sendMessage(json)
 * Remontées : onRoutes(list), onSessionState(idle|connecting|connected), onMessage(json).
 */
class CastHandler(context: Context, private val channel: MethodChannel) {
    companion object {
        const val NAMESPACE = "urn:x-cast:fr.vjm.control"
    }

    private val appContext = context.applicationContext
    private val router = MediaRouter.getInstance(appContext)
    private val appId = appContext.getString(R.string.cast_app_id)
    private val selector = MediaRouteSelector.Builder()
        .addControlCategory(CastMediaControlIntent.categoryForCast(appId))
        .build()

    private val castContext: CastContext? = try {
        CastContext.getSharedInstance(appContext)
    } catch (e: Exception) {
        // Google Play services absent ou trop ancien : pas de Cast.
        null
    }

    private var castSession: CastSession? = null
    private var discovering = false

    private val routerCallback = object : MediaRouter.Callback() {
        override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) = pushRoutes()
        override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) = pushRoutes()
        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) = pushRoutes()
    }

    private val sessionListener = object : SessionManagerListener<CastSession> {
        override fun onSessionStarting(session: CastSession) = pushState("connecting")
        override fun onSessionStarted(session: CastSession, sessionId: String) = attach(session)
        override fun onSessionStartFailed(session: CastSession, error: Int) = pushState("idle")
        override fun onSessionResuming(session: CastSession, sessionId: String) = pushState("connecting")
        override fun onSessionResumed(session: CastSession, wasSuspended: Boolean) = attach(session)
        override fun onSessionResumeFailed(session: CastSession, error: Int) = pushState("idle")
        override fun onSessionSuspended(session: CastSession, reason: Int) = pushState("connecting")
        override fun onSessionEnding(session: CastSession) {}
        override fun onSessionEnded(session: CastSession, error: Int) {
            castSession = null
            pushState("idle")
        }
    }

    init {
        castContext?.sessionManager?.addSessionManagerListener(sessionListener, CastSession::class.java)
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDiscovery" -> {
                if (!discovering) {
                    discovering = true
                    router.addCallback(
                        selector, routerCallback,
                        MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY or
                            MediaRouter.CALLBACK_FLAG_PERFORM_ACTIVE_SCAN
                    )
                }
                pushRoutes()
                result.success(null)
            }
            "stopDiscovery" -> {
                if (discovering) {
                    discovering = false
                    router.removeCallback(routerCallback)
                }
                result.success(null)
            }
            "connect" -> {
                val routeId = call.argument<String>("routeId")
                val route = router.routes.firstOrNull { it.id == routeId }
                if (route == null) {
                    result.error("no_route", "TV introuvable : $routeId", null)
                } else {
                    pushState("connecting")
                    route.select()
                    result.success(null)
                }
            }
            "disconnect" -> {
                castContext?.sessionManager?.endCurrentSession(true)
                result.success(null)
            }
            "sendMessage" -> {
                val json = call.argument<String>("json")
                val session = castSession
                if (session == null || json == null) {
                    result.error("not_connected", "Pas de session Cast", null)
                } else {
                    session.sendMessage(NAMESPACE, json)
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun attach(session: CastSession) {
        castSession = session
        session.setMessageReceivedCallbacks(NAMESPACE) { _, _, message ->
            channel.invokeMethod("onMessage", message)
        }
        pushState("connected")
    }

    private fun pushRoutes() {
        val routes = router.routes
            .filter { it.matchesSelector(selector) && !it.isDefault }
            .map { mapOf("id" to it.id, "name" to it.name) }
        channel.invokeMethod("onRoutes", routes)
    }

    private fun pushState(state: String) {
        channel.invokeMethod("onSessionState", state)
    }

    fun release() {
        if (discovering) router.removeCallback(routerCallback)
        castContext?.sessionManager?.removeSessionManagerListener(sessionListener, CastSession::class.java)
    }
}
