package com.example.ui.screens

import android.location.Location
import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage
import com.example.data.CapturedCreature
import com.example.ui.viewmodel.NatureDexViewModel
import com.example.ui.theme.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient

@Composable
fun MapScreen(viewModel: NatureDexViewModel) {
    val context = LocalContext.current
    val capturedList by viewModel.capturedList.collectAsState()
    val currentLocation by viewModel.currentLocation.collectAsState()
    val currentEnvironmentalWeather by viewModel.currentEnvironmentalWeather.collectAsState()

    var selectedCategory by remember { mutableStateOf("All") }
    var selectedCreature by remember { mutableStateOf<CapturedCreature?>(null) }

    // Start tracking location on launch, stop when screen is disposed
    DisposableEffect(Unit) {
        viewModel.startTrackingLocation()
        onDispose {
            viewModel.stopTrackingLocation()
        }
    }

    var mapHtmlContent by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            try {
                val css = context.assets.open("leaflet.css").bufferedReader().use { it.readText() }
                val js = context.assets.open("leaflet.js").bufferedReader().use { it.readText() }
                var html = context.assets.open("map.html").bufferedReader().use { it.readText() }
                html = html.replace("<link rel=\"stylesheet\" href=\"leaflet.css\" />", "<style>$css</style>")
                html = html.replace("<script src=\"leaflet.js\"></script>", "<script>$js</script>")
                mapHtmlContent = html
            } catch (e: Exception) {
                android.util.Log.e("NatureDexMap", "Failed to load map assets", e)
            }
        }
    }

    val categories = listOf("All", "Animals", "Birds", "Fish", "Insects", "Reptiles", "Plants")

    val filteredList = remember(capturedList, selectedCategory) {
        if (selectedCategory == "All") {
            capturedList
        } else {
            capturedList.filter { it.category.equals(selectedCategory, ignoreCase = true) }
        }
    }

    val coroutineScope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F1E16)) // Immersive dark wild background
    ) {
        // --- 1. HEADER BANNER ---
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(bottomStart = 24.dp, bottomEnd = 24.dp))
                .background(
                    Brush.verticalGradient(
                        colors = listOf(VibrantHeaderGreen, ForestGreen)
                    )
                )
                .padding(top = 16.dp, bottom = 12.dp, start = 20.dp, end = 20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "DISCOVERY MAP",
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Black,
                        color = Color.White,
                        letterSpacing = 1.sp
                    )
                    Text(
                        text = "Weather: $currentEnvironmentalWeather | Total: ${capturedList.size} captures",
                        fontSize = 11.sp,
                        color = VibrantLightMintLabel,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }

        // --- 2. CATEGORIES FILTER BAR ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            categories.forEach { cat ->
                val isSelected = selectedCategory == cat
                Box(
                    modifier = Modifier
                        .background(
                            color = if (isSelected) VibrantAccentMint else Color(0xFF1E3A2F),
                            shape = RoundedCornerShape(12.dp)
                        )
                        .clickable { selectedCategory = cat }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = cat,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (isSelected) Color.White else VibrantLightMintLabel
                    )
                }
            }
        }

        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(start = 12.dp, top = 0.dp, end = 12.dp, bottom = 12.dp)
                .clip(RoundedCornerShape(24.dp))
                .border(2.dp, PaleGreen, RoundedCornerShape(24.dp))
                .background(Color.Black)
        ) {
            if (mapHtmlContent == null) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = VibrantAccentMint)
                }
            } else {
                var isPageLoaded by remember { mutableStateOf(false) }
                var hasCentered by remember { mutableStateOf(false) }
                var webViewRef by remember { mutableStateOf<WebView?>(null) }

                AndroidView(
                    modifier = Modifier.fillMaxSize(),
                    factory = { ctx ->
                        WebView(ctx).apply {
                            layoutParams = android.view.ViewGroup.LayoutParams(
                                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                                android.view.ViewGroup.LayoutParams.MATCH_PARENT
                            )
                            settings.javaScriptEnabled = true
                            settings.domStorageEnabled = true
                            settings.allowFileAccess = true
                            settings.allowContentAccess = true
                            settings.allowFileAccessFromFileURLs = true
                            settings.allowUniversalAccessFromFileURLs = true
                            isHorizontalScrollBarEnabled = false
                            isVerticalScrollBarEnabled = false

                            webChromeClient = object : android.webkit.WebChromeClient() {
                                override fun onConsoleMessage(consoleMessage: android.webkit.ConsoleMessage?): Boolean {
                                    android.util.Log.d("NatureDexMapWebView", "${consoleMessage?.message()} -- From line ${consoleMessage?.lineNumber()} of ${consoleMessage?.sourceId()}")
                                    return true
                                }
                            }

                            addJavascriptInterface(object {
                                @JavascriptInterface
                                fun onMarkerClicked(id: Int) {
                                    coroutineScope.launch {
                                        val creature = filteredList.find { it.id == id }
                                        selectedCreature = creature
                                    }
                                }
                            }, "AndroidBridge")

                            webViewClient = object : WebViewClient() {
                                override fun onPageFinished(view: WebView?, url: String?) {
                                    isPageLoaded = true
                                    val json = buildCreaturesJson(filteredList)
                                    val base64 = Base64.encodeToString(json.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
                                    view?.evaluateJavascript("updateMarkers(atob('$base64'))", null)

                                    val loc = currentLocation ?: Location("").apply {
                                        latitude = 13.0827
                                        longitude = 80.2707
                                    }
                                    view?.evaluateJavascript("updateUserLocation(${loc.latitude}, ${loc.longitude})", null)

                                    if (!hasCentered) {
                                        view?.evaluateJavascript("centerMap(${loc.latitude}, ${loc.longitude}, 13)", null)
                                        hasCentered = true
                                    }
                                }

                                override fun onReceivedError(
                                    view: WebView?,
                                    request: android.webkit.WebResourceRequest?,
                                    error: android.webkit.WebResourceError?
                                ) {
                                    super.onReceivedError(view, request, error)
                                    android.util.Log.e("NatureDexMapWebView", "Error loading resource: ${request?.url} - Error: ${error?.description} (${error?.errorCode})")
                                }

                                override fun onReceivedHttpError(
                                    view: WebView?,
                                    request: android.webkit.WebResourceRequest?,
                                    errorResponse: android.webkit.WebResourceResponse?
                                ) {
                                    super.onReceivedHttpError(view, request, errorResponse)
                                    android.util.Log.e("NatureDexMapWebView", "HTTP Error loading resource: ${request?.url} - Status: ${errorResponse?.statusCode}")
                                }
                            }

                            loadDataWithBaseURL("https://openstreetmap.org", mapHtmlContent!!, "text/html", "UTF-8", null)
                            webViewRef = this
                        }
                    },
                    update = { webView ->
                        if (isPageLoaded) {
                            val json = buildCreaturesJson(filteredList)
                            val base64 = Base64.encodeToString(json.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
                            webView.evaluateJavascript("updateMarkers(atob('$base64'))", null)

                             val loc = currentLocation ?: Location("").apply {
                                 latitude = 13.0827
                                 longitude = 80.2707
                             }
                             webView.evaluateJavascript("updateUserLocation(${loc.latitude}, ${loc.longitude})", null)

                             if (!hasCentered && currentLocation != null) {
                                 webView.evaluateJavascript("centerMap(${loc.latitude}, ${loc.longitude}, 13)", null)
                                 hasCentered = true
                             }
                        }
                    }
                )

                // --- 4. FLOATING LEGEND ---
                Box(
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .padding(12.dp)
                        .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(8.dp))
                        .padding(6.dp)
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text("Rarity Markers:", fontSize = 8.sp, color = Color.White, fontWeight = FontWeight.Bold)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(6.dp).background(Color(0xFF52B788), CircleShape))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Common", fontSize = 8.sp, color = Color.LightGray)
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(6.dp).background(Color(0xFF457B9D), CircleShape))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Uncommon", fontSize = 8.sp, color = Color.LightGray)
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(6.dp).background(Color(0xFFFFB703), CircleShape))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Rare", fontSize = 8.sp, color = Color.LightGray)
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(modifier = Modifier.size(6.dp).background(Color(0xFF9D4EDD), CircleShape))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Legendary", fontSize = 8.sp, color = Color.LightGray)
                        }
                    }
                }

                // --- 5. FLOATING CENTER LOCATION BUTTON ---
                IconButton(
                    onClick = {
                        val loc = currentLocation ?: Location("").apply {
                            latitude = 13.0827
                            longitude = 80.2707
                        }
                        webViewRef?.evaluateJavascript("centerMap(${loc.latitude}, ${loc.longitude}, 13)", null)
                    },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(12.dp)
                        .background(Color(0xFF0F1E16).copy(alpha = 0.8f), CircleShape)
                        .border(1.dp, PaleGreen, CircleShape)
                        .size(40.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.MyLocation,
                        contentDescription = "Center on current location",
                        tint = VibrantAccentMint,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        // --- 6. SELECTED CREATURE POPUP DETAIL CARD ---
        AnimatedVisibility(
            visible = selectedCreature != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut()
        ) {
            selectedCreature?.let { creature ->
                val dateStr = remember(creature.dateCaptured) {
                    val sdf = SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault())
                    sdf.format(Date(creature.dateCaptured))
                }

                var tts: android.speech.tts.TextToSpeech? by remember { mutableStateOf(null) }
                var isTtsLoading by remember { mutableStateOf(false) }

                DisposableEffect(Unit) {
                    onDispose {
                        tts?.stop()
                        tts?.shutdown()
                    }
                }

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 16.dp, top = 0.dp, end = 16.dp, bottom = 16.dp),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = androidx.compose.foundation.BorderStroke(1.dp, PaleGreen)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Creature image
                        AsyncImage(
                            model = creature.imageUrl,
                            contentDescription = creature.name,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(90.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .border(1.dp, PaleGreen, RoundedCornerShape(16.dp))
                        )

                        Spacer(modifier = Modifier.width(14.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = creature.name,
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = VibrantHeaderGreen
                                )

                                Box(
                                    modifier = Modifier
                                        .background(VibrantSoftGreenHighlight, RoundedCornerShape(6.dp))
                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                ) {
                                    Text(
                                        text = creature.category.uppercase(),
                                        fontSize = 7.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = VibrantHeaderGreen
                                    )
                                }
                            }

                            Text(
                                text = creature.scientificName,
                                fontSize = 11.sp,
                                fontStyle = FontStyle.Italic,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                            )

                            Spacer(modifier = Modifier.height(4.dp))

                            Text(
                                text = "Captured: $dateStr",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                            Text(
                                text = rememberAddressText(creature.latitude, creature.longitude),
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                            Text(
                                text = "Tool: ${creature.capturedWithTool} | Rarity: ${creature.rarity}",
                                fontSize = 10.sp,
                                color = Color(0xFF2D6A4F),
                                fontWeight = FontWeight.Bold
                              )
                        }

                        Spacer(modifier = Modifier.width(8.dp))

                        Column(
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            // TTS Speaker
                            IconButton(
                                onClick = {
                                    if (tts == null) {
                                        isTtsLoading = true
                                        tts = android.speech.tts.TextToSpeech(context) { status ->
                                            isTtsLoading = false
                                            if (status == android.speech.tts.TextToSpeech.SUCCESS) {
                                                tts?.language = Locale.US
                                                val textToSpeak = "${creature.name}, scientifically known as ${creature.scientificName}. This ${creature.category} has a rarity of ${creature.rarity} and was captured with a ${creature.capturedWithTool}."
                                                tts?.speak(textToSpeak, android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, null)
                                            } else {
                                                Toast.makeText(context, "TTS failed to initialize", Toast.LENGTH_SHORT).show()
                                            }
                                        }
                                    } else {
                                        val textToSpeak = "${creature.name}, scientifically known as ${creature.scientificName}. This ${creature.category} has a rarity of ${creature.rarity} and was captured with a ${creature.capturedWithTool}."
                                        tts?.speak(textToSpeak, android.speech.tts.TextToSpeech.QUEUE_FLUSH, null, null)
                                    }
                                },
                                modifier = Modifier
                                    .background(VibrantSoftGreenHighlight, CircleShape)
                                    .size(36.dp)
                            ) {
                                if (isTtsLoading) {
                                    CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = VibrantHeaderGreen)
                                } else {
                                    Icon(
                                        imageVector = Icons.Default.VolumeUp,
                                        contentDescription = "Speak Guide",
                                        tint = VibrantHeaderGreen,
                                        modifier = Modifier.size(18.dp)
                                    )
                                }
                            }

                            // Close Details Button
                            IconButton(
                                onClick = { selectedCreature = null },
                                modifier = Modifier
                                    .background(Color.LightGray.copy(alpha = 0.2f), CircleShape)
                                    .size(36.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Close details",
                                    tint = Color.Gray,
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

private fun escapeJsonString(s: String): String {
    val sb = StringBuilder()
    for (ch in s) {
        when (ch) {
            '\\' -> sb.append("\\\\")
            '"' -> sb.append("\\\"")
            '\n' -> sb.append("\\n")
            '\r' -> sb.append("\\r")
            '\t' -> sb.append("\\t")
            '\b' -> sb.append("\\b")
            '\u000C' -> sb.append("\\f")
            else -> {
                if (ch.code < 0x20) {
                    sb.append(String.format("\\u%04x", ch.code))
                } else {
                    sb.append(ch)
                }
            }
        }
    }
    return sb.toString()
}

private fun buildCreaturesJson(creatures: List<CapturedCreature>): String {
    val sb = java.lang.StringBuilder()
    sb.append("[")
    creatures.forEachIndexed { index, c ->
        if (index > 0) sb.append(",")
        val escapedName = escapeJsonString(c.name)
        val escapedRarity = escapeJsonString(c.rarity)
        sb.append("{")
        sb.append("\"id\":${c.id},")
        sb.append("\"name\":\"$escapedName\",")
        sb.append("\"rarity\":\"$escapedRarity\",")
        sb.append("\"lat\":${c.latitude},")
        sb.append("\"lng\":${c.longitude}")
        sb.append("}")
    }
    sb.append("]")
    return sb.toString()
}


