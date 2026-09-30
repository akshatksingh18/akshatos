package com.akshat.reelvault.ui

import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.akshat.reelvault.data.Video

/**
 * Only pages within +/-1 of the current page get a live ExoPlayer instance
 * (controlled by [isActive] from the caller) - this is what keeps a large
 * library from spinning up dozens of players at once.
 */
@Composable
fun VideoPage(
    video: Video,
    isActive: Boolean,
    isCurrent: Boolean,
    onHeadlineChange: (String) -> Unit
) {
    val context = LocalContext.current
    var isPlaying by remember(video.id) { mutableStateOf(true) }

    val exoPlayer = remember(video.id, isActive) {
        if (isActive) {
            ExoPlayer.Builder(context).build().apply {
                setMediaItem(MediaItem.fromUri(Uri.parse(video.uri)))
                repeatMode = Player.REPEAT_MODE_ONE
                prepare()
            }
        } else {
            null
        }
    }

    DisposableEffect(exoPlayer) {
        onDispose { exoPlayer?.release() }
    }

    LaunchedEffect(isCurrent, isPlaying, exoPlayer) {
        exoPlayer?.playWhenReady = isCurrent && isPlaying
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(video.id) {
                detectTapGestures(onTap = { isPlaying = !isPlaying })
            }
    ) {
        if (exoPlayer != null) {
            AndroidView(
                factory = {
                    PlayerView(context).apply {
                        useController = false
                        player = exoPlayer
                    }
                },
                modifier = Modifier.fillMaxSize()
            )
        }

        HeadlineOverlay(
            headline = video.headline,
            onHeadlineChange = onHeadlineChange,
            modifier = Modifier
                .align(Alignment.TopStart)
                .fillMaxWidth()
                .padding(top = 40.dp, start = 16.dp, end = 56.dp)
        )

        if (isCurrent && !isPlaying) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = "Paused",
                tint = Color.White,
                modifier = Modifier
                    .align(Alignment.Center)
                    .size(64.dp)
            )
        }
    }
}
