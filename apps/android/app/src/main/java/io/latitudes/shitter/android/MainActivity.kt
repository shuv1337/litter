package io.latitudes.shitter.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import io.latitudes.shitter.android.state.ServerManager
import io.latitudes.shitter.android.ui.ShitterAppShell
import io.latitudes.shitter.android.ui.ShitterAppTheme
import io.latitudes.shitter.android.ui.rememberShitterAppState

class MainActivity : ComponentActivity() {
    private lateinit var serverManager: ServerManager

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        // disable system window fitting so compose can handle keyboard padding natively
        WindowCompat.setDecorFitsSystemWindows(window, false)

        serverManager = ServerManager(context = this)

        setContent {
            ShitterAppTheme {
                val appState = rememberShitterAppState(serverManager = serverManager)
                ShitterAppShell(appState = appState)
            }
        }
    }

    override fun onDestroy() {
        if (::serverManager.isInitialized) {
            serverManager.close()
        }
        super.onDestroy()
    }
}
