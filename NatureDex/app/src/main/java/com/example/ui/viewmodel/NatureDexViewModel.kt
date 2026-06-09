package com.example.ui.viewmodel

import android.app.Application
import android.content.Context
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import com.example.NavTab
import com.example.ui.screens.LeaderboardEntry
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.firestore.Query
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import android.location.Location
import android.location.LocationManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.util.*

@OptIn(FlowPreview::class)
class NatureDexViewModel(application: Application) : AndroidViewModel(application) {

    private val repository: NatureDexRepository
    private val prefs = run {
        val masterKey = MasterKey.Builder(application)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        val securePrefs = EncryptedSharedPreferences.create(
            application,
            "naturedex_prefs_secure",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
        val oldPrefs = application.getSharedPreferences("naturedex_prefs", Context.MODE_PRIVATE)
        if (oldPrefs.all.isNotEmpty()) {
            val editor = securePrefs.edit()
            oldPrefs.all.forEach { (key, value) ->
                when (value) {
                    is String -> editor.putString(key, value)
                    is Boolean -> editor.putBoolean(key, value)
                    is Int -> editor.putInt(key, value)
                    is Long -> editor.putLong(key, value)
                    is Float -> editor.putFloat(key, value)
                }
            }
            editor.apply()
            oldPrefs.edit().clear().apply()
        }
        securePrefs
    }

    // --- Google Auth Real ---
    private val _isGoogleSignedIn = MutableStateFlow(false)
    val isGoogleSignedIn: StateFlow<Boolean> = _isGoogleSignedIn.asStateFlow()

    // --- Explorer Name ---
    private val _explorerName = MutableStateFlow(prefs.getString("explorer_name", "Gokul") ?: "Gokul")
    val explorerName: StateFlow<String> = _explorerName.asStateFlow()

    // --- User Role & Dev Mode ---
    private val _userRole = MutableStateFlow(prefs.getString("user_role", "catcher") ?: "catcher")
    val userRole: StateFlow<String> = _userRole.asStateFlow()

    private val _isDeveloperMode = MutableStateFlow(prefs.getBoolean("developer_mode", false))
    val isDeveloperMode: StateFlow<Boolean> = _isDeveloperMode.asStateFlow()

    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var activeLocationCallback: com.google.android.gms.location.LocationCallback? = null
    private var activeNativeListener: android.location.LocationListener? = null
    private val _currentLocation = MutableStateFlow<Location?>(null)
    val currentLocation: StateFlow<Location?> = _currentLocation.asStateFlow()

    // --- AR Mode Toggle setting ---
    private val _isArEnabled = MutableStateFlow(prefs.getBoolean("ar_enabled", true))
    val isArEnabled: StateFlow<Boolean> = _isArEnabled.asStateFlow()

    // --- Biometric Lock setting ---
    private val _isBiometricLockEnabled = MutableStateFlow(prefs.getBoolean("biometric_lock_enabled", false))
    val isBiometricLockEnabled: StateFlow<Boolean> = _isBiometricLockEnabled.asStateFlow()

    // --- Weather & Environmental Modifiers ---
    private val _currentEnvironmentalWeather = MutableStateFlow("Sunny")
    val currentEnvironmentalWeather: StateFlow<String> = _currentEnvironmentalWeather.asStateFlow()

    // --- Daily Bounties System ---
    private val _dailyBounties = MutableStateFlow<List<DailyBounty>>(emptyList())
    val dailyBounties: StateFlow<List<DailyBounty>> = _dailyBounties.asStateFlow()

    init {
        val dao = NatureDexDatabase.getDatabase(application).natureDexDao()
        repository = NatureDexRepository(dao)
        checkAndResetDailyUses(application)
        com.example.ui.audio.SoundEffectsManager.isMuted = prefs.getBoolean("sound_muted", false)
        try {
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(application)
        } catch (e: Exception) {
            Log.e("NatureDex", "Failed to initialize location client: ${e.message}")
        }

        // Listen to Firebase Auth state
        try {
            val auth = FirebaseAuth.getInstance()
            _isGoogleSignedIn.value = auth.currentUser != null
            auth.addAuthStateListener { firebaseAuth ->
                val user = firebaseAuth.currentUser
                val signedIn = user != null
                _isGoogleSignedIn.value = signedIn
                if (signedIn) {
                    val name = user.displayName ?: user.email?.substringBefore("@") ?: prefs.getString("explorer_name", "Gokul") ?: "Gokul"
                    // Temporarily set it locally, then sync
                    _explorerName.value = name
                    prefs.edit().putString("explorer_name", name).apply()
                    restoreAllUserDataFromFirestore()
                    fetchFirestoreLeaderboard()
                } else {
                    _userRole.value = "catcher"
                    _isDeveloperMode.value = false
                    prefs.edit().putString("user_role", "catcher").putBoolean("developer_mode", false).apply()
                }
            }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firebase Auth initialization failed: ${e.message}")
        }
        initDailyBounties()
        initWeather()
    }

    private fun checkAndResetDailyUses(context: Context) {
        val lastReset = prefs.getLong("last_daily_reset", 0L)
        val now = System.currentTimeMillis()
        val oneDayMs = 24 * 60 * 60 * 1000L
        if (now - lastReset >= oneDayMs) {
            viewModelScope.launch {
                repository.resetDailyUses()
                prefs.edit().putLong("last_daily_reset", now).apply()
                Log.d("NatureDex", "Daily tool uses reset")
            }
        }
    }

    private var searchJob: kotlinx.coroutines.Job? = null
    private val captureMutex = Mutex()

    // --- UI Navigation ---
    private val _currentTab = MutableStateFlow<NavTab>(NavTab.Index)
    val currentTab: StateFlow<NavTab> = _currentTab.asStateFlow()

    fun selectTab(tab: NavTab) {
        _currentTab.value = tab
    }



    fun setGoogleSignedIn(signedIn: Boolean) {
        try {
            if (!signedIn) {
                FirebaseAuth.getInstance().signOut()
                _isGoogleSignedIn.value = false
            } else {
                _isGoogleSignedIn.value = true
            }
        } catch (e: Exception) {
            _isGoogleSignedIn.value = signedIn
        }
    }

    fun setDeveloperMode(enabled: Boolean) {
        _isDeveloperMode.value = enabled
        prefs.edit().putBoolean("developer_mode", enabled).apply()
    }

    fun refreshUserProfile() {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            db.collection("users").document(currentUser.uid)
                .get()
                .addOnSuccessListener { doc ->
                    if (doc.exists()) {
                        val role = doc.getString("role") ?: "catcher"
                        _userRole.value = role
                        prefs.edit().putString("user_role", role).apply()
                    }
                }
        } catch (e: Exception) {
            Log.e("NatureDex", "Failed to refresh user profile: ${e.message}")
        }
    }

    fun signInWithFirebaseCredential(
        credential: com.google.firebase.auth.AuthCredential,
        onSuccess: () -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        try {
            FirebaseAuth.getInstance().signInWithCredential(credential)
                .addOnCompleteListener { task ->
                    if (task.isSuccessful) {
                        onSuccess()
                        restoreAllUserDataFromFirestore()
                        fetchFirestoreLeaderboard()
                    } else {
                        onFailure(task.exception ?: Exception("Authentication failed"))
                    }
                }
        } catch (e: Exception) {
            onFailure(e)
        }
    }

    // --- Online Leaderboard ---
    private val _onlineLeaderboard = MutableStateFlow<List<LeaderboardEntry>>(emptyList())
    val onlineLeaderboard: StateFlow<List<LeaderboardEntry>> = _onlineLeaderboard.asStateFlow()

