package com.akshat.reelvault.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.akshat.reelvault.MainViewModel
import kotlinx.coroutines.flow.distinctUntilChanged

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ReelScreen(viewModel: MainViewModel, onOpenLibrary: () -> Unit) {
    val playOrder by viewModel.playOrder.collectAsState()

    if (playOrder.isEmpty()) {
        EmptyState(onOpenLibrary)
        return
    }

    val pagerState = rememberPagerState(pageCount = { playOrder.size })

    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }
            .distinctUntilChanged()
            .collect { page -> viewModel.onPageSettled(page) }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        VerticalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            val video = playOrder[page]
            val currentPage = pagerState.currentPage
            val isActive = page == currentPage || page == currentPage - 1 || page == currentPage + 1

            VideoPage(
                video = video,
                isActive = isActive,
                isCurrent = page == currentPage,
                onHeadlineChange = { newHeadline -> viewModel.updateHeadline(video, newHeadline) }
            )
        }

        IconButton(
            onClick = onOpenLibrary,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 40.dp, end = 12.dp)
        ) {
            Icon(Icons.Default.VideoLibrary, contentDescription = "Manage videos", tint = Color.White)
        }
    }
}

@Composable
private fun EmptyState(onOpenLibrary: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("No videos yet")
            Spacer(modifier = Modifier.height(12.dp))
            Button(onClick = onOpenLibrary) { Text("Add videos") }
        }
    }
}
