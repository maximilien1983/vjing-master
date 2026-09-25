package fr.vjm.vjing_master

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var castHandler: CastHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fr.vjm/cast")
        castHandler = CastHandler(this, channel)
        channel.setMethodCallHandler { call, result -> castHandler!!.handle(call, result) }
    }

    override fun onDestroy() {
        castHandler?.release()
        castHandler = null
        super.onDestroy()
    }
}
