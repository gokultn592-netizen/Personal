package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import java.util.Locale
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.data.DefaultSpecies
import com.example.ui.viewmodel.NatureDexViewModel

@Composable
fun SpeciesDetailScreen(
    species: DefaultSpecies,
    viewModel: NatureDexViewModel,
    onBack: () -> Unit
) {
    val wishlist by viewModel.wishlist.collectAsState()
    val isWishlisted = wishlist.any { it.speciesId == species.id }
    val scrollState = rememberScrollState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
        ) {
            // --- TOP HERO IMAGE ---
            val heroAlpha = 1f - (scrollState.value / 600f).coerceIn(0f, 1f)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(350.dp)
                    .graphicsLayer {
                        translationY = scrollState.value * 0.4f
                        alpha = heroAlpha
                    }
            ) {
                AsyncImage(
                    model = species.imageUrl,
                    contentDescription = species.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                // Shadow Gradient Bottom Overlay
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Transparent,
                                    Color.Black.copy(alpha = 0.8f)
                                )
                            )
                        )
                )

                // Species Title on Image
                Column(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(20.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .background(Color(0xFF2D6A4F), RoundedCornerShape(8.dp))
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = species.category.uppercase(),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = species.name,
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Black,
                        color = Color.White
                    )

                    Text(
                        text = species.scientificName,
                        fontSize = 18.sp,
                        fontStyle = FontStyle.Italic,
                        color = Color.White.copy(alpha = 0.8f)
                    )
                }
            }

            // --- BOTTOM CONTENT CARD ---
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                shape = RoundedCornerShape(24.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp)
                ) {
                    // --- SPECIES HIGHLIGHT BADGES ---
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Rarity Status
                        Column {
                            Text(
                                "RARITY",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            RarityBadge(rarity = species.rarity)
                        }

                        // Threat to human status
                        Column {
                            Text(
                                "THREAT TO HUMANS",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            ThreatLevelBadgeDetail(threat = species.threatLevel)
                        }

                        // IUCN status
                        Column {
                            Text(
                                "IUCN RED LIST",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            IucnStatusBadge(status = species.iucnStatus)
                        }
                    }

                    HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))

                    // --- TAXONOMY METRICS ---
                    SectionHeader(title = "Environmental Details")

                    Spacer(modifier = Modifier.height(10.dp))

                    MetricRow(label = "Habitat", value = species.habitat)
                    MetricRow(label = "Dietary preference", value = species.diet)
                    MetricRow(label = "Natural Distribution", value = species.distribution)

                    HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))

                    // --- IN-DEPTH FUN FACTS ---
                    SectionHeader(title = "Fascinating Facts")

                    Spacer(modifier = Modifier.height(12.dp))

                    species.funFacts.forEachIndexed { index, fact ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            verticalAlignment = Alignment.Top
                        ) {
                            Text(
                                text = "${index + 1}.",
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF2D6A4F),
                                modifier = Modifier.width(24.dp),
                                fontSize = 14.sp
                            )
                            Text(
                                text = fact,
                                fontSize = 14.sp,
                                lineHeight = 20.sp,
                                modifier = Modifier.weight(1f),
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    // --- WISHLIST ACTION BUTTON ---
                    Button(
                        onClick = { viewModel.toggleWishlist(species) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp)
                            .testTag("detail_wishlist_button"),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isWishlisted) Color.Red.copy(alpha = 0.1f) else Color(0xFF2D6A4F),
                            contentColor = if (isWishlisted) Color.Red else Color.White
                        )
                    ) {
                        Icon(
                            imageVector = if (isWishlisted) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = if (isWishlisted) "Remove from Wishlist" else "Save to Wishlist",
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                    }
                }
            }
        }

        // --- BACK NAVIGATION ICON ---
        IconButton(
            onClick = onBack,
            modifier = Modifier
                .padding(top = 40.dp, start = 16.dp)
                .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
                .size(40.dp)
        ) {
            Icon(
                Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Navigate Back",
                tint = Color.White
            )
        }

        // --- TTS AUDIO GUIDE ICON ---
        var tts: android.speech.tts.TextToSpeech? by remember { mutableStateOf(null) }
        var isTtsLoading by remember { mutableStateOf(false) }
        val context = androidx.compose.ui.platform.LocalContext.current

        DisposableEffect(Unit) {
            onDispose {
                tts?.stop()
                tts?.shutdown()
            }
        }

        IconButton(
            onClick = {
                if (tts == null) {
                    isTtsLoading = true
                    tts = android.speech.tts.TextToSpeech(context) { status ->
                        isTtsLoading = false
                        if (status == android.speech.tts.TextToSpeech.SUCCESS) {
                            tts?.language = Locale.US
                            val factsStr = species.funFacts.joinToString(". ")
                            val textToSpeak = "${species.name}, scientifically classified as ${species.scientificName}. It resides in ${species.habitat} habitats and prefers a ${species.diet} diet. Fun facts: $factsStr"
                            tts?.speak(textToSpeak, android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, null)
                        } else {
                            android.widget.Toast.makeText(context, "TTS failed to initialize", android.widget.Toast.LENGTH_SHORT).show()
                        }
                    }
                } else {
                    val factsStr = species.funFacts.joinToString(". ")
                    val textToSpeak = "${species.name}, scientifically classified as ${species.scientificName}. It resides in ${species.habitat} habitats and prefers a ${species.diet} diet. Fun facts: $factsStr"
                    tts?.speak(textToSpeak, android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, null)
                }
            },
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 40.dp, end = 16.dp)
                .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
                .size(40.dp)
        ) {
            if (isTtsLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                    color = Color.White
                )
            } else {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.VolumeUp,
                    contentDescription = "Speak Details",
                    tint = Color.White
                )
            }
        }
    }
}

@Composable
fun SectionHeader(title: String) {
    Text(
        text = title,
        fontSize = 18.sp,
        fontWeight = FontWeight.ExtraBold,
        letterSpacing = 0.5.sp,
        color = Color(0xFF2D6A4F)
    )
}

@Composable
fun MetricRow(label: String, value: String) {
    Column(modifier = Modifier.padding(bottom = 8.dp)) {
        Text(
            text = label.uppercase(),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
        )
        Text(
            text = value,
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
fun ThreatLevelBadgeDetail(threat: String) {
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
            .background(bgColor, RoundedCornerShape(8.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp)
    ) {
        Text(
            text = threat,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

@Composable
fun IucnStatusBadge(status: String) {
    val bgColor = when {
        status.contains("Extinct") -> Color.Black
        status.contains("Critically") -> Color(0xFF7A0404)
        status.contains("Endangered") -> Color(0xFFD62828)
        status.contains("Vulnerable") -> Color(0xFFF4A261)
        status.contains("Threatened") -> Color(0xFFE9C46A)
        else -> Color(0xFF2A9D8F)
    }

    Box(
        modifier = Modifier
            .background(bgColor, RoundedCornerShape(8.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp)
    ) {
        Text(
            text = status,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}