    fun fetchFirestoreLeaderboard() {
        try {
            val db = FirebaseFirestore.getInstance()
            db.collection("leaderboards")
                .orderBy("catches", Query.Direction.DESCENDING)
                .limit(20)
                .get()
                .addOnSuccessListener { result ->
                    val entries = result.documents.mapNotNull { doc ->
                        val name = doc.getString("name") ?: "Explorer"
                        val level = doc.getLong("level")?.toInt() ?: 1
                        val catches = doc.getLong("catches")?.toInt() ?: 0
                        val isUser = doc.id == FirebaseAuth.getInstance().currentUser?.uid
                        LeaderboardEntry(name, level, catches, isUser)
                    }
                    _onlineLeaderboard.value = entries
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Failed to retrieve leaderboard from Firestore", e)
                }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firestore is not initialized: ${e.message}")
        }
    }

    fun syncPlayerStatsToFirestore(
        customStats: PlayerStats? = null,
        customCatchesCount: Int? = null
    ) {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            val stats = customStats ?: playerStats.value
            val catchesCount = customCatchesCount ?: capturedList.value.size

            val data = hashMapOf(
                "name" to explorerName.value,
                "level" to stats.level,
                "catches" to catchesCount,
                "updatedAt" to System.currentTimeMillis()
            )

            db.collection("leaderboards").document(currentUser.uid)
                .set(data, SetOptions.merge())
                .addOnSuccessListener {
                    Log.d("NatureDex", "Leaderboard stats synced to Firestore.")
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Leaderboard sync failed", e)
                }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firestore sync failed: ${e.message}")
        }
    }

    fun syncUserProfileToFirestore(
        customStats: PlayerStats? = null,
        customCatchesCount: Int? = null
    ) {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            val stats = customStats ?: playerStats.value
            val catchesCount = customCatchesCount ?: capturedList.value.size

            val profileData = hashMapOf(
                "uid" to currentUser.uid,
                "email" to (currentUser.email ?: "Anonymous"),
                "displayName" to explorerName.value,
                "photoUrl" to (currentUser.photoUrl?.toString() ?: ""),
                "level" to stats.level,
                "experience" to stats.experience,
                "totalCatches" to catchesCount,
                "role" to userRole.value,
                "lastSyncedAt" to System.currentTimeMillis()
            )

            db.collection("users").document(currentUser.uid)
                .set(profileData, SetOptions.merge())
                .addOnSuccessListener {
                    Log.d("NatureDex", "User profile synced to Firestore.")
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "User profile sync failed", e)
                }
        } catch (e: Exception) {
            Log.e("NatureDex", "Profile sync failed: ${e.message}")
        }
    }

    fun backupCapturedCreatureToFirestore(creature: CapturedCreature) {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            
            val data = hashMapOf(
                "speciesId" to creature.speciesId,
                "name" to creature.name,
                "scientificName" to creature.scientificName,
                "category" to creature.category,
                "imageUrl" to creature.imageUrl,
                "rarity" to creature.rarity,
                "threatLevel" to creature.threatLevel,
                "dateCaptured" to creature.dateCaptured,
                "latitude" to creature.latitude,
                "longitude" to creature.longitude,
                "capturedWithTool" to creature.capturedWithTool
            )

            db.collection("users").document(currentUser.uid)
                .collection("captured_creatures").document(creature.speciesId.toString())
                .set(data, SetOptions.merge())
                .addOnSuccessListener {
                    Log.d("NatureDex", "Creature backed up: ${creature.name}")
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Creature backup failed", e)
                }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firestore backup failed: ${e.message}")
        }
    }

    fun backupWishlistToFirestore(creature: WishlistCreature) {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            val data = hashMapOf(
                "speciesId" to creature.speciesId,
                "name" to creature.name,
                "scientificName" to creature.scientificName,
                "category" to creature.category,
                "imageUrl" to creature.imageUrl,
                "rarity" to creature.rarity,
                "threatLevel" to creature.threatLevel
            )
            db.collection("users").document(currentUser.uid)
                .collection("wishlist").document(creature.speciesId.toString())
                .set(data, SetOptions.merge())
                .addOnSuccessListener { Log.d("NatureDex", "Wishlist backed up: ${creature.name}") }
                .addOnFailureListener { e -> Log.e("NatureDex", "Wishlist backup failed", e) }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firestore wishlist backup failed: ${e.message}")
        }
    }

    fun deleteWishlistFromFirestore(speciesId: Int) {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            db.collection("users").document(currentUser.uid)
                .collection("wishlist").document(speciesId.toString())
                .delete()
                .addOnSuccessListener { Log.d("NatureDex", "Wishlist item deleted: $speciesId") }
                .addOnFailureListener { e -> Log.e("NatureDex", "Wishlist delete failed", e) }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firestore wishlist delete failed: ${e.message}")
        }
    }

    fun backupAchievementToFirestore(achievement: CompletedAchievement) {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            val data = hashMapOf(
                "achievementId" to achievement.achievementId,
                "title" to achievement.title,
                "description" to achievement.description,
                "unlockedAt" to achievement.unlockedAt
            )
            db.collection("users").document(currentUser.uid)
                .collection("achievements").document(achievement.achievementId)
                .set(data, SetOptions.merge())
                .addOnSuccessListener { Log.d("NatureDex", "Achievement backed up: ${achievement.title}") }
                .addOnFailureListener { e -> Log.e("NatureDex", "Achievement backup failed", e) }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firestore achievement backup failed: ${e.message}")
        }
    }

    fun restoreCapturedCreaturesFromFirestore() {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()
            
            db.collection("users").document(currentUser.uid)
                .collection("captured_creatures")
                .get()
                .addOnSuccessListener { result ->
                    viewModelScope.launch(Dispatchers.IO) {
                        for (doc in result.documents) {
                            val name = doc.getString("name") ?: continue
                            val scientificName = doc.getString("scientificName") ?: ""
                            val category = doc.getString("category") ?: ""
                            val imageUrl = doc.getString("imageUrl") ?: ""
                            val rarity = doc.getString("rarity") ?: ""
                            val threatLevel = doc.getString("threatLevel") ?: ""
                            val dateCaptured = doc.getLong("dateCaptured") ?: System.currentTimeMillis()
                            val latitude = doc.getDouble("latitude") ?: 0.0
                            val longitude = doc.getDouble("longitude") ?: 0.0
                            val capturedWithTool = doc.getString("capturedWithTool") ?: "Poke Ball"
                            val speciesId = doc.id.toIntOrNull() ?: NatureDexRepository.generateSpeciesId()
                            
                            if (repository.isCreatureCaptured(speciesId) == 0) {
                                repository.insertCaptured(
                                    CapturedCreature(
                                        speciesId = speciesId,
                                        name = name,
                                        scientificName = scientificName,
                                        category = category,
                                        imageUrl = imageUrl,
                                        rarity = rarity,
                                        threatLevel = threatLevel,
                                        dateCaptured = dateCaptured,
                                        latitude = latitude,
                                        longitude = longitude,
                                        capturedWithTool = capturedWithTool
                                    )
                                )
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Failed to restore collection from Firestore", e)
                }
        } catch (e: Exception) {
            Log.e("NatureDex", "Firestore restore failed: ${e.message}")
        }
    }

    fun restoreAllUserDataFromFirestore() {
        try {
            val currentUser = FirebaseAuth.getInstance().currentUser ?: return
            val db = FirebaseFirestore.getInstance()

            // 1. Sync User Profile & Player Stats
            db.collection("users").document(currentUser.uid)
                .get()
                .addOnSuccessListener { doc ->
                    if (doc.exists()) {
                        val firestoreLevel = doc.getLong("level")?.toInt() ?: 1
                        val firestoreExperience = doc.getLong("experience")?.toInt() ?: 0
                        val name = doc.getString("displayName")
                        val role = doc.getString("role") ?: "catcher"

                        _userRole.value = role
                        prefs.edit().putString("user_role", role).apply()
                        
                        // Always load stats from Firestore and overwrite local/device stats
                        if (name != null && name != "Explorer") {
                            _explorerName.value = name
                            prefs.edit().putString("explorer_name", name).apply()
                        }
                        viewModelScope.launch(Dispatchers.IO) {
                            repository.insertPlayerStats(
                                PlayerStats(id = 1, level = firestoreLevel, experience = firestoreExperience)
                            )
                        }
                        Log.d("NatureDex", "Local stats always updated from Firestore: Level $firestoreLevel, Exp $firestoreExperience")
                    } else {
                        // First time logging in: upload local stats to Firestore
                        _userRole.value = "catcher"
                        prefs.edit().putString("user_role", "catcher").apply()
                        val localStats = playerStats.value
                        syncUserProfileToFirestore(localStats, capturedList.value.size)
                        syncPlayerStatsToFirestore(localStats, capturedList.value.size)
                    }
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Failed to get user profile from Firestore", e)
                }

            // 2. Sync Captured Creatures (Two-way sync)
            db.collection("users").document(currentUser.uid)
                .collection("captured_creatures")
                .get()
                .addOnSuccessListener { result ->
                    viewModelScope.launch(Dispatchers.IO) {
                        val firestoreIds = mutableSetOf<Int>()
                        for (doc in result.documents) {
                            val name = doc.getString("name") ?: continue
                            val scientificName = doc.getString("scientificName") ?: ""
                            val category = doc.getString("category") ?: ""
                            val imageUrl = doc.getString("imageUrl") ?: ""
                            val rarity = doc.getString("rarity") ?: ""
                            val threatLevel = doc.getString("threatLevel") ?: ""
                            val dateCaptured = doc.getLong("dateCaptured") ?: System.currentTimeMillis()
                            val latitude = doc.getDouble("latitude") ?: 0.0
                            val longitude = doc.getDouble("longitude") ?: 0.0
                            val capturedWithTool = doc.getString("capturedWithTool") ?: "Poke Ball"
                            val speciesId = doc.id.toIntOrNull() ?: continue
                            
                            firestoreIds.add(speciesId)
                            
                            if (repository.isCreatureCaptured(speciesId) == 0) {
                                repository.insertCaptured(
                                    CapturedCreature(
                                        speciesId = speciesId,
                                        name = name,
                                        scientificName = scientificName,
                                        category = category,
                                        imageUrl = imageUrl,
                                        rarity = rarity,
                                        threatLevel = threatLevel,
                                        dateCaptured = dateCaptured,
                                        latitude = latitude,
                                        longitude = longitude,
                                        capturedWithTool = capturedWithTool
                                    )
                                )
                            }
                        }

                        // Upload local creatures that are not in Firestore
                        val localCatches = repository.getCapturedListOnce()
                        for (creature in localCatches) {
                            if (!firestoreIds.contains(creature.speciesId)) {
                                backupCapturedCreatureToFirestore(creature)
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Failed to restore captured creatures from Firestore", e)
                }

            // 3. Sync Wishlist (Two-way sync)
            db.collection("users").document(currentUser.uid)
                .collection("wishlist")
                .get()
                .addOnSuccessListener { result ->
                    viewModelScope.launch(Dispatchers.IO) {
                        val firestoreIds = mutableSetOf<Int>()
                        for (doc in result.documents) {
                            val speciesId = doc.id.toIntOrNull() ?: continue
                            val name = doc.getString("name") ?: continue
                            val scientificName = doc.getString("scientificName") ?: ""
                            val category = doc.getString("category") ?: ""
                            val imageUrl = doc.getString("imageUrl") ?: ""
                            val rarity = doc.getString("rarity") ?: ""
                            val threatLevel = doc.getString("threatLevel") ?: ""
                            
                            firestoreIds.add(speciesId)
                            
                            if (repository.isWishlisted(speciesId) == 0) {
                                repository.insertWishlist(
                                    WishlistCreature(
                                        speciesId = speciesId,
                                        name = name,
                                        scientificName = scientificName,
                                        category = category,
                                        imageUrl = imageUrl,
                                        rarity = rarity,
                                        threatLevel = threatLevel
                                    )
                                )
                            }
                        }

                        // Upload local wishlist items not in Firestore
                        val localWishlist = repository.wishlist.first()
                        for (wishItem in localWishlist) {
                            if (!firestoreIds.contains(wishItem.speciesId)) {
                                backupWishlistToFirestore(wishItem)
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Failed to restore wishlist from Firestore", e)
                }

            // 4. Sync Achievements (Two-way sync)
            db.collection("users").document(currentUser.uid)
                .collection("achievements")
                .get()
                .addOnSuccessListener { result ->
                    viewModelScope.launch(Dispatchers.IO) {
                        val firestoreIds = mutableSetOf<String>()
                        for (doc in result.documents) {
                            val achievementId = doc.id
                            val title = doc.getString("title") ?: continue
                            val description = doc.getString("description") ?: ""
                            val unlockedAt = doc.getLong("unlockedAt") ?: System.currentTimeMillis()
                            
                            firestoreIds.add(achievementId)
                            
                            val completed = repository.completedAchievements.first().map { it.achievementId }.toSet()
                            if (!completed.contains(achievementId)) {
                                repository.insertCompletedAchievement(
                                    CompletedAchievement(
                                        achievementId = achievementId,
                                        title = title,
                                        description = description,
                                        unlockedAt = unlockedAt
                                    )
                                )
                            }
                        }

                        // Upload local achievements not in Firestore
                        val localAchievements = repository.completedAchievements.first()
                        for (ach in localAchievements) {
                            if (!firestoreIds.contains(ach.achievementId)) {
                                backupAchievementToFirestore(ach)
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Log.e("NatureDex", "Failed to restore achievements from Firestore", e)
                }

        } catch (e: Exception) {
            Log.e("NatureDex", "Failed to restore user data from Firestore: ${e.message}")
        }
    }

    // --- Sound Settings ---
    private val _isSoundMuted = MutableStateFlow(prefs.getBoolean("sound_muted", false))
    val isSoundMuted: StateFlow<Boolean> = _isSoundMuted.asStateFlow()

    fun setSoundMuted(muted: Boolean) {
        _isSoundMuted.value = muted
        prefs.edit().putBoolean("sound_muted", muted).apply()
        com.example.ui.audio.SoundEffectsManager.isMuted = muted
        if (muted) {
            com.example.ui.audio.SoundEffectsManager.stopBgm()
        } else if (currentScannedCreature.value != null) {
            com.example.ui.audio.SoundEffectsManager.startBgm(getApplication())
        }
    }



    fun setExplorerName(name: String) {
        _explorerName.value = name
        prefs.edit().putString("explorer_name", name).apply()
        syncPlayerStatsToFirestore()
        syncUserProfileToFirestore()
    }

    // --- Detail Page ---
    private val _selectedSpecies = MutableStateFlow<DefaultSpecies?>(null)
    val selectedSpecies: StateFlow<DefaultSpecies?> = _selectedSpecies.asStateFlow()

    private val _showDetail = MutableStateFlow(false)
    val showDetail: StateFlow<Boolean> = _showDetail.asStateFlow()

    fun showSpeciesDetail(species: DefaultSpecies) {
        _selectedSpecies.value = species
        _showDetail.value = true
    }

    fun closeSpeciesDetail() {
        _showDetail.value = false
        _selectedSpecies.value = null
    }

    // --- Local Database Flows ---
    val capturedList: StateFlow<List<CapturedCreature>> = repository.capturedList
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val wishlist: StateFlow<List<WishlistCreature>> = repository.wishlist
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val inventoryTools: StateFlow<List<InventoryTool>> = combine(
        repository.inventoryTools,
        _userRole,
        _isDeveloperMode
    ) { tools, role, devMode ->
        if (role == "admin" && devMode) {
            tools.map { tool ->
                tool.copy(
                    isUnlocked = true,
                    usesRemaining = 999,
                    maxDailyUses = 999
                )
            }
        } else {
            tools
        }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    val playerStats: StateFlow<PlayerStats> = repository.playerStats
        .map { it ?: PlayerStats() }
        .stateIn(viewModelScope, SharingStarted.Eagerly, PlayerStats())

    val completedAchievements: StateFlow<List<CompletedAchievement>> = repository.completedAchievements
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    // --- Index Screen Filters & Search ---
    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _selectedCategory = MutableStateFlow("All")
    val selectedCategory: StateFlow<String> = _selectedCategory.asStateFlow()

    private val _iNaturalistResults = MutableStateFlow<List<DefaultSpecies>>(emptyList())
    val iNaturalistResults: StateFlow<List<DefaultSpecies>> = _iNaturalistResults.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    private val _speciesList = MutableStateFlow<List<DefaultSpecies>>(DefaultSpeciesList.list)
    val speciesList: StateFlow<List<DefaultSpecies>> = _speciesList.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    // Combined species catalog (pre-populated offline + loaded from iNaturalist)
    val displayedSpecies: StateFlow<List<DefaultSpecies>> = combine(
        _searchQuery,
        _selectedCategory,
        _iNaturalistResults,
        _speciesList
    ) { query, category, onlineResults, offlineList ->
        val offlineFiltered = offlineList.filter { species ->
            val matchesSearch = species.name.contains(query, ignoreCase = true) ||
                    species.scientificName.contains(query, ignoreCase = true)
            val matchesCategory = category == "All" || species.category.equals(category, ignoreCase = true)
            matchesSearch && matchesCategory
        }

        val onlineFiltered = onlineResults.filter { species ->
            val matchesSearch = species.name.contains(query, ignoreCase = true) ||
                    species.scientificName.contains(query, ignoreCase = true)
            val matchesCategory = category == "All" || species.category.equals(category, ignoreCase = true)
            matchesSearch && matchesCategory
        }

        val mergedList = (offlineFiltered + onlineFiltered).distinctBy { it.scientificName.lowercase() }
        mergedList
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), DefaultSpeciesList.list)

    fun setSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun setCategory(category: String) {
        _selectedCategory.value = category
        triggerINaturalistFetch(_searchQuery.value)
    }

    private fun triggerINaturalistFetch(query: String) {
        val category = _selectedCategory.value
        if (query.length < 3 && category == "All") {
            _iNaturalistResults.value = emptyList()
            return
        }

        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            _isSearching.value = true
            try {
                val iconicTaxon = when (category) {
                    "Animals" -> "Mammalia,Amphibia"
                    "Birds" -> "Aves"
                    "Fish" -> "Actinopterygii"
                    "Insects" -> "Insecta,Arachnida"
                    "Reptiles" -> "Reptilia"
                    "Plants" -> "Plantae"
                    else -> null
                }

                val results = repository.autocompleteINaturalist(query, iconicTaxon)
                val mapped = repository.mapINaturalistResultsToSpecies(results, category)
                _iNaturalistResults.value = mapped
            } catch (e: Exception) {
                Log.e("NatureDex", "iNaturalist fetch failed: ${e.message}")
            } finally {
                _isSearching.value = false
            }
        }
    }

    // --- Wishlist Actions ---
    private val _isWishlistedState = MutableStateFlow<Map<Int, Boolean>>(emptyMap())
    val isWishlistedState: StateFlow<Map<Int, Boolean>> = _isWishlistedState.asStateFlow()

    fun loadWishlistState(speciesId: Int) {
        viewModelScope.launch {
            val count = repository.isWishlisted(speciesId)
            _isWishlistedState.value = _isWishlistedState.value + (speciesId to (count > 0))
        }
    }

    fun toggleWishlist(species: DefaultSpecies) {
        viewModelScope.launch(Dispatchers.IO) {
            val isCurrently = repository.isWishlisted(species.id) > 0
            if (isCurrently) {
                repository.deleteWishlistById(species.id)
                _isWishlistedState.value = _isWishlistedState.value + (species.id to false)
                deleteWishlistFromFirestore(species.id)
            } else {
                val wishlistCreature = WishlistCreature(
                    speciesId = species.id,
                    name = species.name,
                    scientificName = species.scientificName,
                    category = species.category,
                    imageUrl = species.imageUrl,
                    rarity = species.rarity,
                    threatLevel = species.threatLevel
                )
                repository.insertWishlist(wishlistCreature)
                _isWishlistedState.value = _isWishlistedState.value + (species.id to true)
                backupWishlistToFirestore(wishlistCreature)
            }
        }
    }

    fun removeFromWishlist(speciesId: Int) {
        viewModelScope.launch(Dispatchers.IO) {
            repository.deleteWishlistById(speciesId)
            _isWishlistedState.value = _isWishlistedState.value + (speciesId to false)
            deleteWishlistFromFirestore(speciesId)
        }
    }

    // --- Scanning / Camera & Gemini AI Features ---
    private val _currentScannedCreature = MutableStateFlow<ScannedCreatureResponse?>(null)
    val currentScannedCreature: StateFlow<ScannedCreatureResponse?> = _currentScannedCreature.asStateFlow()

    private val _scannedCreatureImageUrl = MutableStateFlow<String?>(null)
    val scannedCreatureImageUrl: StateFlow<String?> = _scannedCreatureImageUrl.asStateFlow()

    private val _isScanningAPI = MutableStateFlow(false)
    val isScanningAPI: StateFlow<Boolean> = _isScanningAPI.asStateFlow()

    private val _scanningError = MutableStateFlow<String?>(null)
    val scanningError: StateFlow<String?> = _scanningError.asStateFlow()

    private suspend fun resolveImageForScanned(creature: ScannedCreatureResponse) {
        val matched = _speciesList.value.find {
            it.name.equals(creature.name, ignoreCase = true) ||
            it.scientificName.equals(creature.scientificName, ignoreCase = true)
        }
        if (matched != null) {
            _scannedCreatureImageUrl.value = matched.imageUrl
            return
        }

        val fetchedUrl = repository.resolveRealSpeciesImage(creature.name, creature.scientificName)
        _scannedCreatureImageUrl.value = fetchedUrl ?: "https://images.unsplash.com/photo-1472214222555-d40d5cca4987?w=500"
    }

    fun scanImageWithGemini(base64Image: String, localImagePath: String? = null) {
        Log.d("NatureDex", "scanImageWithGemini: called with base64 image length = ${base64Image.length}, localImagePath = $localImagePath")
        viewModelScope.launch {
            _isScanningAPI.value = true
            _scanningError.value = null
            _currentScannedCreature.value = null
            _scannedCreatureImageUrl.value = null

            try {
                val apiKey = com.example.BuildConfig.GEMINI_API_KEY
                if (apiKey.isEmpty() || apiKey == "MY_GEMINI_API_KEY") {
                    throw IllegalStateException("API Key is placeholder or missing. Please add your GEMINI_API_KEY inside the .env file in the project directory.")
                }
                Log.d("NatureDex", "scanImageWithGemini: Starting Gemini image request...")
                val scanned = repository.scanImageWithGemini(base64Image)
                Log.d("NatureDex", "scanImageWithGemini: Finished Gemini request, scanned creature: $scanned")
                if (scanned != null) {
                    _currentScannedCreature.value = scanned
                    if (localImagePath != null) {
                        _scannedCreatureImageUrl.value = localImagePath
                    } else {
                        resolveImageForScanned(scanned)
                    }
                } else {
                    _scanningError.value = "Unable to parse Gemini response structure"
                    Log.e("NatureDex", "scanImageWithGemini: Scanned result is null")
                }
            } catch (e: retrofit2.HttpException) {
                val errorBody = try {
                    e.response()?.errorBody()?.string()
                } catch (ex: Exception) {
                    null
                }
                Log.e("NatureDex", "scanImageWithGemini: HTTP Exception ${e.code()}. Response body: $errorBody", e)
                
                val apiErrorMessage = if (errorBody != null) {
                    try {
                        val moshi = com.squareup.moshi.Moshi.Builder().build()
                        val mapAdapter = moshi.adapter(Map::class.java)
                        val parsed = mapAdapter.fromJson(errorBody)
                        val errorMap = parsed?.get("error") as? Map<*, *>
                        errorMap?.get("message") as? String
                    } catch (ex: Exception) {
                        null
                    }
                } else {
                    null
                }

                if (e.code() == 429) {
                    _scanningError.value = apiErrorMessage ?: "Rate Limit Exceeded (HTTP 429). Please check your API usage limits."
                } else {
                    _scanningError.value = apiErrorMessage ?: "HTTP Error ${e.code()}: ${e.message()}"
                }
            } catch (e: Exception) {
                Log.e("NatureDex", "scanImageWithGemini: Exception occurred during scanning", e)
                _scanningError.value = "Error: ${e.message}"
            } finally {
                _isScanningAPI.value = false
                Log.d("NatureDex", "scanImageWithGemini: Completed. isScanningAPI = false")
            }
        }
    }

    // --- Capture Mechanics ---
    private val _selectedTool = MutableStateFlow<InventoryTool?>(null)
    val selectedTool: StateFlow<InventoryTool?> = _selectedTool.asStateFlow()

    fun selectTool(tool: InventoryTool) {
        _selectedTool.value = tool
    }

    private val _captureAttempts = MutableStateFlow(0)
    val captureAttempts: StateFlow<Int> = _captureAttempts.asStateFlow()

    private val _captureFinished = MutableStateFlow(false)
    val captureFinished: StateFlow<Boolean> = _captureFinished.asStateFlow()

    private val _captureResultMsg = MutableStateFlow("")
    val captureResultMsg: StateFlow<String> = _captureResultMsg.asStateFlow()

    private val _lastCapturedCreature = MutableStateFlow<CapturedCreature?>(null)
    val lastCapturedCreature: StateFlow<CapturedCreature?> = _lastCapturedCreature.asStateFlow()

    fun calculateCaptureProbability(
        creature: ScannedCreatureResponse,
        tool: InventoryTool
    ): Int {
        if (tool.toolName == "Master Ball") return 100
        if (tool.toolName == "GS Ball") return 95

        val baseProb = 0.55f

        val threatMult = when (creature.threatLevel) {
            "None" -> 1.2f
            "Low" -> 1.0f
            "Medium" -> 0.8f
            "High" -> 0.6f
            "Deadly" -> 0.4f
            else -> 1.0f
        }

        val rarityMult = when (creature.rarity) {
            "Common" -> 1.2f
            "Uncommon" -> 1.0f
            "Rare" -> 0.7f
            "Legendary" -> 0.4f
            else -> 1.0f
        }

        val sizeMult = when (creature.category) {
            "Plants" -> 1.3f
            "Insects" -> 1.1f
            "Birds" -> 0.9f
            else -> 1.0f
        }

        val ballMultiplier = when (tool.toolName) {
            "Poke Ball" -> 1.0f
            "Premier Ball" -> 1.2f
            "Great Ball" -> 1.5f
            "Quick Ball" -> 1.8f
            "Ultra Ball" -> 2.0f
            "Beast Ball" -> 2.5f
            else -> 1.0f
        }

        val tierBoost = (tool.tier - 1) * 0.15f

        val weather = _currentEnvironmentalWeather.value
        val weatherMult = when (weather) {
            "Rainy" -> if (creature.category == "Fish") 1.3f else if (creature.category == "Birds") 0.8f else 1.0f
            "Stormy" -> if (creature.category == "Fish" || creature.category == "Reptiles") 1.2f else 0.7f
            "Foggy" -> if (creature.category == "Insects") 1.2f else 0.8f
            "Clear Night" -> if (creature.category == "Insects" || creature.category == "Reptiles") 1.2f else 0.9f
            else -> 1.0f
        }

        val totalChance = baseProb * threatMult * rarityMult * sizeMult * (ballMultiplier + tierBoost) * weatherMult
        val percent = (totalChance * 100).toInt().coerceIn(5, 95)
        return percent
    }

    private fun getNativeLocation(): Location? {
        val app = getApplication<Application>()
        val locationManager = app.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        try {
            val providers = locationManager.getProviders(true)
            var bestLocation: Location? = null
            for (provider in providers) {
                val loc = locationManager.getLastKnownLocation(provider) ?: continue
                if (bestLocation == null || loc.accuracy < bestLocation.accuracy) {
                    bestLocation = loc
                }
            }
            return bestLocation
        } catch (e: SecurityException) {
            Log.e("NatureDex", "SecurityException during native location access", e)
        } catch (e: Exception) {
            Log.e("NatureDex", "Failed to get native location", e)
        }
        return null
    }

    private fun requestNativeLocationUpdates() {
        val app = getApplication<Application>()
        if (androidx.core.content.ContextCompat.checkSelfPermission(app, android.Manifest.permission.ACCESS_FINE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
            androidx.core.content.ContextCompat.checkSelfPermission(app, android.Manifest.permission.ACCESS_COARSE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return
        }
        val locationManager = app.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
        try {
            val providers = locationManager.getProviders(true)
            for (provider in providers) {
                locationManager.requestLocationUpdates(
                    provider,
                    1000L,
                    1f,
                    object : android.location.LocationListener {
                        override fun onLocationChanged(location: Location) {
                            _currentLocation.value = location
                            Log.d("NatureDex", "Native LocationManager onLocationChanged: ${location.latitude}, ${location.longitude}")
                            locationManager.removeUpdates(this)
                        }
                    },
                    android.os.Looper.getMainLooper()
                )
            }
        } catch (e: SecurityException) {
            Log.e("NatureDex", "SecurityException requesting native location updates", e)
        } catch (e: Exception) {
            Log.e("NatureDex", "Failed to request native location updates", e)
        }
    }

    fun updateLocation() {
        val app = getApplication<Application>()
        if (androidx.core.content.ContextCompat.checkSelfPermission(app, android.Manifest.permission.ACCESS_FINE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
            androidx.core.content.ContextCompat.checkSelfPermission(app, android.Manifest.permission.ACCESS_COARSE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return
        }

        // Always trigger native platform location requests in parallel as a robust fallback
        requestNativeLocationUpdates()

        try {
            // 1. Try last location first
            fusedLocationClient?.lastLocation?.addOnSuccessListener { location ->
                if (location != null) {
                    _currentLocation.value = location
                    Log.d("NatureDex", "Last Known Location: ${location.latitude}, ${location.longitude}")
                }
            }

            // 2. Request a fresh single update
            val locationRequest = com.google.android.gms.location.LocationRequest.Builder(
                com.google.android.gms.location.Priority.PRIORITY_HIGH_ACCURACY,
                1000L
            ).setMaxUpdates(1).build()

            val locationCallback = object : com.google.android.gms.location.LocationCallback() {
                override fun onLocationResult(locationResult: com.google.android.gms.location.LocationResult) {
                    val location = locationResult.lastLocation
                    if (location != null) {
                        _currentLocation.value = location
                        Log.d("NatureDex", "Callback Location: ${location.latitude}, ${location.longitude}")
                    } else {
                        val nativeLoc = getNativeLocation()
                        if (nativeLoc != null) {
                            _currentLocation.value = nativeLoc
                            Log.d("NatureDex", "Callback Fallback Location: ${nativeLoc.latitude}, ${nativeLoc.longitude}")
                        }
                    }
                }
            }

            fusedLocationClient?.requestLocationUpdates(
                locationRequest,
                locationCallback,
                android.os.Looper.getMainLooper()
            )?.addOnFailureListener {
                val nativeLoc = getNativeLocation()
                if (nativeLoc != null) {
                    _currentLocation.value = nativeLoc
                }
            }
        } catch (e: SecurityException) {
            Log.e("NatureDex", "Location permission missing", e)
        } catch (e: Exception) {
            Log.e("NatureDex", "Error fetching fused location", e)
            val nativeLoc = getNativeLocation()
            if (nativeLoc != null) {
                _currentLocation.value = nativeLoc
            }
        }
    }

    fun startTrackingLocation() {
        val app = getApplication<Application>()
        if (androidx.core.content.ContextCompat.checkSelfPermission(app, android.Manifest.permission.ACCESS_FINE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
            androidx.core.content.ContextCompat.checkSelfPermission(app, android.Manifest.permission.ACCESS_COARSE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return
        }

        // Always do a one-time check/update first
        updateLocation()

        // 1. Continuous Fused updates
        if (activeLocationCallback == null) {
            val locationRequest = com.google.android.gms.location.LocationRequest.Builder(
                com.google.android.gms.location.Priority.PRIORITY_HIGH_ACCURACY,
                3000L
            ).build()

            val callback = object : com.google.android.gms.location.LocationCallback() {
                override fun onLocationResult(locationResult: com.google.android.gms.location.LocationResult) {
                    val location = locationResult.lastLocation
                    if (location != null) {
                        _currentLocation.value = location
                        Log.d("NatureDex", "Continuous Fused Location update: ${location.latitude}, ${location.longitude}")
                    }
                }
            }
            activeLocationCallback = callback
            try {
                fusedLocationClient?.requestLocationUpdates(
                    locationRequest,
                    callback,
                    android.os.Looper.getMainLooper()
                )
            } catch (e: Exception) {
                Log.e("NatureDex", "Error starting fused location updates", e)
            }
        }

        // 2. Continuous Native updates (fallback)
        if (activeNativeListener == null) {
            val locationManager = app.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            if (locationManager != null) {
                val listener = object : android.location.LocationListener {
                    override fun onLocationChanged(location: Location) {
                        _currentLocation.value = location
                        Log.d("NatureDex", "Continuous Native Location update: ${location.latitude}, ${location.longitude}")
                    }
                    @Deprecated("Deprecated in Java")
                    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }
                activeNativeListener = listener
                try {
                    val providers = locationManager.getProviders(true)
                    for (provider in providers) {
                        locationManager.requestLocationUpdates(
                            provider,
                            3000L,
                            0.5f,
                            listener,
                            android.os.Looper.getMainLooper()
                        )
                    }
                } catch (e: Exception) {
                    Log.e("NatureDex", "Error starting native location updates", e)
                }
            }
        }
    }

    fun stopTrackingLocation() {
        val app = getApplication<Application>()
        activeLocationCallback?.let {
            try {
                fusedLocationClient?.removeLocationUpdates(it)
            } catch (e: Exception) {
                Log.e("NatureDex", "Error removing fused location updates", e)
            }
            activeLocationCallback = null
        }
        activeNativeListener?.let { listener ->
            try {
                val locationManager = app.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                locationManager?.removeUpdates(listener)
            } catch (e: Exception) {
                Log.e("NatureDex", "Error removing native location updates", e)
            }
            activeNativeListener = null
        }
    }


    fun makeCaptureAttempt(
        creature: ScannedCreatureResponse,
        tool: InventoryTool,
        gestureSucceeded: Boolean,
        isMiss: Boolean = false
    ) {
        viewModelScope.launch {
            captureMutex.withLock {
                if (_captureFinished.value) return@withLock

                val isDevMode = _userRole.value == "admin" && _isDeveloperMode.value
                if (!isDevMode && tool.usesRemaining <= 0) {
                    _captureResultMsg.value = "Out of uses for this tool today!"
                    return@withLock
                }

                val updatedTool = if (isDevMode) {
                    tool
                } else {
                    val nextTool = tool.copy(usesRemaining = tool.usesRemaining - 1)
                    repository.updateTool(nextTool)
                    nextTool
                }
                _selectedTool.value = updatedTool

                _captureAttempts.value += 1

                val gestureBonus = if (gestureSucceeded) 15 else 0
                val catchChance = if (isMiss) -999 else (calculateCaptureProbability(creature, tool) + gestureBonus)
                val diceRoll = Random().nextInt(100) + 1

                Log.d("NatureDex", "Capture Chance: $catchChance%, Rolled: $diceRoll")

                if (diceRoll <= catchChance) {
                    _captureFinished.value = true
                    _captureResultMsg.value = "Successfully Captured!"

                    val location = _currentLocation.value ?: getNativeLocation()
                    val lat = location?.latitude ?: (13.0827 + (Random().nextDouble() - 0.5) * 0.1)
                    val lng = location?.longitude ?: (80.2707 + (Random().nextDouble() - 0.5) * 0.1)

                    val matchedSpecies = _speciesList.value.find {
                        it.name.equals(creature.name, ignoreCase = true) ||
                        it.scientificName.equals(creature.scientificName, ignoreCase = true)
                    }

                    val finalImage = _scannedCreatureImageUrl.value
                        ?: matchedSpecies?.imageUrl
                        ?: "https://images.unsplash.com/photo-1472214222555-d40d5cca4987?w=500"

                    val captured = CapturedCreature(
                        speciesId = NatureDexRepository.generateSpeciesId(),
                        name = creature.name,
                        scientificName = creature.scientificName,
                        category = creature.category,
                        imageUrl = finalImage,
                        rarity = creature.rarity,
                        threatLevel = creature.threatLevel,
                        dateCaptured = System.currentTimeMillis(),
                        latitude = lat,
                        longitude = lng,
                        capturedWithTool = tool.displayName
                    )

                    repository.insertCaptured(captured)
                    _lastCapturedCreature.value = captured
                    backupCapturedCreatureToFirestore(captured)

                    val weather = _currentEnvironmentalWeather.value
                    val weatherBonus = if (weather == "Rainy" && creature.category == "Fish") 50
                                       else if (weather == "Clear Night" && (creature.category == "Insects" || creature.category == "Reptiles")) 50
                                       else 0

                    val xpGained = when (creature.rarity) {
                        "Common" -> 100
                        "Uncommon" -> 200
                        "Rare" -> 400
                        "Legendary" -> 800
                        else -> 100
                    }
                    val totalXp = xpGained + weatherBonus
                    incrementExperience(totalXp)

                    if (weatherBonus > 0) {
                        _captureResultMsg.value = "Successfully Captured! Weather Boost: +$weatherBonus XP!"
                    } else {
                        _captureResultMsg.value = "Successfully Captured!"
                    }

                    checkBountyProgress(captured)
                    awardAchievements()
                } else {
                    if (_captureAttempts.value >= 3) {
                        _captureFinished.value = true
                        _captureResultMsg.value = "The creature got startled and fled!"
                    } else {
                        _captureResultMsg.value = "Oh no! It broke free of the Poke Ball! Try again (Attempts: ${_captureAttempts.value}/3)"
                    }
                }
            }
        }
    }

    fun resetCaptureState() {
        _currentScannedCreature.value = null
        _scannedCreatureImageUrl.value = null
        _captureAttempts.value = 0
        _captureFinished.value = false
        _captureResultMsg.value = ""
        _lastCapturedCreature.value = null
    }

    // --- Upgrades / Marketplace ---
    fun upgradeToolTier(tool: InventoryTool) {
        viewModelScope.launch {
            if (tool.tier >= 3) return@launch

            val current = playerStats.value
            val costInXP = tool.tier * 300
            if (current.experience >= costInXP) {
                val nextTierName = when (tool.tier) {
                    1 -> "Reinforced ${tool.toolName}"
                    2 -> "Carbon ${tool.toolName}"
                    else -> tool.displayName
                }
                val upgraded = tool.copy(
                    displayName = nextTierName,
                    tier = tool.tier + 1,
                    maxDailyUses = tool.maxDailyUses + 5,
                    usesRemaining = tool.usesRemaining + 5
                )
                repository.updateTool(upgraded)
                repository.insertPlayerStats(current.copy(experience = current.experience - costInXP))
            }
        }
    }

    fun resetDailyInventoryUses() {
        viewModelScope.launch {
            repository.resetDailyUses()
            prefs.edit().putLong("last_daily_reset", System.currentTimeMillis()).apply()
        }
    }

    // --- Progression Systems ---
    fun incrementExperience(amount: Int) {
        viewModelScope.launch {
            val stats = playerStats.value
            var currentXP = stats.experience + amount
            var currentLvl = stats.level

            while (currentXP >= 1000) {
                currentXP -= 1000
                currentLvl += 1
            }

            val nextStats = PlayerStats(
                id = 1,
                level = currentLvl,
                experience = currentXP,
                totalCatches = stats.totalCatches + 1
            )
            repository.insertPlayerStats(nextStats)
            
            val catchesCount = repository.getCapturedListOnce().size
            syncPlayerStatsToFirestore(nextStats, catchesCount)
            syncUserProfileToFirestore(nextStats, catchesCount)

            val tools = repository.inventoryTools.first()
            tools.forEach { t ->
                if (!t.isUnlocked && currentLvl >= t.unlockLevel) {
                    repository.updateTool(t.copy(isUnlocked = true))
                }
            }
        }
    }

    // --- Achievements Awarding ---
    private fun awardAchievements() {
        viewModelScope.launch {
            val catches = repository.getCapturedListOnce()
            if (catches.isEmpty()) return@launch

            val completed = repository.completedAchievements.first().map { it.achievementId }.toSet()

            if (!completed.contains("first_catch")) {
                val ach = CompletedAchievement(
                    achievementId = "first_catch",
                    title = "First Catch",
                    description = "Catch your first real wildlife discovery",
                    unlockedAt = System.currentTimeMillis()
                )
                repository.insertCompletedAchievement(ach)
                backupAchievementToFirestore(ach)
            }

            val birdCatchesCount = catches.count { it.category == "Birds" }
            if (birdCatchesCount >= 10 && !completed.contains("bird_watcher")) {
                val ach = CompletedAchievement(
                    achievementId = "bird_watcher",
                    title = "Bird Watcher",
                    description = "Successfully capture 10 species of birds",
                    unlockedAt = System.currentTimeMillis()
                )
                repository.insertCompletedAchievement(ach)
                backupAchievementToFirestore(ach)
            }

            val hasCobra = catches.any { it.name.contains("Cobra", ignoreCase = true) }
            if (hasCobra && !completed.contains("survived_cobra")) {
                val ach = CompletedAchievement(
                    achievementId = "survived_cobra",
                    title = "Survived a Cobra",
                    description = "Encounter and capture a deadly Spectacled Cobra",
                    unlockedAt = System.currentTimeMillis()
                )
                repository.insertCompletedAchievement(ach)
                backupAchievementToFirestore(ach)
            }

            val tnCatchesCount = catches.count { it.latitude in 8.0..14.0 && it.longitude in 75.0..82.0 }
            if (tnCatchesCount >= 20 && !completed.contains("tamil_nadu_explorer")) {
                val ach = CompletedAchievement(
                    achievementId = "tamil_nadu_explorer",
                    title = "Tamil Nadu Explorer",
                    description = "Discover a total of 20 species native to Tamil Nadu",
                    unlockedAt = System.currentTimeMillis()
                )
                repository.insertCompletedAchievement(ach)
                backupAchievementToFirestore(ach)
            }

            val insectCount = catches.count { it.category == "Insects" }
            if (insectCount >= 5 && !completed.contains("insect_dex")) {
                val ach = CompletedAchievement(
                    achievementId = "insect_dex",
                    title = "Complete Insect Dex",
                    description = "Capture 5 different types of insects in your region",
                    unlockedAt = System.currentTimeMillis()
                )
                repository.insertCompletedAchievement(ach)
                backupAchievementToFirestore(ach)
            }

            val hasNightCatch = catches.any {
                val c = Calendar.getInstance().apply { timeInMillis = it.dateCaptured }
                c.get(Calendar.HOUR_OF_DAY) >= 21 || c.get(Calendar.HOUR_OF_DAY) < 5
            }
            if (hasNightCatch && !completed.contains("night_hunter")) {
                val ach = CompletedAchievement(
                    achievementId = "night_hunter",
                    title = "Night Hunter",
                    description = "Capture any wild specimen after 9:00 PM",
                    unlockedAt = System.currentTimeMillis()
                )
                repository.insertCompletedAchievement(ach)
                backupAchievementToFirestore(ach)
            }

            val hasEndangered = catches.any { it.rarity == "Legendary" || it.rarity == "Rare" }
            if (hasEndangered && !completed.contains("rare_find")) {
                val ach = CompletedAchievement(
                    achievementId = "rare_find",
                    title = "Rare Find",
                    description = "Locate and capture an Endangered or Legendary species",
                    unlockedAt = System.currentTimeMillis()
                )
                repository.insertCompletedAchievement(ach)
                backupAchievementToFirestore(ach)
            }
        }
    }

    private fun migrateToolsIfNecessary() {
        viewModelScope.launch(Dispatchers.IO) {
            val currentTools = repository.inventoryTools.first()
            val hasOldTools = currentTools.size != 8 || currentTools.any { it.toolName == "Net" || it.toolName == "Lasso" }
            if (hasOldTools || currentTools.isEmpty()) {
                repository.clearAllTools()
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
                starterTools.forEach { repository.insertTool(it) }
            }
        }
    }

    private fun loadDefaultSpecies() {
        viewModelScope.launch {
            _isLoading.value = true
            val resolvedList = DefaultSpeciesList.list.map { species ->
                if (species.imageUrl.contains("unsplash.com") || species.imageUrl.isBlank()) {
                    val resolvedUrl = repository.resolveSpeciesImage(species)
                    species.copy(imageUrl = resolvedUrl)
                } else {
                    species
                }
            }
            _speciesList.value = resolvedList
            _isLoading.value = false
        }
    }

    init {
        migrateToolsIfNecessary()
        loadDefaultSpecies()

        _searchQuery
            .debounce(400)
            .distinctUntilChanged()
            .onEach { query ->
                triggerINaturalistFetch(query)
            }
            .launchIn(viewModelScope)
    }

    fun wipeData() {
        viewModelScope.launch(Dispatchers.IO) {
            repository.clearAllCaptured()
            repository.clearAllAchievements()
            repository.insertPlayerStats(PlayerStats(id = 1, level = 1, experience = 0, totalCatches = 0))

            repository.clearAllTools()
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
            starterTools.forEach { repository.insertTool(it) }

            _selectedTool.value = starterTools.first()
            resetCaptureState()

            // Also sync wiped data to Firestore if logged in
            try {
                val currentUser = FirebaseAuth.getInstance().currentUser
                if (currentUser != null) {
                    val db = FirebaseFirestore.getInstance()
                    val data = hashMapOf(
                        "name" to explorerName.value,
                        "level" to 1,
                        "catches" to 0,
                        "updatedAt" to System.currentTimeMillis()
                    )
                    db.collection("leaderboards").document(currentUser.uid)
                        .set(data, SetOptions.merge())
                    
                    // Reset user profile details
                    val profileData = hashMapOf(
                        "level" to 1,
                        "experience" to 0,
                        "totalCatches" to 0,
                        "lastSyncedAt" to System.currentTimeMillis()
                    )
                    db.collection("users").document(currentUser.uid)
                        .set(profileData, SetOptions.merge())
                    
                    // Delete backed up creatures
                    db.collection("users").document(currentUser.uid)
                        .collection("captured_creatures")
                        .get()
                        .addOnSuccessListener { result ->
                            for (doc in result.documents) {
                                doc.reference.delete()
                            }
                        }

                    // Delete wishlist
                    db.collection("users").document(currentUser.uid)
                        .collection("wishlist")
                        .get()
                        .addOnSuccessListener { result ->
                            for (doc in result.documents) {
                                doc.reference.delete()
                            }
                        }

                    // Delete achievements
                    db.collection("users").document(currentUser.uid)
                        .collection("achievements")
                        .get()
                        .addOnSuccessListener { result ->
                            for (doc in result.documents) {
                                doc.reference.delete()
                            }
                        }
                }
            } catch (e: java.lang.Exception) {
                Log.e("NatureDex", "Error syncing wipe to Firestore: ${e.message}")
            }
        }
    }

    // --- AR Mode Toggle setting ---
    fun setArEnabled(enabled: Boolean) {
        _isArEnabled.value = enabled
        prefs.edit().putBoolean("ar_enabled", enabled).apply()
    }

    // --- Biometric Lock setting ---
    fun setBiometricLockEnabled(enabled: Boolean) {
        _isBiometricLockEnabled.value = enabled
        prefs.edit().putBoolean("biometric_lock_enabled", enabled).apply()
    }

    // --- Weather & Environmental Modifiers ---
    private fun initWeather() {
        val weatherList = listOf("Sunny", "Rainy", "Foggy", "Stormy", "Clear Night")
        val calendar = Calendar.getInstance()
        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val isNight = hour >= 18 || hour < 6
        val weatherIndex = (calendar.get(Calendar.DAY_OF_YEAR) + hour / 4) % weatherList.size
        var initialWeather = weatherList[weatherIndex]
        if (isNight && initialWeather == "Sunny") {
            initialWeather = "Clear Night"
        }
        _currentEnvironmentalWeather.value = initialWeather
    }

    // --- Daily Bounties System ---

    private fun initDailyBounties() {
        val calendar = Calendar.getInstance()
        val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
        
        val allBounties = listOf(
            DailyBounty("bounty_birds", "Avian Scout", "Catalog 2 bird species", "Birds", 2, 0, 300),
            DailyBounty("bounty_insects", "Insect Collector", "Catalog 2 insect species", "Insects", 2, 0, 300),
            DailyBounty("bounty_plants", "Botanical Study", "Catalog 2 plant species", "Plants", 2, 0, 300),
            DailyBounty("bounty_reptiles", "Herpetologist", "Catalog 1 reptile species", "Reptiles", 1, 0, 400),
            DailyBounty("bounty_fish", "Aquatic Census", "Catalog 1 fish species", "Fish", 1, 0, 400),
            DailyBounty("bounty_any", "Nature Walks", "Catalog any 3 species", "Any", 3, 0, 250),
            DailyBounty("bounty_rare", "Rare Find", "Catalog 1 Rare or Legendary creature", "Rare", 1, 0, 500)
        )
        
        val index1 = dayOfYear % allBounties.size
        val index2 = (dayOfYear + 2) % allBounties.size
        val index3 = (dayOfYear + 5) % allBounties.size
        
        val chosen = listOf(
            allBounties[index1],
            allBounties[if (index2 == index1) (index2 + 1) % allBounties.size else index2],
            allBounties[if (index3 == index1 || index3 == index2) (index3 + 2) % allBounties.size else index3]
        )
        
        val restored = chosen.map { bounty ->
            val progressKey = "bounty_prog_${bounty.id}_$dayOfYear"
            val compKey = "bounty_comp_${bounty.id}_$dayOfYear"
            val current = prefs.getInt(progressKey, 0)
            val completed = prefs.getBoolean(compKey, false)
            bounty.copy(currentCount = current, isCompleted = completed)
        }
        _dailyBounties.value = restored
    }

    fun checkBountyProgress(creature: CapturedCreature) {
        val calendar = Calendar.getInstance()
        val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
        
        val currentList = _dailyBounties.value
        val updatedList = currentList.map { bounty ->
            if (bounty.isCompleted) return@map bounty
            
            val matchesCategory = when (bounty.category) {
                "Any" -> true
                "Rare" -> creature.rarity == "Rare" || creature.rarity == "Legendary"
                else -> creature.category.equals(bounty.category, ignoreCase = true)
            }
            
            if (matchesCategory) {
                val nextCount = (bounty.currentCount + 1).coerceAtMost(bounty.targetCount)
                val isNowCompleted = nextCount >= bounty.targetCount
                val progressKey = "bounty_prog_${bounty.id}_$dayOfYear"
                val compKey = "bounty_comp_${bounty.id}_$dayOfYear"
                
                prefs.edit().putInt(progressKey, nextCount).putBoolean(compKey, isNowCompleted).apply()
                
                if (isNowCompleted) {
                    viewModelScope.launch {
                        incrementExperience(bounty.xpReward)
                    }
                }
                bounty.copy(currentCount = nextCount, isCompleted = isNowCompleted)
            } else {
                bounty
            }
        }
        _dailyBounties.value = updatedList
    }
}

data class DailyBounty(
    val id: String,
    val title: String,
    val description: String,
    val category: String,
    val targetCount: Int,
    var currentCount: Int,
    val xpReward: Int,
    val isCompleted: Boolean = false
)


