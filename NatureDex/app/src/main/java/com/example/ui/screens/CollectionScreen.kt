package com.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.TravelExplore
import androidx.compose.material.icons.filled.Download
import androidx.compose.material3.*
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import coil.ImageLoader
import coil.request.ImageRequest
import coil.request.SuccessResult
import androidx.compose.runtime.*
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.core.EaseOutCubic
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.data.CapturedCreature
import com.example.ui.viewmodel.NatureDexViewModel
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun CollectionScreen(viewModel: NatureDexViewModel) {
    val capturedList by viewModel.capturedList.collectAsState()

    val categories = listOf("Animals", "Birds", "Fish", "Insects", "Reptiles", "Plants")

    // Calculate completions percentages
    // Let's assume 4 species exist in catalog for each category as native baseline!
    val completionStats = categories.associateWith { category ->
        val caughtCount = capturedList.count { it.category.equals(category, ignoreCase = true) }
        val pct = if (caughtCount >= 4) 100 else caughtCount * 25
        pct
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // --- HEADER ---
        item {
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    text = "WILDLIFE JOURNAL",
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Black,
                    color = Color(0xFF2D6A4F),
                    letterSpacing = 1.sp
                )
                Text(
                    text = "Your personalized historic discoveries ledger",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
        }

        // --- COMPLETION PROGRESS STATS ---
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = com.example.ui.theme.VibrantSoftGreenHighlight)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "DISCOVERY COMPLETION RATES",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = com.example.ui.theme.VibrantHeaderGreen,
                        letterSpacing = 1.sp
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    completionStats.forEach { (cat, percent) ->
                        val animatedProgress by animateFloatAsState(
                            targetValue = percent / 100f,
                            animationSpec = tween(500, easing = FastOutSlowInEasing),
                            label = "progress_$cat"
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(vertical = 4.dp)
                        ) {
                            Text(
                                text = cat,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = com.example.ui.theme.VibrantHeaderGreen,
                                modifier = Modifier.width(80.dp)
                            )

                            LinearProgressIndicator(
                                progress = { animatedProgress },
                                modifier = Modifier
                                    .weight(1f)
                                    .height(6.dp)
                                    .clip(RoundedCornerShape(3.dp)),
                                color = com.example.ui.theme.VibrantAccentMint,
                                trackColor = com.example.ui.theme.PaleGreen
                            )

                            Spacer(modifier = Modifier.width(8.dp))

                            Text(
                                text = "$percent%",
                                fontSize = 12.sp,
                                color = com.example.ui.theme.VibrantHeaderGreen,
                                fontWeight = FontWeight.Black
                            )
                        }
                    }
                }
            }
        }

        // --- CAPTURED LOG LIST ---
        if (capturedList.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 48.dp),
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
                Text(
                    text = "CATALOGED SPECIMENS (${capturedList.size})",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                    letterSpacing = 1.sp
                )
            }

            items(capturedList, key = { it.id }) { creature ->
                CapturedItemRow(creature = creature)
            }
        }
    }
}

