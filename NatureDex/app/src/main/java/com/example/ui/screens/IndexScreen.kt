package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.data.DefaultSpecies
import com.example.ui.viewmodel.NatureDexViewModel

@Composable
fun IndexScreen(
    viewModel: NatureDexViewModel,
    onSpeciesClick: (DefaultSpecies) -> Unit
) {
    val searchQuery by viewModel.searchQuery.collectAsState()
    val selectedCategory by viewModel.selectedCategory.collectAsState()
    val displayedSpecies by viewModel.displayedSpecies.collectAsState()
    val isSearching by viewModel.isSearching.collectAsState()
    val playerStats by viewModel.playerStats.collectAsState()
    val wishlist by viewModel.wishlist.collectAsState()

    val categories = listOf("All", "Animals", "Birds", "Fish", "Insects", "Reptiles", "Plants")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // --- TOP LANDING BANNER ---
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(bottomStart = 40.dp, bottomEnd = 40.dp))
                .background(com.example.ui.theme.VibrantHeaderGreen)
                .padding(top = 28.dp, bottom = 24.dp, start = 20.dp, end = 20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "NATUREDEX",
                        fontSize = 26.sp,
                        fontWeight = FontWeight.Black,
                        color = Color.White,
                        letterSpacing = 2.sp
                    )
                    Text(
                        text = "Tamil Nadu, IN",
                        fontSize = 13.sp,
                        color = com.example.ui.theme.VibrantLightMintLabel,
                        fontWeight = FontWeight.Bold
                    )
                }

                // Level badge stats + avatar lookalike
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Column(
                        horizontalAlignment = Alignment.End
                    ) {
                        Box(
                            modifier = Modifier
                                .background(Color(0xFF409167), RoundedCornerShape(12.dp))
                                .border(1.dp, com.example.ui.theme.VibrantAccentMint, RoundedCornerShape(12.dp))
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = "LVL ${playerStats.level}",
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            )
                        }
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "${playerStats.experience}/1000 XP",
                            color = com.example.ui.theme.VibrantLightMintLabel,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        LinearProgressIndicator(
                            progress = { playerStats.experience / 1000f },
                            modifier = Modifier
                                .width(80.dp)
                                .height(5.dp)
                                .clip(CircleShape),
                            color = com.example.ui.theme.VibrantAccentMint,
                            trackColor = Color(0xFF1B4332)
                        )
                    }

                    // Simulated interactive profile avatar circle
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.15f))
                            .border(1.dp, Color.White.copy(alpha = 0.3f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "⚡️",
                            fontSize = 16.sp
                        )
                    }
                }
            }
        }

        // --- SEARCH INPUT ---
        OutlinedTextField(
            value = searchQuery,
            onValueChange = { viewModel.setSearchQuery(it) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .testTag("index_search_input"),
            placeholder = { Text("Search by common or scientific name...") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search Icon") },
            trailingIcon = {
                if (searchQuery.isNotEmpty()) {
                    IconButton(onClick = { viewModel.setSearchQuery("") }) {
                        Icon(Icons.Default.Clear, contentDescription = "Clear text")
                    }
                }
            },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color(0xFF2D6A4F),
                unfocusedBorderColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.2f),
                focusedContainerColor = MaterialTheme.colorScheme.surface,
                unfocusedContainerColor = MaterialTheme.colorScheme.surface
            ),
            shape = RoundedCornerShape(16.dp),
            singleLine = true
        )

        // --- CATEGORIES HORIZONTAL ROW ---
        LazyRow(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(categories, key = { it }) { category ->
                val isSelected = selectedCategory == category
                val icon = when (category) {
                    "Animals" -> Icons.Default.Pets
                    "Birds" -> Icons.Default.FlutterDash
                    "Fish" -> Icons.Default.Water
                    "Insects" -> Icons.Default.BugReport
                    "Reptiles" -> Icons.Default.Coronavirus
                    "Plants" -> Icons.Default.LocalFlorist
                    else -> Icons.Default.GridView
                }

                FilterChip(
                    selected = isSelected,
                    onClick = { viewModel.setCategory(category) },
                    label = {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                icon,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp)
                            )
                            Text(category)
                        }
                    },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = com.example.ui.theme.VibrantSoftGreenHighlight,
                        selectedLabelColor = com.example.ui.theme.VibrantHeaderGreen,
                        selectedLeadingIconColor = com.example.ui.theme.VibrantHeaderGreen,
                        containerColor = MaterialTheme.colorScheme.surface,
                        labelColor = MaterialTheme.colorScheme.onSurface,
                        iconColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                    ),
                    border = FilterChipDefaults.filterChipBorder(
                        enabled = true,
                        selected = isSelected,
                        borderColor = Color.LightGray.copy(alpha = 0.5f),
                        selectedBorderColor = com.example.ui.theme.VibrantHeaderGreen,
                        borderWidth = 1.dp,
                        selectedBorderWidth = 1.5.dp
                    ),
                    shape = RoundedCornerShape(12.dp)
                )
            }
        }

        // --- RESULTS LIST CHANGER VIEW ---
        AnimatedContent(
            targetState = Triple(isSearching, displayedSpecies.isEmpty(), selectedCategory),
            transitionSpec = {
                fadeIn(tween(140, easing = FastOutSlowInEasing)) togetherWith
                fadeOut(tween(100))
            },
            label = "resultsState",
            modifier = Modifier.weight(1f)
        ) { (searching, empty, _) ->
            when {
                searching -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(color = Color(0xFF2D6A4F))
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                "Connecting to iNaturalist API...",
                                fontSize = 14.sp,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                        }
                    }
                }
                empty -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(32.dp)
                        ) {
                            Icon(
                                Icons.Default.SearchOff,
                                contentDescription = "No Results",
                                modifier = Modifier.size(64.dp),
                                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                "No creatures found",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                "Try a different taxon filter or verify connection.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                lineHeight = 16.sp
                            )
                        }
                    }
                }
                else -> {
                    // --- MAIN CREATURE GRID ---
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(displayedSpecies, key = { it.id }) { species ->
                            val isWishlisted = wishlist.any { it.speciesId == species.id }
                            SpeciesItemCard(
                                species = species,
                                isWishlisted = isWishlisted,
                                onCardClick = { onSpeciesClick(species) },
                                onWishlistToggle = { viewModel.toggleWishlist(species) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SpeciesItemCard(
    species: DefaultSpecies,
    isWishlisted: Boolean,
    onCardClick: () -> Unit,
    onWishlistToggle: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    // Snappy press animation
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.96f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = Spring.StiffnessHigh),
        label = "cardScale"
    )

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(260.dp)
            .scale(scale)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onCardClick()
                }
            )
            .testTag("species_card_${species.id}"),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = CardDefaults.cardColors().containerColor
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Image Box
                AsyncImage(
                    model = species.imageUrl,
                    contentDescription = species.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(130.dp)
                )

                // Info Section
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(10.dp)
                ) {
                    Text(
                        text = species.name,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = species.scientificName,
                        fontStyle = FontStyle.Italic,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    // Rarity Badge Row
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RarityBadge(rarity = species.rarity)
                        ThreatBadge(threat = species.threatLevel)
                    }

                    Spacer(modifier = Modifier.height(6.dp))

                    // Category Banner Indication
                    Text(
                        text = species.category.uppercase(),
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Black,
                        color = Color(0xFF2D6A4F),
                        letterSpacing = 1.sp
                    )
                }
            }

            // Top Heart Overlay Button
            IconButton(
                onClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onWishlistToggle()
                },
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(6.dp)
                    .background(Color.Black.copy(alpha = 0.4f), CircleShape)
                    .size(32.dp)
            ) {
                Icon(
                    imageVector = if (isWishlisted) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = "Toggle Wishlist",
                    tint = if (isWishlisted) Color.Red else Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

// --- HELPER COMPOSABLE BADGES ---
@Composable
fun RarityBadge(rarity: String) {
    val bgColor = when (rarity) {
        "Common" -> Color(0xFFD3D3D3)
        "Uncommon" -> Color(0xFF74C69D)
        "Rare" -> Color(0xFFF4A261)
        "Legendary" -> Color(0xFF9D4EDD)
        else -> Color.DarkGray
    }

    val textColor = if (rarity == "Common") Color.DarkGray else Color.White

    Box(
        modifier = Modifier
            .background(bgColor, RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(
            text = rarity,
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            color = textColor
        )
    }
}

@Composable
fun ThreatBadge(threat: String) {
    val bgColor = when (threat) {
        "None" -> Color(0xFF2A9D8F)
        "Low" -> Color(0xFF457B9D)
        "Medium" -> Color(0xFFE9C46A)
        "High" -> Color(0xFFE76F51)
        "Deadly" -> Color(0xFFD62828)
        else -> Color.DarkGray
    }

    Box(
        modifier = Modifier
            .background(bgColor, RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(
            text = "T: $threat",
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}
