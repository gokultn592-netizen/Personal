package com.example.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface NatureDexDao {

    // --- Captured Creatures ---
    @Query("SELECT * FROM captured_creatures ORDER BY dateCaptured DESC")
    fun getAllCaptured(): Flow<List<CapturedCreature>>

    @Query("SELECT * FROM captured_creatures")
    suspend fun getCapturedListOnce(): List<CapturedCreature>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCaptured(creature: CapturedCreature)

    @Query("SELECT COUNT(*) FROM captured_creatures WHERE speciesId = :speciesId")
    suspend fun isCreatureCaptured(speciesId: Int): Int

    // --- Wishlist ---
    @Query("SELECT * FROM wishlist_creatures")
    fun getWishlist(): Flow<List<WishlistCreature>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertWishlist(creature: WishlistCreature)

    @Delete
    suspend fun deleteWishlist(creature: WishlistCreature)

    @Query("DELETE FROM wishlist_creatures WHERE speciesId = :speciesId")
    suspend fun deleteWishlistById(speciesId: Int)

    @Query("SELECT COUNT(*) FROM wishlist_creatures WHERE speciesId = :speciesId")
    suspend fun isWishlisted(speciesId: Int): Int

    // --- Inventory / Tools ---
    @Query("SELECT * FROM inventory_tools")
    fun getInventoryTools(): Flow<List<InventoryTool>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTool(tool: InventoryTool)

    @Update
    suspend fun updateTool(tool: InventoryTool)

    @Query("DELETE FROM inventory_tools")
    suspend fun clearAllTools()

    @Query("UPDATE inventory_tools SET usesRemaining = maxDailyUses")
    suspend fun resetDailyUses()

    // --- Player Stats ---
    @Query("SELECT * FROM player_stats WHERE id = 1")
    fun getPlayerStats(): Flow<PlayerStats?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlayerStats(stats: PlayerStats)

    // --- Achievements ---
    @Query("SELECT * FROM completed_achievements")
    fun getCompletedAchievements(): Flow<List<CompletedAchievement>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCompletedAchievement(achievement: CompletedAchievement)

    @Query("DELETE FROM captured_creatures")
    suspend fun clearAllCaptured()

    @Query("DELETE FROM completed_achievements")
    suspend fun clearAllAchievements()
}
