package com.akshat.reelvault.shuffle

import com.akshat.reelvault.data.Video

/**
 * Fisher-Yates "shuffle bag".
 *
 * Guarantees:
 *  1. Every video in the set plays exactly once before any video repeats
 *     (fair frequency - fixes the "same video keeps popping up" problem
 *     you get with naive Random.nextInt() picks every turn).
 *  2. No back-to-back repeat across the boundary where one shuffled
 *     cycle ends and the next one begins.
 *
 * Not thread-safe by design - it's meant to be driven from a single
 * coroutine scope (the ViewModel's viewModelScope), same as the rest
 * of this app's state.
 */
class ShuffleBag(initialVideos: List<Video>) {

    private var videos: List<Video> = initialVideos
    private var queue: MutableList<Video> = mutableListOf()
    private var lastPlayed: Video? = null

    init {
        refill()
    }

    /**
     * Call this whenever the underlying video set changes (added/removed).
     * Videos already queued but since removed are dropped; if that empties
     * the queue and videos remain, it's refilled immediately.
     */
    fun updateVideos(newVideos: List<Video>) {
        videos = newVideos
        val validIds = newVideos.map { it.id }.toSet()
        queue = queue.filter { it.id in validIds }.toMutableList()
        if (queue.isEmpty() && videos.isNotEmpty()) {
            refill()
        }
    }

    /** Returns the next video in shuffle order, or null if there are none. */
    fun next(): Video? {
        if (videos.isEmpty()) return null
        if (queue.isEmpty()) refill()
        if (queue.isEmpty()) return null // still empty after refill attempt
        val nextVideo = queue.removeAt(0)
        lastPlayed = nextVideo
        return nextVideo
    }

    private fun refill() {
        if (videos.isEmpty()) {
            queue = mutableListOf()
            return
        }
        val shuffled = videos.shuffled().toMutableList()

        // Avoid the boundary case: last video of the old cycle immediately
        // repeating as the first video of the new cycle.
        if (videos.size > 1 && shuffled.first().id == lastPlayed?.id) {
            val swapIndex = (1 until shuffled.size).random()
            val tmp = shuffled[0]
            shuffled[0] = shuffled[swapIndex]
            shuffled[swapIndex] = tmp
        }

        queue = shuffled
    }
}
