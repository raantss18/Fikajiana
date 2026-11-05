package mg.fikajiana.app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var evenementsStylet = 0
    private var pointsStylet = 0

    // Pour le spike : ce qu'Android livre, historique compris, à comparer à ce que Flutter reçoit.
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.getToolType(0) == MotionEvent.TOOL_TYPE_STYLUS) {
            evenementsStylet++
            pointsStylet += event.historySize + 1
        }
        return super.dispatchTouchEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pour l'écran d'essai : raconte les derniers arrêts de l'app, rien ne quitte l'appareil.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fikajiana/essai")
            .setMethodCallHandler { appel, resultat ->
                when (appel.method) {
                    "derniersArrets" -> resultat.success(derniersArrets())
                    "compteursStylet" -> resultat.success(mapOf("evenements" to evenementsStylet, "points" to pointsStylet))
                    "remettreCompteursStylet" -> {
                        evenementsStylet = 0
                        pointsStylet = 0
                        resultat.success(null)
                    }
                    else -> resultat.notImplemented()
                }
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
