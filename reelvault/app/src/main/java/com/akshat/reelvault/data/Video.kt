package com.akshat.reelvault.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "videos")
data class Video(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val uri: String,
    val headline: String = "",
    val dateAdded: Long = System.currentTimeMillis()
)
