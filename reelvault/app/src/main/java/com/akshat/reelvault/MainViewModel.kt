package com.akshat.reelvault

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.akshat.reelvault.data.AppDatabase
import com.akshat.reelvault.data.Video
import com.akshat.reelvault.shuffle.ShuffleBag
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private val dao = AppDatabase.getInstance(application).videoDao()
    private val shuffleBag = ShuffleBag(emptyList())

    /** Everything in the library - used by the Library/manage screen. */
    private val _allVideos = MutableStateFlow<List<Video>>(emptyList())
    val allVideos: StateFlow<List<Video>> = _allVideos.asStateFlow()

    /** The materialized, already-shuffled queue the reel pager scrolls through. */
    private val _playOrder = MutableStateFlow<List<Video>>(emptyList())
    val playOrder: StateFlow<List<Video>> = _playOrder.asStateFlow()

    private val bufferAhead = 6

    init {
        viewModelScope.launch {
            dao.getAll().collect { videos ->
                _allVideos.value = videos
                shuffleBag.updateVideos(videos)
                if (videos.isEmpty()) {
                    _playOrder.value = emptyList()
                } else {
                    ensureBuffer(minSize = bufferAhead)
                }
            }
        }
    }

    /** Tops up the play order queue from the shuffle bag until it reaches minSize. */
    private fun ensureBuffer(minSize: Int) {
        val current = _playOrder.value.toMutableList()
        while (current.size < minSize) {
            val next = shuffleBag.next() ?: break
            current.add(next)
        }
        if (current.size != _playOrder.value.size) {
            _playOrder.value = current
        }
    }

    /** Call when the pager settles on a page, so we can keep the queue topped up. */
    fun onPageSettled(index: Int) {
        if (_playOrder.value.size - index <= bufferAhead) {
            ensureBuffer(minSize = index + bufferAhead + 1)
        }
    }

    fun updateHeadline(video: Video, newHeadline: String) {
        if (newHeadline == video.headline) return
        viewModelScope.launch {
            dao.updateHeadline(video.id, newHeadline)
        }
    }

    /**
     * Persists read access to each picked video URI beyond this session,
     * then stores it. Without takePersistableUriPermission, the URI would
     * stop being playable the next time the app is opened.
     */
    fun addVideos(uris: List<Uri>) {
        val context = getApplication<Application>()
        viewModelScope.launch {
            for (uri in uris) {
                try {
                    context.contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                } catch (_: SecurityException) {
                    // Some providers don't support persistable grants; the
                    // video just won't survive an app restart. Not fatal.
                }
                if (dao.countByUri(uri.toString()) == 0) {
                    dao.insert(Video(uri = uri.toString()))
                }
            }
        }
    }

    fun removeVideo(video: Video) {
        viewModelScope.launch {
            dao.delete(video)
            _playOrder.value = _playOrder.value.filter { it.id != video.id }
        }
    }
}
