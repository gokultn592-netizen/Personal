package com.example.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "captured_creatures")
data class CapturedCreature(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val speciesId: Int,
    val name: String,
    val scientificName: String,
    val category: String, // Animals, Birds, Fish, Insects, Reptiles, Plants
    val imageUrl: String,
    val rarity: String, // Common, Uncommon, Rare, Legendary
    val threatLevel: String, // None, Low, Medium, High, Deadly
    val dateCaptured: Long,
    val latitude: Double,
    val longitude: Double,
    val capturedWithTool: String,
    val isSample: Boolean = false
)

@Entity(tableName = "wishlist_creatures")
data class WishlistCreature(
    @PrimaryKey val speciesId: Int,
    val name: String,
    val scientificName: String,
    val category: String,
    val imageUrl: String,
    val rarity: String,
    val threatLevel: String
)

@Entity(tableName = "inventory_tools")
data class InventoryTool(
    @PrimaryKey val toolName: String, // "Net", "Lasso", "Tranq Dart", "Fishing Net", "Glass Jar", "Cage Trap", "Hook"
    val displayName: String,
    val tier: Int, // 1 = Basic, 2 = Reinforced, 3 = Carbon
    val usesRemaining: Int,
    val maxDailyUses: Int,
    val unlockLevel: Int,
    val isUnlocked: Boolean
)

@Entity(tableName = "player_stats")
data class PlayerStats(
    @PrimaryKey val id: Int = 1,
    val level: Int = 1,
    val experience: Int = 0,
    val totalCatches: Int = 0
)

@Entity(tableName = "completed_achievements")
data class CompletedAchievement(
    @PrimaryKey val achievementId: String,
    val title: String,
    val description: String,
    val unlockedAt: Long
)
