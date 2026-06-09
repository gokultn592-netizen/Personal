package com.example.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@Database(
    entities = [
        CapturedCreature::class,
        WishlistCreature::class,
        InventoryTool::class,
        PlayerStats::class,
        CompletedAchievement::class
    ],
    version = 1,
    exportSchema = false
)
abstract class NatureDexDatabase : RoomDatabase() {

    abstract fun natureDexDao(): NatureDexDao

    companion object {
        @Volatile
        private var INSTANCE: NatureDexDatabase? = null

        fun getDatabase(context: Context): NatureDexDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    NatureDexDatabase::class.java,
                    "naturedex_database"
                )
                .addCallback(object : RoomDatabase.Callback() {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        super.onCreate(db)
                        val scope = CoroutineScope(Dispatchers.IO)
                        scope.launch {
                            val dao = INSTANCE?.natureDexDao() ?: return@launch
                            
                            // 1. Initial Player Stats
                            dao.insertPlayerStats(PlayerStats(id = 1, level = 1, experience = 0, totalCatches = 0))
                            
                            // 2. Initial Inventory Tools
                            val starterTools = listOf(
                                InventoryTool("Poke Ball", "Poke Ball", tier = 1, usesRemaining = 20, maxDailyUses = 20, unlockLevel = 1, isUnlocked = true),
                                InventoryTool("Premier Ball", "Premier Ball", tier = 1, usesRemaining = 15, maxDailyUses = 15, unlockLevel = 2, isUnlocked = false),
                                InventoryTool("Great Ball", "Great Ball", tier = 2, usesRemaining = 10, maxDailyUses = 10, unlockLevel = 3, isUnlocked = false),
                                InventoryTool("Quick Ball", "Quick Ball", tier = 2, usesRemaining = 8, maxDailyUses = 8, unlockLevel = 4, isUnlocked = false),
                                InventoryTool("Ultra Ball", "Ultra Ball", tier = 3, usesRemaining = 5, maxDailyUses = 5, unlockLevel = 5, isUnlocked = false),
                                InventoryTool("Beast Ball", "Beast Ball", tier = 3, usesRemaining = 3, maxDailyUses = 3, unlockLevel = 7, isUnlocked = false),
                                InventoryTool("GS Ball", "GS Ball", tier = 4, usesRemaining = 2, maxDailyUses = 2, unlockLevel = 8, isUnlocked = false),
                                InventoryTool("Master Ball", "Master Ball", tier = 4, usesRemaining = 1, maxDailyUses = 1, unlockLevel = 10, isUnlocked = false)
                            )
                            starterTools.forEach { dao.insertTool(it) }
                        }
                    }
                })
                .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
