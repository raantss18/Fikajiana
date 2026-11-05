package mg.fikajiana.app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pour l'écran d'essai : raconte les derniers arrêts de l'app, rien ne quitte l'appareil.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fikajiana/essai")
            .setMethodCallHandler { appel, resultat ->
                if (appel.method == "derniersArrets") resultat.success(derniersArrets()) else resultat.notImplemented()
            }
    }

    private fun derniersArrets(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        val gestionnaire = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return gestionnaire.getHistoricalProcessExitReasons(packageName, 0, 3).map {
            "raison ${it.reason}, signal ${it.status}, ${it.description ?: "sans description"}"
        }
    }
}
