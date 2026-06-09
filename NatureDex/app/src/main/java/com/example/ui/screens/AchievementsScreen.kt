package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.core.EaseOutCubic
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.CompletedAchievement
import com.example.ui.viewmodel.NatureDexViewModel
import java.text.SimpleDateFormat
import java.util.*

data class AchievementDefinition(
    val id: String,
    val title: String,
    val description: String,
    val points: Int,
    val icon: ImageVector,
    val checkProgress: () -> Pair<Int, Int> // (Current, Target)
)

@Composable
fun AchievementsScreen(viewModel: NatureDexViewModel) {
    val completedAchievements by viewModel.completedAchievements.collectAsState()
    val playerStats by viewModel.playerStats.collectAsState()
    val capturedList by viewModel.capturedList.collectAsState()

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

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // --- HEADER PROFILE CARD ---
        item {
            Card(
                modifier = Modifier.fillMaxWidth().testTag("achievements_profile_card"),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = com.example.ui.theme.VibrantSoftGreenHighlight),
                border = androidx.compose.foundation.BorderStroke(1.dp, com.example.ui.theme.PaleGreen)
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
                            .background(com.example.ui.theme.VibrantAccentMint, CircleShape),
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
                            color = com.example.ui.theme.VibrantHeaderGreen,
                            letterSpacing = 1.sp
                        )
                        Text(
                            text = "Rarity Level: Gold Rank",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Black,
                            color = com.example.ui.theme.VibrantHeaderGreen
                        )
                        Text(
                            text = "Unlocked: ${completedAchievements.size}/${achievementDefinitions.size} Badges",
                            fontSize = 13.sp,
                            color = com.example.ui.theme.VibrantHeaderGreen.copy(alpha = 0.7f),
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }

        // --- SECTION LABELS ---
        item {
            Text(
                text = "EXPLORATION PATH BADGES",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                letterSpacing = 1.sp,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        // --- LIST SPECIFIC ACHIEVEMENTS ---
        items(achievementDefinitions, key = { it.id }) { ach ->
            val unlockedEntry = completedAchievements.find { it.achievementId == ach.id }
            val isUnlocked = unlockedEntry != null
            val (currentProgress, targetProgress) = ach.checkProgress()

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

@Composable
fun AchievementBadgeRow(
    definition: AchievementDefinition,
    unlockedAt: Long?,
    isUnlocked: Boolean,
    currentProgress: Int,
    targetProgress: Int
) {
    val dateUnlockedStr = remember(unlockedAt) {
        if (unlockedAt != null) {
            val sdf = SimpleDateFormat("dd MMM yyyy", Locale.getDefault())
            "Unlocked - " + sdf.format(Date(unlockedAt))
        } else ""
    }

    val cardScale by animateFloatAsState(
        targetValue = if (isUnlocked) 1f else 0.98f,
        animationSpec = if (isUnlocked) spring(dampingRatio = Spring.DampingRatioLowBouncy, stiffness = Spring.StiffnessHigh) else tween(150),
        label = "unlockScale"
    )
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                scaleX = cardScale
                scaleY = cardScale
            }
            .testTag("achievement_card_${definition.title.lowercase().replace(" ", "_")}"),
        border = androidx.compose.foundation.BorderStroke(
            width = 1.dp,
            color = if (isUnlocked) com.example.ui.theme.VibrantAccentMint else Color(0xFFE2E8F0)
        ),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isUnlocked) com.example.ui.theme.VibrantSoftGreenHighlight else Color.White
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Icon layout
            Box(
                modifier = Modifier
                    .size(54.dp)
                    .background(
                        if (isUnlocked) com.example.ui.theme.VibrantHeaderGreen else Color(0xFFEDF2F7),
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = if (isUnlocked) definition.icon else Icons.Default.Lock,
                    contentDescription = null,
                    tint = if (isUnlocked) Color.White else Color(0xFFA0AEC0),
                    modifier = Modifier.size(24.dp)
                )
            }

            Spacer(modifier = Modifier.width(16.dp))

            // Text Description layout
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = definition.title,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (isUnlocked) com.example.ui.theme.VibrantHeaderGreen else Color.Gray
                    )

                    Text(
                        text = "+${definition.points} PTS",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = if (isUnlocked) com.example.ui.theme.VibrantHeaderGreen else Color.Gray
                    )
                }

                Text(
                    text = definition.description,
                    fontSize = 12.sp,
                    color = if (isUnlocked) com.example.ui.theme.VibrantHeaderGreen.copy(alpha = 0.8f) else Color.Gray,
                    lineHeight = 16.sp,
                    modifier = Modifier.padding(vertical = 4.dp)
                )

                // Render dynamic progress bars
                val barProgress = currentProgress / targetProgress.toFloat()
                val animatedProgress by animateFloatAsState(
                    targetValue = barProgress,
                    animationSpec = tween(700, easing = EaseOutCubic),
                    label = "achievementProgress"
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(top = 4.dp)
                ) {
                    LinearProgressIndicator(
                        progress = { animatedProgress },
                        modifier = Modifier
                            .weight(1f)
                            .height(6.dp)
                            .clip(CircleShape),
                        color = if (isUnlocked) com.example.ui.theme.VibrantHeaderGreen else Color(0xFFA0AEC0),
                        trackColor = if (isUnlocked) com.example.ui.theme.PaleGreen else Color(0xFFEDF2F7)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "$currentProgress/$targetProgress",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (isUnlocked) com.example.ui.theme.VibrantHeaderGreen else Color.Gray
                    )
                }

                if (isUnlocked) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = dateUnlockedStr,
                        fontSize = 10.sp,
                        color = com.example.ui.theme.VibrantAccentMint,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}
