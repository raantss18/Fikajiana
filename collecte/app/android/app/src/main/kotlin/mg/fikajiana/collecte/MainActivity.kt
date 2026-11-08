package mg.fikajiana.collecte

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fikajiana_collecte/systeme")
            .setMethodCallHandler { appel, resultat ->
                when (appel.method) {
                    // Où garder l'état (interne) et les séances (lisibles par `adb pull`).
                    "infos" -> resultat.success(
                        mapOf(
                            "modele" to Build.MODEL,
                            "interne" to filesDir.absolutePath,
                            "export" to (getExternalFilesDir(null) ?: filesDir).absolutePath,
                        ),
                    )
                    // Le partage Android, fichier par fichier, sans réseau ni permission.
                    "partager" -> {
                        val uris = ArrayList<Uri>(
                            appel.argument<List<String>>("chemins")!!.map {
                                FileProvider.getUriForFile(this, "$packageName.export", File(it))
                            },
                        )
                        val envoi = if (uris.size == 1) {
                            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
                        } else {
                            Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                        }
                        envoi.type = "application/json"
                        envoi.clipData = ClipData.newUri(contentResolver, "séance", uris[0]).apply {
                            uris.drop(1).forEach { addItem(ClipData.Item(it)) }
                        }
                        envoi.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(Intent.createChooser(envoi, "Envoyer l'écriture"))
                        resultat.success(true)
                    }
                    else -> resultat.notImplemented()
                }
            }
    }
}