@Composable
fun CapturedItemRow(creature: CapturedCreature) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val dateStr = remember(creature.dateCaptured) {
        val sdf = SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault())
        sdf.format(Date(creature.dateCaptured))
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, com.example.ui.theme.PaleGreen)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Captured creature photo
            AsyncImage(
                model = creature.imageUrl,
                contentDescription = creature.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(95.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .border(1.dp, com.example.ui.theme.PaleGreen, RoundedCornerShape(16.dp))
            )

            Spacer(modifier = Modifier.width(16.dp))

            // Main details block
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = creature.name,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = com.example.ui.theme.VibrantHeaderGreen,
                        modifier = Modifier.weight(1f)
                    )

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        val coroutineScope = rememberCoroutineScope()
                        var isSaving by remember { mutableStateOf(false) }

                        IconButton(
                            onClick = {
                                if (!isSaving) {
                                    isSaving = true
                                    coroutineScope.launch {
                                        try {
                                            val bitmap = loadBitmapFromUrl(context, creature.imageUrl)
                                            if (bitmap != null) {
                                                val savedUri = saveImageToGallery(context, bitmap)
                                                if (savedUri != null) {
                                                    android.widget.Toast.makeText(context, "Saved to Photos!", android.widget.Toast.LENGTH_SHORT).show()
                                                } else {
                                                    android.widget.Toast.makeText(context, "Failed to save image", android.widget.Toast.LENGTH_SHORT).show()
                                                }
                                            } else {
                                                android.widget.Toast.makeText(context, "Unable to load image", android.widget.Toast.LENGTH_SHORT).show()
                                            }
                                        } catch (e: Exception) {
                                            android.widget.Toast.makeText(context, "Error: ${e.message}", android.widget.Toast.LENGTH_SHORT).show()
                                        } finally {
                                            isSaving = false
                                        }
                                    }
                                }
                            },
                            modifier = Modifier.size(28.dp)
                        ) {
                            if (isSaving) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(16.dp),
                                    strokeWidth = 2.dp,
                                    color = com.example.ui.theme.VibrantHeaderGreen
                                )
                            } else {
                                Icon(
                                    imageVector = Icons.Default.Download,
                                    contentDescription = "Save Photo",
                                    tint = com.example.ui.theme.VibrantHeaderGreen,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }

                        Box(
                            modifier = Modifier
                                .background(com.example.ui.theme.VibrantSoftGreenHighlight, RoundedCornerShape(8.dp))
                                .border(1.dp, com.example.ui.theme.VibrantAccentMint.copy(alpha = 0.4f), RoundedCornerShape(8.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = creature.category.uppercase(),
                                fontSize = 8.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = com.example.ui.theme.VibrantHeaderGreen,
                                letterSpacing = 0.5.sp
                            )
                        }
                    }
                }

                Text(
                    text = creature.scientificName,
                    fontSize = 12.sp,
                    fontStyle = FontStyle.Italic,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Date stamp
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(bottom = 2.dp)
                ) {
                    Icon(
                        Icons.Default.CalendarToday,
                        contentDescription = null,
                        modifier = Modifier.size(10.dp),
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = dateStr,
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }

                // GPS Location coordinates
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(bottom = 2.dp)
                ) {
                    Icon(
                        Icons.Default.LocationOn,
                        contentDescription = null,
                        modifier = Modifier.size(10.dp),
                        tint = Color(0xFFE76F51)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = rememberAddressText(creature.latitude, creature.longitude),
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }

                // Tool utilized statement
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Info,
                        contentDescription = null,
                        modifier = Modifier.size(10.dp),
                        tint = Color(0xFF52B788)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Captured with: ${creature.capturedWithTool}",
                        fontSize = 10.sp,
                        color = Color(0xFF2D6A4F),
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

suspend fun loadBitmapFromUrl(context: android.content.Context, url: String): Bitmap? {
    return kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
        try {
            val loader = ImageLoader(context)
            val request = ImageRequest.Builder(context)
                .data(url)
                .allowHardware(false)
                .build()
            val result = loader.execute(request)
            if (result is SuccessResult) {
                (result.drawable as? BitmapDrawable)?.bitmap
            } else {
                null
            }
        } catch (e: Exception) {
            android.util.Log.e("NatureDex", "Failed to load bitmap from url: $url", e)
            null
        }
    }
}

fun getAddressFromLocation(context: android.content.Context, latitude: Double, longitude: Double): String {
    return try {
        val geocoder = android.location.Geocoder(context, java.util.Locale.getDefault())
        val addresses = geocoder.getFromLocation(latitude, longitude, 1)
        if (!addresses.isNullOrEmpty()) {
            val address = addresses[0]
            val city = address.locality ?: address.subAdminArea ?: address.adminArea
            if (!city.isNullOrBlank()) {
                String.format(java.util.Locale.US, "GPS: %.4f, %.4f (%s)", latitude, longitude, city)
            } else {
                String.format(java.util.Locale.US, "GPS: %.4f, %.4f", latitude, longitude)
            }
        } else {
            String.format(java.util.Locale.US, "GPS: %.4f, %.4f", latitude, longitude)
        }
    } catch (e: Exception) {
        String.format(java.util.Locale.US, "GPS: %.4f, %.4f", latitude, longitude)
    }
}

@Composable
fun rememberAddressText(latitude: Double, longitude: Double): String {
    val context = androidx.compose.ui.platform.LocalContext.current
    var addressText by remember(latitude, longitude) {
        mutableStateOf(String.format(java.util.Locale.US, "GPS: %.4f, %.4f", latitude, longitude))
    }
    LaunchedEffect(latitude, longitude) {
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val resolved = getAddressFromLocation(context, latitude, longitude)
            addressText = resolved
        }
    }
    return addressText
}
