package com.akshat.reelvault

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.akshat.reelvault.ui.LibraryScreen
import com.akshat.reelvault.ui.ReelScreen

class MainActivity : ComponentActivity() {

    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    var showLibrary by remember { mutableStateOf(false) }
                    if (showLibrary) {
                        LibraryScreen(viewModel = viewModel, onBack = { showLibrary = false })
                    } else {
                        ReelScreen(viewModel = viewModel, onOpenLibrary = { showLibrary = true })
                    }
                }
            }
        }
    }
}
