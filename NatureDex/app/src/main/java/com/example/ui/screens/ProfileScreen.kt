package com.example.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.automirrored.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.ui.viewmodel.NatureDexViewModel
import com.example.ui.theme.*
import com.example.data.CapturedCreature
import com.example.data.CompletedAchievement
import android.content.Context
import android.content.ContextWrapper
import androidx.fragment.app.FragmentActivity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun ProfileScreen(viewModel: NatureDexViewModel) {
    val isGoogleSignedIn by viewModel.isGoogleSignedIn.collectAsState()
    val explorerName by viewModel.explorerName.collectAsState()
    val isSoundMuted by viewModel.isSoundMuted.collectAsState()
    val capturedList by viewModel.capturedList.collectAsState()
    val playerStats by viewModel.playerStats.collectAsState()
    val completedAchievements by viewModel.completedAchievements.collectAsState()
    val onlineLeaderboard by viewModel.onlineLeaderboard.collectAsState()
    val userRole by viewModel.userRole.collectAsState()
    val isDeveloperMode by viewModel.isDeveloperMode.collectAsState()
    val isArEnabled by viewModel.isArEnabled.collectAsState()
    val isBiometricLockEnabled by viewModel.isBiometricLockEnabled.collectAsState()
    val wishlist by viewModel.wishlist.collectAsState()
    var isCollectionUnlocked by remember { mutableStateOf(false) }

    val context = androidx.compose.ui.platform.LocalContext.current
    var showWipeConfirm by remember { mutableStateOf(false) }
    var selectedSubTab by remember { mutableIntStateOf(0) }

    LaunchedEffect(selectedSubTab) {
        if (selectedSubTab != 0) {
            isCollectionUnlocked = false
        }
    }

    LaunchedEffect(Unit) {
        viewModel.fetchFirestoreLeaderboard()
        viewModel.refreshUserProfile()
    }

    // Firebase state details
    val currentUser = FirebaseAuth.getInstance().currentUser
    val userEmail = currentUser?.email ?: if (currentUser?.isAnonymous == true) "Anonymous Mode" else "gokul@gmail.com"
    val userPhotoUrl = currentUser?.photoUrl?.toString() ?: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150"

    val authLauncher = rememberLauncherForActivityResult(
        contract = androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
            try {
                val account = task.getResult(ApiException::class.java)!!
                val credential = GoogleAuthProvider.getCredential(account.idToken, null)
                viewModel.signInWithFirebaseCredential(
                    credential = credential,
                    onSuccess = {
                        android.widget.Toast.makeText(context, "Welcome ${account.displayName}!", android.widget.Toast.LENGTH_SHORT).show()
                    },
                    onFailure = { e ->
                        android.widget.Toast.makeText(context, "Firebase Sign-In failed: ${e.localizedMessage}", android.widget.Toast.LENGTH_LONG).show()
                    }
                )
            } catch (e: Exception) {
                android.widget.Toast.makeText(context, "Google Sign-In failed: ${e.localizedMessage}", android.widget.Toast.LENGTH_LONG).show()
            }
        }
    }

    fun signInAnonymously() {
        FirebaseAuth.getInstance().signInAnonymously()
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    android.widget.Toast.makeText(context, "Signed in anonymously to Firebase (No client ID config found)", android.widget.Toast.LENGTH_LONG).show()
                } else {
                    android.widget.Toast.makeText(context, "Firebase anonymous sign-in failed: ${task.exception?.localizedMessage}", android.widget.Toast.LENGTH_LONG).show()
                }
            }
    }

    fun triggerSignIn() {
        val webClientId = com.example.BuildConfig.GOOGLE_WEB_CLIENT_ID
        if (webClientId.isNotEmpty() && !webClientId.contains("YOUR_")) {
            try {
                val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                    .requestIdToken(webClientId)
                    .requestEmail()
                    .build()
                val client = GoogleSignIn.getClient(context, gso)
                client.signOut().addOnCompleteListener {
                    val intent = client.signInIntent
                    authLauncher.launch(intent)
                }
            } catch (e: Exception) {
                signInAnonymously()
            }
        } else {
            signInAnonymously()
        }
    }

    if (showWipeConfirm) {
        AlertDialog(
            onDismissRequest = { showWipeConfirm = false },
            title = { Text("Wipe Data?", fontWeight = FontWeight.Bold) },
            text = { Text("Are you absolutely sure you want to clear your collection, achievements, and stats? This cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.wipeData()
                        showWipeConfirm = false
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = Color.Red)
                ) {
                    Text("Wipe Everything")
                }
            },
            dismissButton = {
                TextButton(onClick = { showWipeConfirm = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    val achievementDefinitions = remember(capturedList) {
        listOf(
            AchievementDefinition(
                id = "first_catch",
                title = "First Catch",
                description = "Successfully capture your very first real-world wildlife discovery specimen.",
                points = 100,
                icon = Icons.Default.EmojiEvents,
                checkProgress = { if (capturedList.isNotEmpty()) 1 to 1 else 0 to 1 }
            ),
            AchievementDefinition(
                id = "bird_watcher",
                title = "Bird Watcher",
                description = "Capture an impressive record of 10 wild bird species.",
                points = 400,
                icon = Icons.Default.FlutterDash,
                checkProgress = {
                    val count = capturedList.count { it.category == "Birds" }
                    count.coerceAtMost(10) to 10
                }
            ),
            AchievementDefinition(
                id = "survived_cobra",
                title = "Survived a Cobra",
                description = "Face down and successfully capture a deadly, venomous Spectacled Cobra.",
                points = 500,
                icon = Icons.Default.PriorityHigh,
                checkProgress = {
                    val met = capturedList.any { it.name.contains("Cobra", ignoreCase = true) }
                    if (met) 1 to 1 else 0 to 1
                }
            ),
            AchievementDefinition(
                id = "tamil_nadu_explorer",
                title = "Tamil Nadu Explorer",
                description = "Discover a total of 20 wild species within the Tamil Nadu region boundaries.",
                points = 600,
                icon = Icons.Default.Map,
                checkProgress = {
                    val tnCount = capturedList.count { it.latitude in 8.0..14.0 && it.longitude in 75.0..82.0 }
                    tnCount.coerceAtMost(20) to 20
                }
            ),
            AchievementDefinition(
                id = "insect_dex",
                title = "Complete Insect Dex",
                description = "Successfully catalog 5 unique insect crawlers or flyers in your area.",
                points = 300,
                icon = Icons.Default.BugReport,
                checkProgress = {
                    val count = capturedList.count { it.category == "Insects" }
                    count.coerceAtMost(5) to 5
                }
            ),
            AchievementDefinition(
                id = "night_hunter",
                title = "Night Hunter",
                description = "Scout, track down, and capture a wild specimen after 9:00 PM local time.",
                points = 300,
                icon = Icons.Default.ModeNight,
                checkProgress = {
                    val met = capturedList.any {
                        val cal = Calendar.getInstance().apply { timeInMillis = it.dateCaptured }
                        cal.get(Calendar.HOUR_OF_DAY) >= 21 || cal.get(Calendar.HOUR_OF_DAY) < 5
                    }
                    if (met) 1 to 1 else 0 to 1
                }
            ),
            AchievementDefinition(
                id = "rare_find",
                title = "Rare Find",
                description = "Encounter and capture a critically endangered list or Legendary wild species.",
                points = 800,
                icon = Icons.Default.Star,
                checkProgress = {
                    val met = capturedList.any { it.rarity == "Legendary" || it.rarity == "Rare" }
                    if (met) 1 to 1 else 0 to 1
                }
            )
        )
    }

    val leaderboardEntries = remember(explorerName, capturedList.size, playerStats.level, onlineLeaderboard) {
        val filteredOnline = onlineLeaderboard.filter { !it.isUser }
        val userEntry = LeaderboardEntry(explorerName, playerStats.level, capturedList.size, isUser = true)
        (filteredOnline + userEntry)
            .distinctBy { it.name.lowercase() }
            .sortedWith(compareByDescending<LeaderboardEntry> { it.catches }.thenByDescending { it.level })
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // --- 1. HEADER BANNER ---
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(bottomStart = 32.dp, bottomEnd = 32.dp))
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(VibrantHeaderGreen, ForestGreen)
                        )
                    )
                    .padding(top = 28.dp, bottom = 20.dp, start = 20.dp, end = 20.dp)
            ) {
                Column {
                    Text(
                        text = "EXPLORER PROFILE",
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Black,
                        color = Color.White,
                        letterSpacing = 1.5.sp
                    )
                    Text(
                        text = "Manage your account, settings & achievements",
                        fontSize = 12.sp,
                        color = VibrantLightMintLabel,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }

        // --- 2. GOOGLE CARD & EDIT NAME ---
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("google_account_card"),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        if (isGoogleSignedIn) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                // Real Google/Firebase Profile Photo
                                AsyncImage(
                                    model = userPhotoUrl,
                                    contentDescription = "Profile Photo",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .size(60.dp)
                                        .clip(CircleShape)
                                        .border(2.dp, VibrantAccentMint, CircleShape)
                                )

                                Spacer(modifier = Modifier.width(16.dp))

                                Column(modifier = Modifier.weight(1f)) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        Text(
                                            text = "Google Account",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = VibrantHeaderGreen
                                        )
                                        Box(
                                            modifier = Modifier
                                                .background(VibrantSoftGreenHighlight, RoundedCornerShape(4.dp))
                                                .padding(horizontal = 4.dp, vertical = 2.dp)
                                        ) {
                                            Text(
                                                text = "SIGNED IN",
                                                fontSize = 8.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = VibrantHeaderGreen
                                            )
                                        }
                                    }

                                    Text(
                                        text = userEmail,
                                        fontSize = 13.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )

                                    Spacer(modifier = Modifier.height(4.dp))

                                    // Explorer Name Text Field (Edit inline)
                                    OutlinedTextField(
                                        value = explorerName,
                                        onValueChange = { viewModel.setExplorerName(it) },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(52.dp)
                                            .testTag("explorer_name_input"),
                                        placeholder = { Text("Enter explorer name...") },
                                        leadingIcon = {
                                            Icon(
                                                Icons.Default.Edit,
                                                contentDescription = "Edit Name",
                                                modifier = Modifier.size(16.dp),
                                                tint = VibrantHeaderGreen
                                            )
                                        },
                                        colors = OutlinedTextFieldDefaults.colors(
                                            focusedBorderColor = VibrantHeaderGreen,
                                            unfocusedBorderColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f),
                                            focusedContainerColor = Color.Transparent,
                                            unfocusedContainerColor = Color.Transparent
                                        ),
                                        shape = RoundedCornerShape(10.dp),
                                        singleLine = true
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            // Sign Out Button
                            Button(
                                onClick = { viewModel.setGoogleSignedIn(false) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(40.dp)
                                    .testTag("btn_sign_out"),
                                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.errorContainer, contentColor = MaterialTheme.colorScheme.onErrorContainer),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(
                                    Icons.AutoMirrored.Filled.Logout,
                                    contentDescription = "Sign Out",
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Sign Out of Google Account", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        } else {
                            // Signed Out state UI
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(60.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        Icons.Default.AccountCircle,
                                        contentDescription = "No Account",
                                        modifier = Modifier.size(40.dp),
                                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                                    )
                                }

                                Spacer(modifier = Modifier.width(16.dp))

                                Column {
                                    Text(
                                        text = "Google Account",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "Sign in to backup details & compete in leaderboards",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            // Sign In button
                            Button(
                                onClick = { triggerSignIn() },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(44.dp)
                                    .testTag("btn_sign_in"),
                                colors = ButtonDefaults.buttonColors(containerColor = VibrantHeaderGreen, contentColor = Color.White),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Icon(
                                    Icons.AutoMirrored.Filled.Login,
                                    contentDescription = "Sign In",
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Sign In with Google", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
        }

        // --- 3. SETTINGS & AUDIO CONTROLS ---
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("settings_card"),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "APP SETTINGS",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = VibrantHeaderGreen,
                            letterSpacing = 1.sp
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // Mute / Unmute Audio Toggle
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = if (isSoundMuted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp,
                                    contentDescription = "Sound Status",
                                    tint = if (isSoundMuted) Color.Gray else VibrantHeaderGreen,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Sound Effects & BGM",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = if (isSoundMuted) "Audio muted" else "All sound effects enabled",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }
                            Switch(
                                checked = !isSoundMuted,
                                onCheckedChange = { viewModel.setSoundMuted(!it) },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = Color.White,
                                    checkedTrackColor = VibrantAccentMint,
                                    uncheckedThumbColor = Color.LightGray,
                                    uncheckedTrackColor = Color.LightGray.copy(alpha = 0.4f)
                                )
                            )
                        }

                        HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = PaleGreen)

                        // --- AR Toggle setting row ---
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.Camera,
                                    contentDescription = "AR HUD",
                                    tint = if (!isArEnabled) Color.Gray else VibrantHeaderGreen,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "AR Silhouette Overlay",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = if (isArEnabled) "Glowing scanning HUD active" else "AR overlays disabled",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }
                            Switch(
                                checked = isArEnabled,
                                onCheckedChange = { viewModel.setArEnabled(it) },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = Color.White,
                                    checkedTrackColor = VibrantAccentMint,
                                    uncheckedThumbColor = Color.LightGray,
                                    uncheckedTrackColor = Color.LightGray.copy(alpha = 0.4f)
                                )
                            )
                        }

                        HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = PaleGreen)

                        // --- Biometric Lock setting row ---
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.Fingerprint,
                                    contentDescription = "Biometrics",
                                    tint = if (!isBiometricLockEnabled) Color.Gray else VibrantHeaderGreen,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Biometric Collection Lock",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = if (isBiometricLockEnabled) "Fingerprint/PIN required for Collection" else "Collection unlocked",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }
                            Switch(
                                checked = isBiometricLockEnabled,
                                onCheckedChange = { viewModel.setBiometricLockEnabled(it) },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = Color.White,
                                    checkedTrackColor = VibrantAccentMint,
                                    uncheckedThumbColor = Color.LightGray,
                                    uncheckedTrackColor = Color.LightGray.copy(alpha = 0.4f)
                                )
                            )
                        }

                        HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp), color = PaleGreen)

                        // Wipe Data Button
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.weight(1f)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.DeleteForever,
                                    contentDescription = "Wipe Data",
                                    tint = Color.Red,
                                    modifier = Modifier.size(24.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = "Wipe All Local Data",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color.Red
                                    )
                                    Text(
                                        text = "Reset stats, inventory & delete all captured entries",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }

                            Button(
                                onClick = { showWipeConfirm = true },
                                colors = ButtonDefaults.buttonColors(containerColor = Color.Red.copy(alpha = 0.1f), contentColor = Color.Red),
                                elevation = null,
                                border = androidx.compose.foundation.BorderStroke(1.dp, Color.Red.copy(alpha = 0.3f)),
                                shape = RoundedCornerShape(10.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Text("Wipe", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }

        // --- 3.5 DEVELOPER OPTIONS (ADMIN ONLY) ---
        if (userRole == "admin") {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("developer_options_card"),
                        shape = RoundedCornerShape(20.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF9D4EDD))
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = "DEVELOPER OPTIONS (ADMIN)",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF9D4EDD),
                                letterSpacing = 1.sp
                            )

                            Spacer(modifier = Modifier.height(12.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Default.Build,
                                        contentDescription = "Developer Mode",
                                        tint = if (isDeveloperMode) Color(0xFF9D4EDD) else Color.Gray,
                                        modifier = Modifier.size(24.dp)
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Text(
                                            text = "Developer Mode",
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.Bold
                                        )
                                        Text(
                                            text = "Unlock all pokeballs with unlimited uses",
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                        )
                                    }
                                }
                                Switch(
                                    checked = isDeveloperMode,
                                    onCheckedChange = { viewModel.setDeveloperMode(it) },
                                    colors = SwitchDefaults.colors(
                                        checkedThumbColor = Color.White,
                                        checkedTrackColor = Color(0xFF9D4EDD),
                                        uncheckedThumbColor = Color.LightGray,
                                        uncheckedTrackColor = Color.LightGray.copy(alpha = 0.4f)
                                    )
                                )
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
        }

        // --- 4. SUB-TAB BAR CONTROLLER ---
        item {
            val subTabs = listOf("Collection", "Achievements", "Leaderboard", "Favourites")
            ScrollableTabRow(
                selectedTabIndex = selectedSubTab,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = VibrantHeaderGreen,
                edgePadding = 0.dp,
                indicator = { tabPositions ->
                    TabRowDefaults.SecondaryIndicator(
                        modifier = Modifier.tabIndicatorOffset(tabPositions[selectedSubTab]),
                        color = VibrantHeaderGreen
                    )
                }
            ) {
                subTabs.forEachIndexed { index, title ->
                    Tab(
                        selected = selectedSubTab == index,
                        onClick = { selectedSubTab = index },
                        text = { Text(title, fontWeight = FontWeight.Bold, fontSize = 13.sp) }
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }

        // --- 5. DYNAMIC SUB-TAB ITEMS (SCROLLING TOGETHER) ---
        if (!isGoogleSignedIn) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = VibrantSoftGreenHighlight),
                        border = androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                    ) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(
                                Icons.Default.Lock,
                                contentDescription = "Locked Feature",
                                modifier = Modifier.size(48.dp),
                                tint = VibrantHeaderGreen
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = "Sign In Required",
                                fontWeight = FontWeight.Black,
                                fontSize = 18.sp,
                                color = VibrantHeaderGreen
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Please sign in with your Google account to view your Captured Collection, Achievements, and compete in the Leaderboards.",
                                fontSize = 13.sp,
                                color = VibrantHeaderGreen.copy(alpha = 0.8f),
                                textAlign = TextAlign.Center,
                                lineHeight = 18.sp
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(
                                onClick = { triggerSignIn() },
                                colors = ButtonDefaults.buttonColors(containerColor = VibrantHeaderGreen),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text("Sign In with Google", fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        } else {
            when (selectedSubTab) {
                0 -> {
                    // --- SUB-TAB: COLLECTION ---
                    if (isBiometricLockEnabled && !isCollectionUnlocked) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(24.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    shape = RoundedCornerShape(20.dp),
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                                ) {
                                    Column(
                                        modifier = Modifier.padding(24.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.Lock,
                                            contentDescription = "Collection Locked",
                                            modifier = Modifier.size(56.dp),
                                            tint = VibrantHeaderGreen
                                        )
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Text(
                                            text = "Wildlife Journal Locked",
                                            fontWeight = FontWeight.Black,
                                            fontSize = 18.sp,
                                            color = VibrantHeaderGreen
                                        )
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text(
                                            text = "To protect your captured species journal, biometric verification is required.",
                                            fontSize = 13.sp,
                                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                            textAlign = TextAlign.Center
                                        )
                                        Spacer(modifier = Modifier.height(16.dp))
                                        
                                        val executor = remember { androidx.core.content.ContextCompat.getMainExecutor(context) }

                                        Button(
                                            onClick = {
                                                // Resolve FragmentActivity directly from context
                                                var ctx: android.content.Context = context
                                                var fragmentActivity: androidx.fragment.app.FragmentActivity? = null
                                                while (ctx is android.content.ContextWrapper) {
                                                    if (ctx is androidx.fragment.app.FragmentActivity) {
                                                        fragmentActivity = ctx
                                                        break
                                                    }
                                                    ctx = ctx.baseContext
                                                }
                                                if (fragmentActivity != null) {
                                                    val biometricPrompt = androidx.biometric.BiometricPrompt(
                                                        fragmentActivity,
                                                        executor,
                                                        object : androidx.biometric.BiometricPrompt.AuthenticationCallback() {
                                                            override fun onAuthenticationSucceeded(result: androidx.biometric.BiometricPrompt.AuthenticationResult) {
                                                                isCollectionUnlocked = true
                                                            }
                                                            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                                                android.widget.Toast.makeText(context, "Auth error: $errString", android.widget.Toast.LENGTH_SHORT).show()
                                                            }
                                                        }
                                                    )
                                                    val promptInfo = androidx.biometric.BiometricPrompt.PromptInfo.Builder()
                                                        .setTitle("Unlock Wildlife Journal")
                                                        .setSubtitle("Authenticate to view your captured species")
                                                        .setAllowedAuthenticators(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                                                        .build()
                                                    try {
                                                        biometricPrompt.authenticate(promptInfo)
                                                    } catch (e: Exception) {
                                                        android.widget.Toast.makeText(context, "Error: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
                                                    }
                                                } else {
                                                    // Fallback: unlock without biometric if activity not resolvable
                                                    isCollectionUnlocked = true
                                                }
                                            },
                                            colors = ButtonDefaults.buttonColors(containerColor = VibrantHeaderGreen),
                                            shape = RoundedCornerShape(12.dp)
                                        ) {
                                            Text("Unlock Journal", fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        val categories = listOf("Animals", "Birds", "Fish", "Insects", "Reptiles", "Plants")
                        val completionStats = categories.associateWith { category ->
                            val caughtCount = capturedList.count { it.category.equals(category, ignoreCase = true) }
                            val pct = if (caughtCount >= 4) 100 else caughtCount * 25
                            pct
                        }

                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp)
                            ) {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    shape = RoundedCornerShape(16.dp),
                                    colors = CardDefaults.cardColors(containerColor = VibrantSoftGreenHighlight)
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Text(
                                            "DISCOVERY COMPLETION RATES",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = VibrantHeaderGreen,
                                            letterSpacing = 1.sp
                                        )

                                        Spacer(modifier = Modifier.height(12.dp))

                                        completionStats.forEach { (cat, percent) ->
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically,
                                                modifier = Modifier.padding(vertical = 4.dp)
                                            ) {
                                                Text(
                                                    text = cat,
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = VibrantHeaderGreen,
                                                    modifier = Modifier.width(80.dp)
                                                )

                                                LinearProgressIndicator(
                                                    progress = { percent / 100f },
                                                    modifier = Modifier
                                                        .weight(1f)
                                                        .height(6.dp)
                                                        .clip(RoundedCornerShape(3.dp)),
                                                    color = VibrantAccentMint,
                                                    trackColor = PaleGreen
                                                )

                                                Spacer(modifier = Modifier.width(8.dp))

                                                Text(
                                                    text = "$percent%",
                                                    fontSize = 12.sp,
                                                    color = VibrantHeaderGreen,
                                                    fontWeight = FontWeight.Black
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            Spacer(modifier = Modifier.height(16.dp))
                        }

                        if (capturedList.isEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 48.dp, horizontal = 16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Icon(
                                            Icons.Default.TravelExplore,
                                            contentDescription = "",
                                            modifier = Modifier.size(64.dp),
                                            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f)
                                        )
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Text(
                                            text = "No Captured Specimens Yet",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 16.sp
                                        )
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Text(
                                            text = "Active creatures captured via the scanner (📸) will register inside this registry.",
                                            fontSize = 12.sp,
                                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                            textAlign = TextAlign.Center,
                                            modifier = Modifier.padding(horizontal = 24.dp)
                                        )
                                    }
                                }
                            }
                        } else {
                            item {
                                Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                                    Text(
                                        text = "CATALOGED SPECIMENS (${capturedList.size})",
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                        letterSpacing = 1.sp
                                    )
                                }
                                Spacer(modifier = Modifier.height(12.dp))
                            }

                            items(capturedList.size) { index ->
                                val creature = capturedList[index]
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 16.dp, vertical = 6.dp)
                                ) {
                                    CapturedItemRow(creature = creature)
                                }
                            }
                        }
                    }
                }
                1 -> {
                    // --- SUB-TAB: ACHIEVEMENTS ---
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                        ) {
                            Card(
                                modifier = Modifier.fillMaxWidth().testTag("achievements_profile_card"),
                                shape = RoundedCornerShape(24.dp),
                                colors = CardDefaults.cardColors(containerColor = VibrantSoftGreenHighlight),
                                border = androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(20.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(70.dp)
                                            .background(VibrantAccentMint, CircleShape),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            Icons.Default.WorkspacePremium,
                                            contentDescription = null,
                                            tint = Color.White,
                                            modifier = Modifier.size(36.dp)
                                        )
                                    }

                                    Spacer(modifier = Modifier.width(16.dp))

                                    Column {
                                        Text(
                                            text = "EXPLORER PROFILE",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = VibrantHeaderGreen,
                                            letterSpacing = 1.sp
                                        )
                                        Text(
                                            text = "Rarity Level: Gold Rank",
                                            fontSize = 18.sp,
                                            fontWeight = FontWeight.Black,
                                            color = VibrantHeaderGreen
                                        )
                                        Text(
                                            text = "Unlocked: ${completedAchievements.size}/${achievementDefinitions.size} Badges",
                                            fontSize = 13.sp,
                                            color = VibrantHeaderGreen.copy(alpha = 0.7f),
                                            fontWeight = FontWeight.Medium
                                        )
                                    }
                                }
                            }
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    item {
                        Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                            Text(
                                text = "EXPLORATION PATH BADGES",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                letterSpacing = 1.sp
                            )
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    items(achievementDefinitions.size) { index ->
                        val ach = achievementDefinitions[index]
                        val unlockedEntry = completedAchievements.find { it.achievementId == ach.id }
                        val isUnlocked = unlockedEntry != null
                        val (currentProgress, targetProgress) = ach.checkProgress()

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 6.dp)
                        ) {
                            AchievementBadgeRow(
                                definition = ach,
                                unlockedAt = unlockedEntry?.unlockedAt,
                                isUnlocked = isUnlocked,
                                currentProgress = currentProgress,
                                targetProgress = targetProgress
                            )
                        }
                    }
                }
                2 -> {
                    // --- SUB-TAB: LEADERBOARD ---
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                        ) {
                            Column {
                                Text(
                                    text = "GLOBAL EXPLORER RANKINGS",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                    letterSpacing = 1.sp
                                )
                                Text(
                                    text = "Compete with legendary trainers worldwide",
                                    fontSize = 11.sp,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                                )
                            }
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                    }

                    items(leaderboardEntries.size, key = { leaderboardEntries[it].name }) { index ->
                        val entry = leaderboardEntries[index]
                        val rank = index + 1

                        val itemBg = if (entry.isUser) VibrantSoftGreenHighlight else MaterialTheme.colorScheme.surface
                        val borderStroke = if (entry.isUser) {
                            androidx.compose.foundation.BorderStroke(1.5.dp, VibrantAccentMint)
                        } else {
                            androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                        }

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 6.dp)
                        ) {
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(16.dp),
                                colors = CardDefaults.cardColors(containerColor = itemBg),
                                border = borderStroke,
                                elevation = CardDefaults.cardElevation(defaultElevation = if (entry.isUser) 3.dp else 1.dp)
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(14.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    // Rank indicator
                                    val rankBg = when (rank) {
                                        1 -> Color(0xFFFFD700) // Gold
                                        2 -> Color(0xFFC0C0C0) // Silver
                                        3 -> Color(0xFFCD7F32) // Bronze
                                        else -> if (entry.isUser) VibrantHeaderGreen else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
                                    }
                                    val rankTextColor = when (rank) {
                                        1, 2 -> Color.Black // High contrast on Gold and Silver
                                        3 -> Color.White
                                        else -> if (entry.isUser) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                                    }

                                    Box(
                                        modifier = Modifier
                                            .size(36.dp)
                                            .clip(CircleShape)
                                            .background(rankBg),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = rank.toString(),
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Black,
                                            color = rankTextColor
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(16.dp))

                                    // Avatar Initial with high contrast background
                                    Box(
                                        modifier = Modifier
                                            .size(40.dp)
                                            .clip(CircleShape)
                                            .background(
                                                if (entry.isUser) VibrantHeaderGreen else Color(0xFFE2E8F0)
                                            ),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = entry.name.firstOrNull()?.toString()?.uppercase() ?: "?",
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = if (entry.isUser) Color.White else Color.DarkGray
                                        )
                                    }

                                    Spacer(modifier = Modifier.width(12.dp))

                                    // Explorer Info
                                    Column(modifier = Modifier.weight(1f)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = entry.name,
                                                fontSize = 15.sp,
                                                fontWeight = if (entry.isUser) FontWeight.ExtraBold else FontWeight.Bold,
                                                color = if (entry.isUser) VibrantHeaderGreen else MaterialTheme.colorScheme.onSurface
                                            )
                                            if (entry.isUser) {
                                                Spacer(modifier = Modifier.width(6.dp))
                                                Box(
                                                    modifier = Modifier
                                                        .background(VibrantHeaderGreen, RoundedCornerShape(4.dp))
                                                        .padding(horizontal = 4.dp, vertical = 2.dp)
                                                ) {
                                                    Text(
                                                        text = "YOU",
                                                        fontSize = 8.sp,
                                                        color = Color.White,
                                                        fontWeight = FontWeight.Bold
                                                    )
                                                }
                                            }
                                        }

                                        Text(
                                            text = "Level ${entry.level}",
                                            fontSize = 12.sp,
                                            color = if (entry.isUser) VibrantHeaderGreen.copy(alpha = 0.8f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                        )
                                    }

                                    // Catch Count
                                    Column(horizontalAlignment = Alignment.End) {
                                        Text(
                                            text = "${entry.catches} Catches",
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Black,
                                            color = VibrantHeaderGreen
                                        )
                                        Text(
                                            text = when (rank) {
                                                 1 -> "Grand Master"
                                                 2 -> "Master Explorer"
                                                 3 -> "Veteran"
                                                 else -> "Explorer"
                                            },
                                            fontSize = 10.sp,
                                            color = if (entry.isUser) VibrantHeaderGreen.copy(alpha = 0.8f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                                            fontWeight = FontWeight.Medium
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                3 -> {
                    // --- SUB-TAB: FAVOURITES ---
                    if (wishlist.isEmpty()) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 48.dp, horizontal = 16.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Icon(
                                        Icons.Outlined.FavoriteBorder,
                                        contentDescription = "",
                                        modifier = Modifier.size(64.dp),
                                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f)
                                    )
                                    Spacer(modifier = Modifier.height(12.dp))
                                    Text(
                                        text = "No Favourites Yet",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 16.sp
                                    )
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(
                                        text = "Tap the ♥ heart icon on any species in the Index to save it as a favourite.",
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier.padding(horizontal = 24.dp)
                                    )
                                }
                            }
                        }
                    } else {
                        item {
                            Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                                Text(
                                    text = "SAVED SPECIES (${wishlist.size})",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                    letterSpacing = 1.sp
                                )
                            }
                            Spacer(modifier = Modifier.height(12.dp))
                        }

                        items(wishlist.size, key = { wishlist[it].speciesId }) { index ->
                            val item = wishlist[index]
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 6.dp)
                            ) {
                                Card(
                                    modifier = Modifier.fillMaxWidth(),
                                    shape = RoundedCornerShape(16.dp),
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                                ) {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(12.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        // Creature Image
                                        AsyncImage(
                                            model = item.imageUrl,
                                            contentDescription = item.name,
                                            contentScale = ContentScale.Crop,
                                            modifier = Modifier
                                                .size(64.dp)
                                                .clip(RoundedCornerShape(12.dp))
                                        )

                                        Spacer(modifier = Modifier.width(14.dp))

                                        // Info
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                text = item.name,
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 15.sp,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis,
                                                color = MaterialTheme.colorScheme.onSurface
                                            )
                                            Text(
                                                text = item.scientificName,
                                                fontStyle = FontStyle.Italic,
                                                fontSize = 12.sp,
                                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis
                                            )
                                            Spacer(modifier = Modifier.height(6.dp))
                                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                RarityBadge(rarity = item.rarity)
                                                ThreatBadge(threat = item.threatLevel)
                                            }
                                        }

                                        // Remove from favourites button
                                        IconButton(
                                            onClick = { viewModel.removeFromWishlist(item.speciesId) },
                                            modifier = Modifier
                                                .size(36.dp)
                                                .background(Color.Red.copy(alpha = 0.1f), CircleShape)
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Favorite,
                                                contentDescription = "Remove Favourite",
                                                tint = Color.Red,
                                                modifier = Modifier.size(18.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Add a bottom space to prevent the content from being hidden behind the bottom navigation bar
        item {
            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@androidx.annotation.Keep
data class LeaderboardEntry(
    val name: String,
    val level: Int,
    val catches: Int,
    val isUser: Boolean = false
)


