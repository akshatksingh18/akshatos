package com.akshat.reelvault.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface VideoDao {

    @Query("SELECT * FROM videos ORDER BY dateAdded DESC")
    fun getAll(): Flow<List<Video>>

    @Insert
    suspend fun insert(video: Video): Long

    @Delete
    suspend fun delete(video: Video)

    @Query("UPDATE videos SET headline = :headline WHERE id = :id")
    suspend fun updateHeadline(id: Long, headline: String)

    @Query("SELECT COUNT(*) FROM videos WHERE uri = :uri")
    suspend fun countByUri(uri: String): Int
}
