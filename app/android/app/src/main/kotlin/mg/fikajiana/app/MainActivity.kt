package mg.fikajiana.app

import android.app.ActivityManager
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.MotionEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var evenementsStylet = 0
    private var pointsStylet = 0
    private var aEnregistrer: ByteArray? = null
    private var reponseEnregistrer: MethodChannel.Result? = null

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
        // Version installée et installateur d'Android pour les mises à jour (ADR 0015).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fikajiana/systeme")
            .setMethodCallHandler { appel, resultat ->
                val info = packageManager.getPackageInfo(packageName, 0)
                when (appel.method) {
                    "build" -> resultat.success(
                        if (Build.VERSION.SDK_INT >= 28) info.longVersionCode.toInt()
                        else @Suppress("DEPRECATION") info.versionCode,
                    )
                    "version" -> resultat.success(info.versionName)
                    // Pour l'export des corrections au format de collecte (ADR 0039).
                    "modele" -> resultat.success(Build.MODEL)
                    // Les dons consentis partent sur le Wi-Fi seulement, par défaut (ADR 0042).
                    "reseau" -> {
                        val gestion = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val capacites = gestion.getNetworkCapabilities(gestion.activeNetwork)
                        resultat.success(
                            mapOf(
                                "connecte" to (capacites?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true),
                                "nonFacture" to (capacites?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == true),
                            ),
                        )
                    }
                    // L'écriture exportée (ADR 0042) : un dossier que `adb pull` lit, sans permission.
                    "dossierEcritures" -> resultat.success(
                        File(getExternalFilesDir(null) ?: filesDir, "ecritures").absolutePath,
                    )
                    // Le partage Android des fichiers exportés ; rien ne part sans le choix de la personne.
                    "partager" -> {
                        val uris = ArrayList<Uri>(
                            appel.argument<List<String>>("chemins")!!.map {
                                FileProvider.getUriForFile(this, "$packageName.updates", File(it))
                            },
                        )
                        val envoi = if (uris.size == 1) {
                            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
                        } else {
                            Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                        }
                        envoi.type = "application/json"
                        envoi.clipData = ClipData.newUri(contentResolver, "écriture", uris[0]).apply {
                            uris.drop(1).forEach { addItem(ClipData.Item(it)) }
                        }
                        envoi.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(Intent.createChooser(envoi, null))
                        resultat.success(true)
                    }
                    "installer" -> {
                        // Sans l'autorisation, on ouvre le réglage : l'utilisateur l'accorde puis recommence.
                        if (!packageManager.canRequestPackageInstalls()) {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                            resultat.success(false)
                        } else {
                            val fichier = File(appel.argument<String>("chemin")!!)
                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", fichier)
                            @Suppress("DEPRECATION")
                            startActivity(Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                            })
                            resultat.success(true)
                        }
                    }
                    // Android demande où mettre le fichier : aucune autorisation (ADR 0022).
                    "enregistrer" -> {
                        aEnregistrer = appel.argument<ByteArray>("octets")
                        reponseEnregistrer = resultat
                        @Suppress("DEPRECATION")
                        startActivityForResult(
                            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = appel.argument<String>("type")
                                putExtra(Intent.EXTRA_TITLE, appel.argument<String>("nom"))
                            },
                            CODE_ENREGISTRER,
                        )
                    }
                    else -> resultat.notImplemented()
                }
            }
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

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != CODE_ENREGISTRER) return
        val octets = aEnregistrer
        val reponse = reponseEnregistrer
        aEnregistrer = null
        reponseEnregistrer = null
        val destination = data?.data
        if (resultCode != RESULT_OK || destination == null || octets == null) {
            reponse?.success(false)
            return
        }
        // Hors du fil principal : un fournisseur de documents peut être lent.
        Thread {
            val erreur = try {
                contentResolver.openOutputStream(destination)!!.use { it.write(octets) }
                null
            } catch (e: Exception) {
                e.message ?: "écriture impossible"
            }
            runOnUiThread {
                if (erreur == null) reponse?.success(true)
                else reponse?.error("enregistrer", erreur, null)
            }
        }.start()
    }

    private fun derniersArrets(): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
        val gestionnaire = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return gestionnaire.getHistoricalProcessExitReasons(packageName, 0, 3).map {
            "raison ${it.reason}, signal ${it.status}, ${it.description ?: "sans description"}"
        }
    }

    private companion object {
        const val CODE_ENREGISTRER = 4242
    }
}
