package com.akshat.reelvault.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.akshat.reelvault.MainViewModel
import com.akshat.reelvault.data.Video

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(viewModel: MainViewModel, onBack: () -> Unit) {
    val videos by viewModel.allVideos.collectAsState()

    val pickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenMultipleDocuments()
    ) { uris -> if (uris.isNotEmpty()) viewModel.addVideos(uris) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Your videos (${videos.size})") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back to reel")
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { pickerLauncher.launch(arrayOf("video/*")) }) {
                Text("+", modifier = Modifier.padding(4.dp))
            }
        }
    ) { padding ->
        LazyColumn(modifier = Modifier.padding(padding).fillMaxSize()) {
            items(videos, key = { it.id }) { video ->
                VideoRow(
                    video = video,
                    onHeadlineChange = { viewModel.updateHeadline(video, it) },
                    onDelete = { viewModel.removeVideo(video) }
                )
            }
        }
    }
}

@Composable
private fun VideoRow(video: Video, onHeadlineChange: (String) -> Unit, onDelete: () -> Unit) {
    var text by remember(video.headline) { mutableStateOf(video.headline) }
    val dirty = text != video.headline

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
    ) {
        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            label = { Text("Headline") },
            singleLine = true,
            modifier = Modifier.weight(1f)
        )
        if (dirty) {
            TextButton(onClick = { onHeadlineChange(text) }) { Text("Save") }
        }
        IconButton(onClick = onDelete) {
            Icon(Icons.Default.Delete, contentDescription = "Remove video")
        }
    }
}
