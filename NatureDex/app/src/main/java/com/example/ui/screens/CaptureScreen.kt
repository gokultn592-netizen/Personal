package com.example.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import coil.compose.AsyncImage
import com.example.data.InventoryTool
import com.example.ui.viewmodel.NatureDexViewModel
import com.example.ui.audio.SoundEffectsManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream
import java.io.OutputStream
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Environment
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.*

@Composable
fun CaptureScreen(viewModel: NatureDexViewModel) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val currentScanned by viewModel.currentScannedCreature.collectAsState()
    val scannedImageUrl by viewModel.scannedCreatureImageUrl.collectAsState()
    val isScanningAPI by viewModel.isScanningAPI.collectAsState()
    val scanningError by viewModel.scanningError.collectAsState()

    val inventoryTools by viewModel.inventoryTools.collectAsState()
    val selectedTool by viewModel.selectedTool.collectAsState()
    val captureAttempts by viewModel.captureAttempts.collectAsState()
    val captureFinished by viewModel.captureFinished.collectAsState()
    val captureResultMsg by viewModel.captureResultMsg.collectAsState()
    val lastCaptured by viewModel.lastCapturedCreature.collectAsState()
    val playerStats by viewModel.playerStats.collectAsState()
    val isArEnabled by viewModel.isArEnabled.collectAsState()
    val weather by viewModel.currentEnvironmentalWeather.collectAsState()

    // Camera, Location, Storage setup variables
    var hasCameraPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        )
    }
    var hasLocationPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        )
    }
    var hasStoragePermission by remember {
        mutableStateOf(
            if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.P) {
                ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
        )
    }

    val permissionsToRequest = remember {
        val list = mutableListOf(
            Manifest.permission.CAMERA,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.P) {
            list.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        list
    }

    val permissionsLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
        onResult = { permissions ->
            hasCameraPermission = permissions[Manifest.permission.CAMERA] ?: hasCameraPermission
            hasLocationPermission = (permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false) ||
                                    (permissions[Manifest.permission.ACCESS_COARSE_LOCATION] ?: false)
            if (android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.P) {
                hasStoragePermission = permissions[Manifest.permission.WRITE_EXTERNAL_STORAGE] ?: hasStoragePermission
            }
        }
    )

    val imageCapture = remember { ImageCapture.Builder().build() }
    val cameraExecutor = remember { Executors.newSingleThreadExecutor() }
    DisposableEffect(Unit) {
        onDispose {
            cameraExecutor.shutdown()
        }
    }

    // Pokémon Go Capture Game States
    var isAnimatingCapture by remember { mutableStateOf(false) }
    var localThrowState by remember { mutableStateOf(ThrowState.IDLE) }
    var isBallGlow by remember { mutableStateOf(false) }

    // Animatable properties for smooth visual polish
    val flightProgress = remember { Animatable(0f) }
    val bounceProgress = remember { Animatable(0f) }
    val wobbleAngle = remember { Animatable(0f) }
    val throwQualityScale = remember { Animatable(0f) }
    val throwQualityAlpha = remember { Animatable(0f) }
    val creatureScaleAnim = remember { Animatable(1f) }
    val creatureAlphaAnim = remember { Animatable(1f) }

    // Physics coordinates during flight
    var throwStartX by remember { mutableStateOf(0f) }
    var throwStartY by remember { mutableStateOf(0f) }
    var throwEndX by remember { mutableStateOf(0f) }
    var throwEndY by remember { mutableStateOf(0f) }
    var throwStartYVal by remember { mutableStateOf(0f) }
    var bounceTargetY by remember { mutableStateOf(0f) }

    // Swipe tracking
    var dragStart by remember { mutableStateOf(Offset.Zero) }
    var dragCurrent by remember { mutableStateOf(Offset.Zero) }
    var dragTime by remember { mutableStateOf(0L) }

    // Viewport coordinates
    var viewWidth by remember { mutableStateOf(0f) }
    var viewHeight by remember { mutableStateOf(0f) }

    // Throw quality message overlay
    var throwQualityText by remember { mutableStateOf("") }
    var throwQualityColor by remember { mutableStateOf(Color.White) }

    // Star particles for capture success
    var particles by remember { mutableStateOf<List<StarParticle>>(emptyList()) }

    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        val needed = permissionsToRequest.filter {
            ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
        }
        if (needed.isNotEmpty()) {
            permissionsLauncher.launch(needed.toTypedArray())
        }
    }

    LaunchedEffect(hasLocationPermission) {
        if (hasLocationPermission) {
            viewModel.updateLocation()
        }
    }

    LaunchedEffect(currentScanned) {
        if (currentScanned != null) {
            SoundEffectsManager.startBgm(context)
        } else {
            SoundEffectsManager.stopBgm()
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            SoundEffectsManager.stopBgm()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0F1E16)) // Immersive dark wild background
    ) {
        // --- TOP CAMERA SCANNING PREVIEW ---
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1.1f)
                .padding(14.dp)
                .clip(RoundedCornerShape(32.dp))
                .border(4.dp, Color.White, RoundedCornerShape(32.dp))
                .background(Color.Black)
                .onGloballyPositioned { coords ->
                    viewWidth = coords.size.width.toFloat()
                    viewHeight = coords.size.height.toFloat()
                }
        ) {
            if (hasCameraPermission) {
                // CAMERA ACTIVE STREAMS FEED
                CameraPreviewLayout(imageCapture = imageCapture)
                WeatherParticlesOverlay(weather = weather)
            } else {
                // CAMERA ACCESS DENIED STATE
                Box(
                    modifier = Modifier.fillMaxSize().padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(
                            Icons.Default.Camera,
                            contentDescription = "",
                            modifier = Modifier.size(64.dp),
                            tint = Color.Red.copy(alpha = 0.8f)
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            "Camera Permission Required",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            "Please grant camera access to scan species and discover wildlife in real-time.",
                            fontSize = 12.sp,
                            color = Color.LightGray,
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = {
                                val needed = permissionsToRequest.filter {
                                    ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED
                                }
                                if (needed.isNotEmpty()) {
                                    permissionsLauncher.launch(needed.toTypedArray())
                                }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2D6A4F))
                        ) {
                            Text("Grant Permission", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // Green Grid Lines overlay to simulate scanner look (only when not catching and scanning)
            if (currentScanned == null) {
                ScannerOverlay(isScanning = isScanningAPI, isArEnabled = isArEnabled, weather = weather)
            }

            // Scanning Status Panel
            if (isScanningAPI) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.6f)),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = Color(0xFF52B788))
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(
                            "AUTO-ANALYZING FEED VIA GEMINI VISION...",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            letterSpacing = 1.sp
                        )
                    }
                }
            }

            // SCAN/CAPTURE CONTROLS DIRECT OVERLAY BOTTOM RIGHT
            if (currentScanned == null && !isScanningAPI && hasCameraPermission) {
                Button(
                    onClick = {
                        viewModel.updateLocation()
                        captureImageAndScan(context, imageCapture, cameraExecutor, viewModel)
                    },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 20.dp)
                        .testTag("scan_camera_button"),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2D6A4F)),
                    shape = RoundedCornerShape(24.dp)
                ) {
                    Icon(Icons.Default.Camera, contentDescription = "Scan")
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("SCAN SPECIES", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }
            }

            // --- POKEMON GO STYLE GAMEPLAY OVERLAY ---
            if (currentScanned != null) {
                val specimen = currentScanned!!
                val tool = selectedTool

                val launchX = viewWidth / 2f
                val launchY = viewHeight * 0.82f
                val creatureX = viewWidth / 2f
                val creatureY = viewHeight * 0.32f
                val hitRadius = with(LocalDensity.current) { 55.dp.toPx() }

                // Bobbing animation
                val infiniteTransition = rememberInfiniteTransition(label = "creature_bob")
                val bobOffset by infiniteTransition.animateFloat(
                    initialValue = -10f,
                    targetValue = 10f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(1200, easing = LinearEasing),
                        repeatMode = RepeatMode.Reverse
                    ),
                    label = "creature_bob_offset"
                )

                // Shrinking ring animation
                val ringProgress by infiniteTransition.animateFloat(
                    initialValue = 1.0f,
                    targetValue = 0.15f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(2200, easing = LinearEasing),
                        repeatMode = RepeatMode.Restart
                    ),
                    label = "ring_progress"
                )

                // Local dynamic positions mapped from Animatable properties
                val activeBallX = when (localThrowState) {
                    ThrowState.IDLE -> launchX
                    ThrowState.DRAGGING -> launchX + dragCurrent.x
                    ThrowState.FLYING -> {
                        val t = flightProgress.value
                        (1 - t) * throwStartX + t * throwEndX
                    }
                    ThrowState.BOUNCING -> throwEndX
                    ThrowState.WOBBLING -> throwEndX
                    else -> throwEndX
                }

                val activeBallY = when (localThrowState) {
                    ThrowState.IDLE -> launchY
                    ThrowState.DRAGGING -> launchY + dragCurrent.y
                    ThrowState.FLYING -> {
                        val t = flightProgress.value
                        val peakY = minOf(throwStartYVal, throwEndY) - 180f
                        if (t < 0.5f) {
                            val u = t * 2f
                            (1 - u) * throwStartYVal + u * peakY
                        } else {
                            val u = (t - 0.5f) * 2f
                            (1 - u) * peakY + u * throwEndY
                        }
                    }
                    ThrowState.BOUNCING -> {
                        val groundY = viewHeight * 0.72f
                        throwEndY + (groundY - throwEndY) * bounceProgress.value
                    }
                    ThrowState.WOBBLING, ThrowState.SUCCESS -> viewHeight * 0.72f
                    else -> throwEndY
                }

                val activeBallScale = when (localThrowState) {
                    ThrowState.IDLE, ThrowState.DRAGGING -> 1f
                    ThrowState.FLYING -> 1f - (1f - 0.35f) * flightProgress.value
                    else -> 0.35f
                }

                val activeBallRotation = when (localThrowState) {
                    ThrowState.IDLE -> 0f
                    ThrowState.DRAGGING -> dragCurrent.x * 0.12f
                    ThrowState.FLYING -> flightProgress.value * 720f
                    ThrowState.WOBBLING -> wobbleAngle.value
                    else -> 0f
                }

                // Local Wobble / Escape helpers using Animatable
                suspend fun escapeBall() {
                    wobbleAngle.snapTo(0f)
                    bounceProgress.snapTo(0f)
                    flightProgress.snapTo(0f)

                    coroutineScope.launch {
                        creatureScaleAnim.snapTo(0f)
                        creatureAlphaAnim.snapTo(0f)
                        launch {
                            creatureScaleAnim.animateTo(1f, tween(350, easing = EaseOutBack))
                        }
                        launch {
                            creatureAlphaAnim.animateTo(1f, tween(300))
                        }
                    }
                    delay(350)
                    localThrowState = ThrowState.IDLE
                    isAnimatingCapture = false
                }

                // Reset ball position states when idle
                LaunchedEffect(localThrowState, viewWidth, viewHeight) {
                    if (localThrowState == ThrowState.IDLE) {
                        isBallGlow = false
                        wobbleAngle.snapTo(0f)
                        bounceProgress.snapTo(0f)
                        flightProgress.snapTo(0f)
                    }
                }

                Box(modifier = Modifier.fillMaxSize()) {
                    // Dismiss (Run Away) Button in top-left
                    IconButton(
                        onClick = { viewModel.resetCaptureState() },
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .padding(16.dp)
                            .background(Color.Black.copy(alpha = 0.5f), CircleShape)
                            .size(40.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Run Away",
                            tint = Color.White
                        )
                    }

                    // Floating difficulty badge
                    if (tool != null) {
                        val probability = viewModel.calculateCaptureProbability(specimen, tool)
                        val (difficultyName, difficultyColor) = when {
                            probability >= 80 -> "Guaranteed" to Color(0xFF9D4EDD) // Purple
                            probability >= 60 -> "Easy" to Color(0xFF52B788) // Green
                            probability >= 40 -> "Medium" to Color(0xFFFFB703) // Amber/Yellow
                            else -> "Hard" to Color(0xFFE63946) // Red
                        }

                        Surface(
                            shape = RoundedCornerShape(16.dp),
                            color = difficultyColor.copy(alpha = 0.2f),
                            border = androidx.compose.foundation.BorderStroke(1.5.dp, difficultyColor),
                            modifier = Modifier
                                .align(Alignment.TopCenter)
                                .padding(top = 16.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .background(difficultyColor, CircleShape)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "$difficultyName ($probability%)",
                                    color = Color.White,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }

                    // Viewport Pokéball Counter overlay in bottom-right
                    if (tool != null) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = Color.Black.copy(alpha = 0.6f),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Color.White.copy(alpha = 0.3f)),
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .padding(16.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.RadioButtonChecked,
                                    contentDescription = null,
                                    tint = when (tool.toolName) {
                                        "Poke Ball" -> Color(0xFFE63946)
                                        "Premier Ball" -> Color(0xFFF0F0F0)
                                        "Great Ball" -> Color(0xFF457B9D)
                                        "Quick Ball" -> Color(0xFF0288D1)
                                        "Ultra Ball" -> Color(0xFFFFB703)
                                        "Beast Ball" -> Color(0xFF3A86C8)
                                        "GS Ball" -> Color(0xFFE9C46A)
                                        "Master Ball" -> Color(0xFF9D4EDD)
                                        else -> Color.White
                                    },
                                    modifier = Modifier.size(16.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(
                                    text = "x${tool.usesRemaining}",
                                    color = Color.White,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }

                    // AR Specimen Locking HUD Overlay (Behind/around creature)
                    if (isArEnabled) {
                        val category = specimen.category
                        val infiniteTransition = rememberInfiniteTransition(label = "ar_hud")
                        val hudRotation by infiniteTransition.animateFloat(
                            initialValue = 0f,
                            targetValue = 360f,
                            animationSpec = infiniteRepeatable(
                                animation = tween(5000, easing = LinearEasing),
                                repeatMode = RepeatMode.Restart
                            ),
                            label = "hud_rot"
                        )
                        val auraPulse by infiniteTransition.animateFloat(
                            initialValue = 65.dp.value,
                            targetValue = 85.dp.value,
                            animationSpec = infiniteRepeatable(
                                animation = tween(1500, easing = FastOutSlowInEasing),
                                repeatMode = RepeatMode.Reverse
                            ),
                            label = "aura"
                        )

                        // Draw category specific visual energy HUD
                        val hudColor = when (category) {
                            "Animals" -> Color(0xFF52B788) // Green
                            "Birds" -> Color(0xFF74C69D)   // Mint
                            "Fish" -> Color(0xFF48CAE4)    // Blue
                            "Insects" -> Color(0xFFFFB703) // Amber Yellow
                            "Reptiles" -> Color(0xFFE76F51)// Orange-Red
                            "Plants" -> Color(0xFF2D6A4F)  // Dark Forest Green
                            else -> Color(0xFF52B788)
                        }

                        Canvas(modifier = Modifier.fillMaxSize()) {
                            val centerX = creatureX
                            val centerY = creatureY + bobOffset

                            // 1. Draw glowing background aura
                            drawCircle(
                                brush = Brush.radialGradient(
                                    colors = listOf(hudColor.copy(alpha = 0.2f), Color.Transparent),
                                    center = Offset(centerX, centerY),
                                    radius = auraPulse.dp.toPx()
                                ),
                                center = Offset(centerX, centerY),
                                radius = auraPulse.dp.toPx()
                            )

                            // 2. Draw rotating cyber rings
                            drawCircle(
                                color = hudColor.copy(alpha = 0.5f),
                                radius = 62.dp.toPx(),
                                center = Offset(centerX, centerY),
                                style = Stroke(width = 2.dp.toPx(), pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(30f, 20f), hudRotation))
                            )
                            drawCircle(
                                color = hudColor.copy(alpha = 0.3f),
                                radius = 70.dp.toPx(),
                                center = Offset(centerX, centerY),
                                style = Stroke(width = 1.dp.toPx(), pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(10f, 40f), -hudRotation))
                            )

                            // 3. Draw targeting brackets (crosshair corners)
                            val bracketLen = 15.dp.toPx()
                            val bracketGap = 55.dp.toPx()
                            val strokeW = 2.dp.toPx()

                            // Top Left Bracket
                            drawLine(hudColor, Offset(centerX - bracketGap, centerY - bracketGap), Offset(centerX - bracketGap + bracketLen, centerY - bracketGap), strokeW)
                            drawLine(hudColor, Offset(centerX - bracketGap, centerY - bracketGap), Offset(centerX - bracketGap, centerY - bracketGap + bracketLen), strokeW)

                            // Top Right Bracket
                            drawLine(hudColor, Offset(centerX + bracketGap, centerY - bracketGap), Offset(centerX + bracketGap - bracketLen, centerY - bracketGap), strokeW)
                            drawLine(hudColor, Offset(centerX + bracketGap, centerY - bracketGap), Offset(centerX + bracketGap, centerY - bracketGap + bracketLen), strokeW)

                            // Bottom Left Bracket
                            drawLine(hudColor, Offset(centerX - bracketGap, centerY + bracketGap), Offset(centerX - bracketGap + bracketLen, centerY + bracketGap), strokeW)
                            drawLine(hudColor, Offset(centerX - bracketGap, centerY + bracketGap), Offset(centerX - bracketGap, centerY + bracketGap - bracketLen), strokeW)

                            // Bottom Right Bracket
                            drawLine(hudColor, Offset(centerX + bracketGap, centerY + bracketGap), Offset(centerX + bracketGap - bracketLen, centerY + bracketGap), strokeW)
                            drawLine(hudColor, Offset(centerX + bracketGap, centerY + bracketGap), Offset(centerX + bracketGap, centerY + bracketGap - bracketLen), strokeW)
                        }

                        // Category text label overlay
                        Box(
                            modifier = Modifier
                                .offset(
                                    x = with(LocalDensity.current) { (creatureX - 60.dp.toPx()).toDp() },
                                    y = with(LocalDensity.current) { (creatureY - 76.dp.toPx() + bobOffset).toDp() }
                                )
                                .background(hudColor.copy(alpha = 0.85f), RoundedCornerShape(4.dp))
                                .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(4.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Text(
                                text = "LOCKED: ${category.uppercase()}",
                                color = Color.White,
                                fontSize = 8.sp,
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 1.sp
                            )
                        }
                    }

                    // Floating creature portrait
                    Box(
                        modifier = Modifier
                            .offset(
                                x = with(LocalDensity.current) { (creatureX - 50.dp.toPx()).toDp() },
                                y = with(LocalDensity.current) { (creatureY - 50.dp.toPx() + bobOffset).toDp() }
                            )
                            .size(100.dp)
                            .clip(CircleShape)
                            .border(3.dp, Color(0xFF52B788), CircleShape)
                            .background(Color.Black.copy(alpha = 0.25f))
                    ) {
                        AsyncImage(
                            model = scannedImageUrl ?: "https://images.unsplash.com/photo-1472214222555-d40d5cca4987?w=500",
                            contentDescription = "Target Specimen",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxSize()
                                .graphicsLayer {
                                    scaleX = creatureScaleAnim.value
                                    scaleY = creatureScaleAnim.value
                                    alpha = creatureAlphaAnim.value
                                }
                        )
                    }

                    // Shrinking Target Ring (only active when idle, dragging, or flying)
                    if (tool != null && localThrowState in listOf(ThrowState.IDLE, ThrowState.DRAGGING, ThrowState.FLYING)) {
                        Canvas(modifier = Modifier.fillMaxSize()) {
                            val ringRadius = hitRadius * ringProgress
                            val probability = viewModel.calculateCaptureProbability(specimen, tool)
                            val ringColor = when {
                                probability >= 60 -> Color(0xFF52B788)
                                probability >= 40 -> Color(0xFFFFB703)
                                else -> Color(0xFFE63946)
                            }
                            drawCircle(
                                color = ringColor,
                                radius = ringRadius,
                                center = Offset(creatureX, creatureY + bobOffset),
                                style = Stroke(width = 3.dp.toPx())
                            )
                        }
                    }

                    // Star particle explosion
                    if (localThrowState == ThrowState.SUCCESS && particles.isNotEmpty()) {
                        Canvas(modifier = Modifier.fillMaxSize()) {
                            particles.forEach { p ->
                                drawCircle(
                                    color = p.color.copy(alpha = p.alpha),
                                    radius = p.size,
                                    center = Offset(p.x, p.y)
                                )
                            }
                        }
                    }

                    // Floating Quality Text Feedback
                    if (throwQualityAlpha.value > 0f) {
                        Text(
                            text = throwQualityText,
                            color = throwQualityColor.copy(alpha = throwQualityAlpha.value),
                            fontSize = 26.sp,
                            fontWeight = FontWeight.Black,
                            modifier = Modifier
                                .align(Alignment.Center)
                                .graphicsLayer {
                                    scaleX = throwQualityScale.value
                                    scaleY = throwQualityScale.value
                                }
                        )
                    }

                    // Pokéball Rendering
                    if (tool != null && localThrowState != ThrowState.SUCCESS) {
                        val dragModifier = if (localThrowState in listOf(ThrowState.IDLE, ThrowState.DRAGGING)) {
                            Modifier.pointerInput(launchX, launchY, tool, specimen) {
                                detectDragGestures(
                                    onDragStart = { offset ->
                                        if (localThrowState == ThrowState.IDLE) {
                                            localThrowState = ThrowState.DRAGGING
                                            dragStart = offset
                                            dragCurrent = Offset.Zero
                                            dragTime = System.currentTimeMillis()
                                        }
                                    },
                                    onDrag = { change, dragAmount ->
                                        if (localThrowState == ThrowState.DRAGGING) {
                                            change.consume()
                                            dragCurrent += dragAmount
                                        }
                                    },
                                    onDragEnd = {
                                        if (localThrowState == ThrowState.DRAGGING) {
                                            val timeElapsed = System.currentTimeMillis() - dragTime
                                            val swipeY = dragCurrent.y

                                            // Trigger a throw if swiped up
                                            if (swipeY < -120f && timeElapsed > 50) {
                                                isAnimatingCapture = true
                                                SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.THROW)

                                                val finalTargetY = creatureY
                                                val finalTargetX = launchX + dragCurrent.x * 1.6f

                                                throwStartX = launchX + dragCurrent.x
                                                throwStartYVal = launchY + dragCurrent.y
                                                throwEndX = finalTargetX
                                                throwEndY = finalTargetY

                                                localThrowState = ThrowState.FLYING

                                                coroutineScope.launch {
                                                    // Flight Animation
                                                    flightProgress.snapTo(0f)
                                                    flightProgress.animateTo(
                                                        targetValue = 1f,
                                                        animationSpec = tween(durationMillis = 680, easing = LinearEasing)
                                                    )

                                                    // Hit detection
                                                    val currentCreatureY = creatureY + bobOffset
                                                    val dist = sqrt((throwEndX - creatureX).pow(2) + (throwEndY - currentCreatureY).pow(2))
                                                    val isHit = dist <= hitRadius

                                                    if (isHit) {
                                                        localThrowState = ThrowState.HIT
                                                        SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.HIT)
                                                        val finalRingMult = ringProgress

                                                        // Quality feedback
                                                        throwQualityText = when {
                                                            finalRingMult <= 0.35f -> "Excellent Throw!"
                                                            finalRingMult <= 0.65f -> "Great Throw!"
                                                            else -> "Nice Throw!"
                                                        }
                                                        throwQualityColor = when {
                                                            finalRingMult <= 0.35f -> Color(0xFF9D4EDD)
                                                            finalRingMult <= 0.65f -> Color(0xFF52B788)
                                                            else -> Color(0xFF457B9D)
                                                        }

                                                        launch {
                                                            throwQualityScale.snapTo(0.3f)
                                                            throwQualityAlpha.snapTo(1f)
                                                            throwQualityScale.animateTo(1f, tween(300, easing = EaseOutBack))
                                                            delay(600)
                                                            throwQualityAlpha.animateTo(0f, tween(200))
                                                        }

                                                        // Suck in creature
                                                        launch {
                                                            creatureScaleAnim.animateTo(0f, tween(250, easing = EaseInBack))
                                                        }
                                                        launch {
                                                            creatureAlphaAnim.animateTo(0f, tween(250))
                                                        }
                                                        delay(250)

                                                        // Drop & Bounce
                                                        localThrowState = ThrowState.BOUNCING
                                                        bounceProgress.snapTo(0f)
                                                        bounceProgress.animateTo(
                                                            targetValue = 1f,
                                                            animationSpec = tween(durationMillis = 800, easing = EaseOutBounce)
                                                        )

                                                        // Wobbles
                                                        localThrowState = ThrowState.WOBBLING
                                                        val qualityBonus = throwQualityText == "Excellent Throw!" || throwQualityText == "Great Throw!"
                                                        viewModel.makeCaptureAttempt(specimen, tool, qualityBonus)

                                                        delay(350)
                                                        val isCaptured = viewModel.captureFinished.value && viewModel.captureResultMsg.value.contains("Successfully")
                                                        val isFled = viewModel.captureFinished.value && viewModel.captureResultMsg.value.contains("fled")

                                                        // Wobble 1
                                                        SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.WOBBLE)
                                                        wobbleAngle.snapTo(0f)
                                                        wobbleAngle.animateTo(20f, tween(100, easing = LinearEasing))
                                                        wobbleAngle.animateTo(-20f, tween(150, easing = LinearEasing))
                                                        wobbleAngle.animateTo(0f, tween(100, easing = LinearEasing))
                                                        delay(300)

                                                        var finalOutcomeReached = false
                                                        if (!isCaptured && !isFled && viewModel.captureAttempts.value > 0) {
                                                            SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.ESCAPE)
                                                            escapeBall()
                                                            finalOutcomeReached = true
                                                        }

                                                        if (!finalOutcomeReached) {
                                                            // Wobble 2
                                                            SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.WOBBLE)
                                                            wobbleAngle.animateTo(20f, tween(100, easing = LinearEasing))
                                                            wobbleAngle.animateTo(-20f, tween(150, easing = LinearEasing))
                                                            wobbleAngle.animateTo(0f, tween(100, easing = LinearEasing))
                                                            delay(300)

                                                            if (!isCaptured && !isFled && viewModel.captureAttempts.value > 0) {
                                                                SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.ESCAPE)
                                                                escapeBall()
                                                                finalOutcomeReached = true
                                                            }
                                                        }

                                                        if (!finalOutcomeReached) {
                                                            // Wobble 3
                                                            SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.WOBBLE)
                                                            wobbleAngle.animateTo(20f, tween(100, easing = LinearEasing))
                                                            wobbleAngle.animateTo(-20f, tween(150, easing = LinearEasing))
                                                            wobbleAngle.animateTo(0f, tween(100, easing = LinearEasing))
                                                            delay(300)

                                                            if (isCaptured) {
                                                                localThrowState = ThrowState.SUCCESS
                                                                isBallGlow = true
                                                                SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.SUCCESS)

                                                                // Particle Burst
                                                                var pList = List(25) {
                                                                    val angle = kotlin.random.Random.nextDouble() * 2 * Math.PI
                                                                    val speed = 4f + kotlin.random.Random.nextFloat() * 12f
                                                                    StarParticle(
                                                                        x = throwEndX,
                                                                        y = viewHeight * 0.72f,
                                                                        vx = (cos(angle) * speed).toFloat(),
                                                                        vy = (sin(angle) * speed).toFloat(),
                                                                        color = listOf(Color(0xFFFFF3B0), Color(0xFFF4A261), Color(0xFFE76F51), Color(0xFF2D6A4F)).random(),
                                                                        size = 5f + kotlin.random.Random.nextFloat() * 7f,
                                                                        alpha = 1f
                                                                    )
                                                                }
                                                                particles = pList

                                                                val particleEndTime = System.currentTimeMillis() + 600L
                                                                while (System.currentTimeMillis() < particleEndTime && pList.any { it.alpha > 0f }) {
                                                                    withFrameNanos { frameTimeNanos ->
                                                                        pList = pList.map { p ->
                                                                            p.copy(
                                                                                x = p.x + p.vx * 0.6f,
                                                                                y = p.y + p.vy * 0.6f,
                                                                                alpha = maxOf(0f, p.alpha - 0.03f)
                                                                            )
                                                                        }
                                                                        particles = pList
                                                                    }
                                                                }
                                                                delay(300)
                                                                isAnimatingCapture = false
                                                            } else {
                                                                // Fled
                                                                localThrowState = ThrowState.FLED
                                                                SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.ESCAPE)
                                                                launch {
                                                                    creatureScaleAnim.snapTo(0.1f)
                                                                    creatureAlphaAnim.snapTo(1f)
                                                                    creatureScaleAnim.animateTo(1.5f, tween(400))
                                                                    creatureAlphaAnim.animateTo(0f, tween(400))
                                                                }
                                                                delay(600)
                                                                isAnimatingCapture = false
                                                            }
                                                        }
                                                    } else {
                                                        // Missed throw: ball falls down screen
                                                        SoundEffectsManager.playSound(context, SoundEffectsManager.SoundType.ESCAPE)
                                                        viewModel.makeCaptureAttempt(specimen, tool, false, isMiss = true)
                                                        delay(400)
                                                        isAnimatingCapture = false
                                                        localThrowState = ThrowState.IDLE
                                                    }
                                                }
                                            } else {
                                                localThrowState = ThrowState.IDLE
                                            }
                                        }
                                    }
                                )
                            }
                        } else Modifier

                        Box(
                            modifier = Modifier
                                .offset(
                                    x = with(LocalDensity.current) { (activeBallX - 50.dp.toPx() * activeBallScale).toDp() },
                                    y = with(LocalDensity.current) { (activeBallY - 50.dp.toPx() * activeBallScale).toDp() }
                                )
                                .size((100.dp.value * activeBallScale).dp)
                                .then(dragModifier),
                            contentAlignment = Alignment.Center
                        ) {
                            Box(
                                modifier = Modifier.size((60.dp.value * activeBallScale).dp)
                            ) {
                                DrawPokeball(
                                    ballType = tool.toolName,
                                    modifier = Modifier.fillMaxSize(),
                                    rotation = activeBallRotation,
                                    glow = isBallGlow
                                )
                            }
                        }
                    }
                }
            }
        }

        // --- BOTTOM PANEL CONTAINING SPECIMEN DETAILS & TOOLS ---
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .background(Color(0xFF0F1E16))
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            if (currentScanned != null) {
                val specimen = currentScanned!!

                Column(modifier = Modifier.fillMaxWidth()) {
                    // Specimen detail notification header
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = specimen.name,
                                fontSize = 24.sp,
                                fontWeight = FontWeight.Black,
                                color = Color.White
                            )
                            Text(
                                text = specimen.scientificName,
                                fontSize = 14.sp,
                                fontStyle = FontStyle.Italic,
                                color = Color(0xFFA3B18A)
                            )
                        }

                        // Confidence Match
                        Box(
                            modifier = Modifier
                                .background(Color(0xFF52B788).copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                                .padding(horizontal = 10.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = "MATCH: ${specimen.confidence}%",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF52B788)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    // Tool list drawer selector
                    Text(
                        text = "CHOOSE CAPTURE TOOLKIT",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFA3B18A),
                        letterSpacing = 1.sp
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    LazyRow(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        val unlockedTools = inventoryTools.filter { it.isUnlocked }
                        items(unlockedTools) { tool ->
                            val isPicked = selectedTool?.toolName == tool.toolName
                            val ballColor = when (tool.toolName) {
                                "Poke Ball" -> Color(0xFFE63946)
                                "Premier Ball" -> Color(0xFFF0F0F0)
                                "Great Ball" -> Color(0xFF457B9D)
                                "Quick Ball" -> Color(0xFF0288D1)
                                "Ultra Ball" -> Color(0xFFFFB703)
                                "Beast Ball" -> Color(0xFF3A86C8)
                                "GS Ball" -> Color(0xFFE9C46A)
                                "Master Ball" -> Color(0xFF9D4EDD)
                                else -> Color.White
                            }
                            val ballIcon = when (tool.toolName) {
                                "Master Ball" -> Icons.Default.Stars
                                else -> Icons.Default.RadioButtonChecked
                            }

                            Box(
                                modifier = Modifier
                                    .width(115.dp)
                                    .background(
                                        if (isPicked) ballColor.copy(alpha = 0.25f) else Color(0xFF16281E),
                                        RoundedCornerShape(16.dp)
                                    )
                                    .border(
                                        width = if (isPicked) 2.dp else 1.dp,
                                        color = if (isPicked) ballColor else Color(0xFF2A3E33),
                                        shape = RoundedCornerShape(16.dp)
                                    )
                                    .clickable { viewModel.selectTool(tool) }
                                    .padding(horizontal = 10.dp, vertical = 12.dp)
                            ) {
                                Column(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Icon(
                                        ballIcon,
                                        contentDescription = null,
                                        tint = ballColor,
                                        modifier = Modifier.size(26.dp)
                                    )
                                    Spacer(modifier = Modifier.height(6.dp))
                                    Text(
                                        text = tool.displayName,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (isPicked) ballColor else Color.White,
                                        maxLines = 1
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = "${tool.usesRemaining}/${tool.maxDailyUses} left",
                                        fontSize = 10.sp,
                                        color = if (tool.usesRemaining <= 2) Color(0xFFE76F51) else if (isPicked) ballColor.copy(alpha = 0.8f) else Color(0xFF88A092)
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Main Capture Trigger area
                    val showResult = captureFinished && !isAnimatingCapture
                    if (selectedTool != null && !showResult) {
                        val currentTool = selectedTool!!
                        val probability = viewModel.calculateCaptureProbability(specimen, currentTool)

                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(Color(0xFF1E2E24), RoundedCornerShape(16.dp))
                                .padding(14.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(
                                        "CATCH CHANCE PROBABILITY",
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = Color(0xFFA3B18A)
                                    )
                                    Text(
                                        text = "$probability%",
                                        fontSize = 24.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (probability >= 60) Color(0xFF52B788) else Color(0xFFE76F51)
                                    )
                                }

                                Text(
                                    text = "Flick the Pokéball up!",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Drag and flick the Pokéball in the camera viewport above towards the floating species card. Hit it to trigger the capture roll!",
                                fontSize = 11.sp,
                                color = Color.LightGray,
                                lineHeight = 16.sp
                            )
                        }
                    } else if (showResult) {
                        // CAPTURE FINISHED STATUS REVEAL
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(Color(0xFF1E2E24), RoundedCornerShape(16.dp))
                                .padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = captureResultMsg,
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Black,
                                color = if (captureResultMsg.contains("Successfully")) Color(0xFF52B788) else Color.Red,
                                textAlign = TextAlign.Center
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            if (captureResultMsg.contains("Successfully")) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Icon(Icons.Default.Stars, contentDescription = "", tint = Color(0xFFF4A261))
                                        Spacer(modifier = Modifier.width(6.dp))
                                        val rewardsXP = when (specimen.rarity) {
                                            "Common" -> 100
                                            "Uncommon" -> 200
                                            "Rare" -> 400
                                            "Legendary" -> 800
                                            else -> 100
                                        }
                                        Text(
                                            text = "+$rewardsXP EXP ACCUMULATED!",
                                            fontSize = 14.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White
                                        )
                                    }

                                    if (scannedImageUrl != null && scannedImageUrl!!.startsWith("file://")) {
                                        Spacer(modifier = Modifier.height(12.dp))
                                        var isSaved by remember { mutableStateOf(false) }
                                        Button(
                                            onClick = {
                                                try {
                                                    val filePath = scannedImageUrl!!.replace("file://", "")
                                                    val bitmap = BitmapFactory.decodeFile(filePath)
                                                    if (bitmap != null) {
                                                        val savedUri = saveImageToGallery(context, bitmap)
                                                        if (savedUri != null) {
                                                            isSaved = true
                                                            android.widget.Toast.makeText(context, "Saved to Gallery!", android.widget.Toast.LENGTH_SHORT).show()
                                                        } else {
                                                            android.widget.Toast.makeText(context, "Failed to save image", android.widget.Toast.LENGTH_SHORT).show()
                                                        }
                                                    } else {
                                                        android.widget.Toast.makeText(context, "Unable to load image file", android.widget.Toast.LENGTH_SHORT).show()
                                                    }
                                                } catch (e: Exception) {
                                                    android.widget.Toast.makeText(context, "Error saving: ${e.message}", android.widget.Toast.LENGTH_SHORT).show()
                                                }
                                            },
                                            colors = ButtonDefaults.buttonColors(
                                                containerColor = if (isSaved) Color(0xFF52B788) else Color(0xFFF4A261)
                                            ),
                                            shape = RoundedCornerShape(12.dp),
                                            enabled = !isSaved
                                        ) {
                                            Icon(
                                                imageVector = if (isSaved) Icons.Default.Check else Icons.Default.Download,
                                                contentDescription = null,
                                                tint = Color.White,
                                                modifier = Modifier.size(16.dp)
                                            )
                                            Spacer(modifier = Modifier.width(6.dp))
                                            Text(
                                                text = if (isSaved) "SAVED TO GALLERY" else "SAVE TO GALLERY",
                                                fontWeight = FontWeight.Bold,
                                                color = Color.White
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            Button(
                                onClick = { viewModel.resetCaptureState() },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2D6A4F)),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text("SCAN NEXT WILDLIFE", fontWeight = FontWeight.Bold)
                            }
                        }
                    } else {
                        // Prompt to select tool
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(Color(0xFF1E2E24), RoundedCornerShape(16.dp))
                                .padding(20.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "👈 Select a tool from your toolkit drawer above to engage capture mechanics!",
                                fontSize = 13.sp,
                                color = Color.White.copy(alpha = 0.7f),
                                textAlign = TextAlign.Center,
                                lineHeight = 18.sp
                            )
                        }
                    }
                }
            } else {
                // STARTING CAPTURE FEED PROMPT
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        if (scanningError != null) {
                            Icon(
                                Icons.Default.ErrorOutline,
                                contentDescription = "",
                                modifier = Modifier.size(64.dp),
                                tint = Color.Red.copy(alpha = 0.8f)
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "SCANNING ERROR",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Black,
                                color = Color.Red
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = scanningError!!,
                                fontSize = 13.sp,
                                color = Color.White,
                                textAlign = TextAlign.Center,
                                lineHeight = 18.sp
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Button(
                                onClick = { viewModel.resetCaptureState() },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFE63946))
                            ) {
                                Text("Retry", fontWeight = FontWeight.Bold, color = Color.White)
                            }
                        } else {
                            Icon(
                                Icons.Default.MyLocation,
                                contentDescription = "",
                                modifier = Modifier.size(64.dp),
                                tint = Color(0xFF2D6A4F)
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "POINT CAMERA AT WILDLIFE",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Black,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Click 'SCAN SPECIES' to invoke Gemini Vision real-time computer vision scanning!",
                                fontSize = 12.sp,
                                color = Color(0xFFA3B18A),
                                textAlign = TextAlign.Center,
                                lineHeight = 18.sp
                            )
                        }
                    }
                }
            }
        }
    }
}

// Helper icons custom modifiers
@Composable
private fun TintedIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, contentDescription: String?, hint: Color, modifier: Modifier) {
    Icon(icon, contentDescription, modifier, tint = hint)
}

// --- SCANNER GRID OVERLAY ANIMATOR ---
@Composable
fun ScannerOverlay(isScanning: Boolean, isArEnabled: Boolean, weather: String) {
    val infiniteTransition = rememberInfiniteTransition(label = "scanner")
    
    // Rotating sweep angle
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(6000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    // Pulsing reticle size
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Canvas(modifier = Modifier.fillMaxSize()) {
        val width = size.width
        val height = size.height

        // Simple subtle green guide frame
        val padding = 40.dp.toPx()
        drawRect(
            color = Color(0xFF52B788).copy(alpha = 0.2f),
            topLeft = Offset(padding, padding),
            size = androidx.compose.ui.geometry.Size(width - (padding * 2), height - (padding * 2)),
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.dp.toPx())
        )

        // Corner visual indicators
        val lineLen = 20.dp.toPx()
        val thickness = 4.dp.toPx()
        val greenColor = Color(0xFF52B788)
        // Top-Left Corner
        drawLine(greenColor, Offset(padding, padding), Offset(padding + lineLen, padding), thickness)
        drawLine(greenColor, Offset(padding, padding), Offset(padding, padding + lineLen), thickness)
        // Top-Right Corner
        drawLine(greenColor, Offset(width - padding, padding), Offset(width - padding - lineLen, padding), thickness)
        drawLine(greenColor, Offset(width - padding, padding), Offset(width - padding, padding + lineLen), thickness)
        // Bottom-Left Corner
        drawLine(greenColor, Offset(padding, height - padding), Offset(padding + lineLen, height - padding), thickness)
        drawLine(greenColor, Offset(padding, height - padding), Offset(padding, height - padding - lineLen), thickness)
        // Bottom-Right Corner
        drawLine(greenColor, Offset(width - padding, height - padding), Offset(width - padding - lineLen, height - padding), thickness)
        drawLine(greenColor, Offset(width - padding, height - padding), Offset(width - padding, height - padding - lineLen), thickness)

        if (isArEnabled) {
            val centerX = width / 2f
            val centerY = height / 2f

            // Draw center circular reticle
            drawCircle(
                color = Color(0xFF52B788).copy(alpha = 0.15f),
                radius = 80.dp.toPx() * pulse,
                center = Offset(centerX, centerY)
            )
            drawCircle(
                color = Color(0xFF52B788).copy(alpha = 0.4f),
                radius = 80.dp.toPx() * pulse,
                center = Offset(centerX, centerY),
                style = Stroke(width = 1.5.dp.toPx(), pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(15f, 15f), rotation))
            )

            // Draw center point
            drawCircle(
                color = Color(0xFF52B788),
                radius = 4.dp.toPx(),
                center = Offset(centerX, centerY)
            )

            // Draw reticle crosshair marks
            val innerGap = 15.dp.toPx()
            val outerLen = 35.dp.toPx()
            drawLine(Color(0xFF52B788).copy(alpha = 0.6f), Offset(centerX, centerY - innerGap), Offset(centerX, centerY - outerLen), 2.dp.toPx())
            drawLine(Color(0xFF52B788).copy(alpha = 0.6f), Offset(centerX, centerY + innerGap), Offset(centerX, centerY + outerLen), 2.dp.toPx())
            drawLine(Color(0xFF52B788).copy(alpha = 0.6f), Offset(centerX - innerGap, centerY), Offset(centerX - outerLen, centerY), 2.dp.toPx())
            drawLine(Color(0xFF52B788).copy(alpha = 0.6f), Offset(centerX + innerGap, centerY), Offset(centerX + outerLen, centerY), 2.dp.toPx())
        }
    }
}

@Composable
fun WeatherParticlesOverlay(weather: String) {
    val infiniteTransition = rememberInfiniteTransition(label = "weather")
    val animProgress by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(2500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "progress"
    )

    Canvas(modifier = Modifier.fillMaxSize()) {
        val width = size.width
        val height = size.height

        when (weather) {
            "Rainy", "Stormy" -> {
                val rainCount = if (weather == "Stormy") 40 else 25
                for (i in 0 until rainCount) {
                    val seedX = (i * 97) % width
                    val startY = ((i * 137) + animProgress * height) % height
                    val length = 25.dp.toPx()
                    val slant = 4.dp.toPx()
                    
                    drawLine(
                        color = Color(0xFF80A3A2).copy(alpha = 0.4f),
                        start = Offset(seedX, startY),
                        end = Offset(seedX - slant, startY + length),
                        strokeWidth = 1.5.dp.toPx()
                    )
                }
            }
            "Foggy" -> {
                val driftX = animProgress * width
                drawRect(
                    brush = Brush.horizontalGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.05f),
                            Color.White.copy(alpha = 0.15f),
                            Color.White.copy(alpha = 0.05f)
                        ),
                        startX = driftX - width,
                        endX = driftX
                    ),
                    topLeft = Offset.Zero,
                    size = size
                )
                drawRect(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.08f),
                            Color.Transparent,
                            Color.White.copy(alpha = 0.12f)
                        )
                    ),
                    topLeft = Offset.Zero,
                    size = size
                )
            }
            "Sunny" -> {
                val pulseScale = 1.0f + 0.05f * sin(animProgress * 2 * Math.PI.toFloat())
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color(0xFFFFF3B0).copy(alpha = 0.3f),
                            Color(0xFFE09F3E).copy(alpha = 0.1f),
                            Color.Transparent
                        ),
                        center = Offset(width - 50.dp.toPx(), 50.dp.toPx()),
                        radius = 120.dp.toPx() * pulseScale
                    ),
                    center = Offset(width - 50.dp.toPx(), 50.dp.toPx()),
                    radius = 120.dp.toPx() * pulseScale
                )
            }
            "Clear Night" -> {
                for (i in 0 until 12) {
                    val starX = (i * 223) % width
                    val starY = (i * 149) % (height * 0.8f)
                    val starPulse = 1.5.dp.toPx() * (1f + 0.6f * sin((animProgress * 2 * Math.PI.toFloat()) + i))
                    drawCircle(
                        color = Color.White.copy(alpha = 0.6f),
                        radius = starPulse,
                        center = Offset(starX, starY)
                    )
                }
            }
        }
    }
}

// --- BASIC CAMERA PREVIEW LAYOUT ---
@Composable
fun CameraPreviewLayout(imageCapture: ImageCapture) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }

    AndroidView(
        factory = { ctx ->
            val previewView = PreviewView(ctx).apply {
                scaleType = PreviewView.ScaleType.FILL_CENTER
            }
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview,
                        imageCapture
                    )
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }, ContextCompat.getMainExecutor(ctx))
            previewView
        },
        modifier = Modifier.fillMaxSize()
    )
}



// --- CAMERA CAPTURE UTILS ---
fun imageProxyToBitmap(image: ImageProxy): Bitmap? {
    val planes = image.planes
    if (planes.isEmpty()) {
        android.util.Log.e("NatureDex", "imageProxyToBitmap: No planes available in ImageProxy")
        return null
    }
    val buffer = planes[0].buffer
    val bytes = ByteArray(buffer.remaining())
    buffer.get(bytes)
    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    if (bitmap == null) {
        android.util.Log.e("NatureDex", "imageProxyToBitmap: BitmapFactory.decodeByteArray returned null")
        return null
    }

    val rotation = image.imageInfo.rotationDegrees
    return if (rotation != 0) {
        val matrix = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
        Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    } else {
        bitmap
    }
}

fun bitmapToBase64(bitmap: Bitmap): String {
    val outputStream = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, 75, outputStream)
    val bytes = outputStream.toByteArray()
    return Base64.encodeToString(bytes, Base64.NO_WRAP)
}

fun saveBitmapToFile(context: android.content.Context, bitmap: Bitmap): String? {
    return try {
        val directory = java.io.File(context.filesDir, "captured_species")
        if (!directory.exists()) {
            directory.mkdirs()
        }
        val file = java.io.File(directory, "capture_${System.currentTimeMillis()}.jpg")
        java.io.FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }
        val path = "file://" + file.absolutePath
        android.util.Log.d("NatureDex", "saveBitmapToFile: Saved captured image to $path")
        path
    } catch (e: Exception) {
        android.util.Log.e("NatureDex", "Failed to save bitmap to file", e)
        null
    }
}

fun saveImageToGallery(context: android.content.Context, bitmap: Bitmap): String? {
    return try {
        val filename = "NatureDex_${System.currentTimeMillis()}.jpg"
        var imageUri: android.net.Uri? = null
        val resolver = context.contentResolver

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/NatureDex/")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            imageUri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            if (imageUri != null) {
                resolver.openOutputStream(imageUri)?.use { fos ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 95, fos)
                }
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(imageUri, contentValues, null, null)
            }
        } else {
            val imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).toString()
            val directory = java.io.File(imagesDir, "NatureDex")
            if (!directory.exists()) {
                directory.mkdirs()
            }
            val file = java.io.File(directory, filename)
            java.io.FileOutputStream(file).use { fos ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 95, fos)
            }
            imageUri = android.net.Uri.fromFile(file)
            
            // Trigger media scanner scan so it shows up in gallery app immediately
            val mediaScanIntent = android.content.Intent(android.content.Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
            mediaScanIntent.data = imageUri
            context.sendBroadcast(mediaScanIntent)
        }
        
        android.util.Log.d("NatureDex", "saveImageToGallery: Saved to $imageUri")
        imageUri?.toString()
    } catch (e: Exception) {
        android.util.Log.e("NatureDex", "Failed to save image to gallery", e)
        e.printStackTrace()
        null
    }
}

fun captureImageAndScan(
    context: android.content.Context,
    imageCapture: ImageCapture,
    executor: java.util.concurrent.Executor,
    viewModel: NatureDexViewModel
) {
    android.util.Log.d("NatureDex", "captureImageAndScan: Called, taking picture...")
    imageCapture.takePicture(
        executor,
        object : ImageCapture.OnImageCapturedCallback() {
            override fun onCaptureSuccess(image: ImageProxy) {
                android.util.Log.d("NatureDex", "captureImageAndScan: onCaptureSuccess called, format = ${image.format}, width = ${image.width}, height = ${image.height}")
                try {
                    val bitmap = imageProxyToBitmap(image)
                    if (bitmap == null) {
                        android.util.Log.e("NatureDex", "captureImageAndScan: Failed to convert ImageProxy to Bitmap")
                        return
                    }
                    android.util.Log.d("NatureDex", "captureImageAndScan: bitmap converted, width = ${bitmap.width}, height = ${bitmap.height}")
                    val localPath = saveBitmapToFile(context, bitmap)
                    val base64 = bitmapToBase64(bitmap)
                    android.util.Log.d("NatureDex", "captureImageAndScan: base64 generated, length = ${base64.length}")
                    viewModel.scanImageWithGemini(base64, localPath)
                } catch (e: Exception) {
                    android.util.Log.e("NatureDex", "captureImageAndScan: Exception converting/saving image", e)
                    e.printStackTrace()
                } finally {
                    image.close()
                }
            }

            override fun onError(exception: androidx.camera.core.ImageCaptureException) {
                android.util.Log.e("NatureDex", "Camera capture error: [${exception.imageCaptureError}] ${exception.message}", exception)
            }
        }
    )
}

enum class ThrowState {
    IDLE, DRAGGING, FLYING, HIT, SUCKING_IN, BOUNCING, WOBBLING, SUCCESS, ESCAPE, FLED
}

data class StarParticle(
    val x: Float,
    val y: Float,
    val vx: Float,
    val vy: Float,
    val color: Color,
    val size: Float,
    val alpha: Float
)

@Composable
fun DrawPokeball(
    ballType: String,
    modifier: Modifier = Modifier,
    rotation: Float = 0f,
    glow: Boolean = false
) {
    Canvas(modifier = modifier) {
        val radius = size.minDimension / 2
        val center = Offset(size.width / 2, size.height / 2)

        // Draw shadow under the ball
        drawOval(
            color = Color.Black.copy(alpha = 0.25f),
            topLeft = Offset(center.x - radius, center.y + radius * 0.8f),
            size = androidx.compose.ui.geometry.Size(radius * 2, radius * 0.35f)
        )

        // Draw the ball with rotation
        withTransform({
            rotate(rotation, center)
        }) {
            // 1. Draw bottom half
            val bottomColor = when (ballType) {
                "GS Ball" -> Color(0xFFCCCCCC) // Silver bottom
                "Beast Ball" -> Color(0xFF1E2A38) // dark metallic gray bottom
                else -> Color(0xFFE5E5E5)
            }
            drawArc(
                color = bottomColor,
                startAngle = 0f,
                sweepAngle = 180f,
                useCenter = true,
                topLeft = Offset(center.x - radius, center.y - radius),
                size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
            )

            // Draw bottom half shading (gradient overlay)
            drawArc(
                brush = Brush.radialGradient(
                    colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.15f)),
                    center = Offset(center.x, center.y + radius * 0.5f),
                    radius = radius
                ),
                startAngle = 0f,
                sweepAngle = 180f,
                useCenter = true,
                topLeft = Offset(center.x - radius, center.y - radius),
                size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
            )

            // 2. Draw top half based on ball type
            val topColor = when (ballType) {
                "Poke Ball" -> Color(0xFFE63946)
                "Premier Ball" -> Color(0xFFF0F0F0) // White top
                "Great Ball" -> Color(0xFF457B9D)
                "Quick Ball" -> Color(0xFF0288D1) // Light blue top
                "Ultra Ball" -> Color(0xFF2B2D42) // Dark graphite
                "Beast Ball" -> Color(0xFF0F4C81) // Dark blue top
                "GS Ball" -> Color(0xFFE9C46A) // Gold top
                "Master Ball" -> Color(0xFF7209B7) // Deep purple
                else -> Color(0xFFE63946)
            }

            drawArc(
                color = topColor,
                startAngle = 180f,
                sweepAngle = 180f,
                useCenter = true,
                topLeft = Offset(center.x - radius, center.y - radius),
                size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
            )

            // Draw ball-specific patterns on the top half
            when (ballType) {
                "Great Ball" -> {
                    // Two red stripes on the sides
                    drawArc(
                        color = Color(0xFFE63946),
                        startAngle = 210f,
                        sweepAngle = 30f,
                        useCenter = true,
                        topLeft = Offset(center.x - radius, center.y - radius),
                        size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
                    )
                    drawArc(
                        color = Color(0xFFE63946),
                        startAngle = 300f,
                        sweepAngle = 30f,
                        useCenter = true,
                        topLeft = Offset(center.x - radius, center.y - radius),
                        size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
                    )
                }
                "Ultra Ball" -> {
                    // Yellow stripe patterns
                    val stripeThickness = radius * 0.18f
                    drawArc(
                        color = Color(0xFFFFB703),
                        startAngle = 220f,
                        sweepAngle = 100f,
                        useCenter = false,
                        topLeft = Offset(center.x - radius * 0.8f, center.y - radius * 0.8f),
                        size = androidx.compose.ui.geometry.Size(radius * 1.6f, radius * 1.6f),
                        style = Stroke(width = stripeThickness)
                    )
                    drawRect(
                        color = Color(0xFFFFB703),
                        topLeft = Offset(center.x - stripeThickness / 2, center.y - radius),
                        size = androidx.compose.ui.geometry.Size(stripeThickness, radius * 0.5f)
                    )
                }
                "Quick Ball" -> {
                    // Yellow starburst/X pattern crossing from the center.
                    val yellowColor = Color(0xFFFFD166)
                    val pathX = Path().apply {
                        val cx = center.x
                        val cy = center.y - radius * 0.5f
                        val r = radius * 0.4f
                        moveTo(cx - r, cy - r)
                        lineTo(cx + r, cy + r)
                        moveTo(cx + r, cy - r)
                        lineTo(cx - r, cy + r)
                    }
                    drawPath(
                        path = pathX,
                        color = yellowColor,
                        style = Stroke(width = radius * 0.16f, cap = StrokeCap.Round)
                    )
                }
                "Beast Ball" -> {
                    // Yellow/Gold claw lines wrapping around the edges
                    val clawColor = Color(0xFFE9C46A)
                    val clawThickness = radius * 0.10f
                    drawArc(
                        color = clawColor,
                        startAngle = 190f,
                        sweepAngle = 60f,
                        useCenter = false,
                        topLeft = Offset(center.x - radius * 0.9f, center.y - radius * 0.9f),
                        size = androidx.compose.ui.geometry.Size(radius * 1.8f, radius * 1.8f),
                        style = Stroke(width = clawThickness)
                    )
                    drawArc(
                        color = clawColor,
                        startAngle = 290f,
                        sweepAngle = 60f,
                        useCenter = false,
                        topLeft = Offset(center.x - radius * 0.9f, center.y - radius * 0.9f),
                        size = androidx.compose.ui.geometry.Size(radius * 1.8f, radius * 1.8f),
                        style = Stroke(width = clawThickness)
                    )
                }
                "GS Ball" -> {
                    // Engraved 'G' and 'S' paths on the left and right of the top half
                    val goldColor = Color(0xFFD4AF37)
                    val gPath = Path().apply {
                        val topY = center.y - radius * 0.70f
                        val botY = center.y - radius * 0.38f
                        val midY = center.y - radius * 0.54f
                        val leftX = center.x - radius * 0.40f
                        val rightX = center.x - radius * 0.10f
                        
                        moveTo(rightX, topY)
                        lineTo(leftX, topY)
                        lineTo(leftX, botY)
                        lineTo(rightX, botY)
                        lineTo(rightX, midY)
                        lineTo(center.x - radius * 0.25f, midY)
                    }
                    val sPath = Path().apply {
                        val topY = center.y - radius * 0.70f
                        val botY = center.y - radius * 0.38f
                        val midY = center.y - radius * 0.54f
                        val leftX = center.x + radius * 0.10f
                        val rightX = center.x + radius * 0.40f
                        
                        moveTo(rightX, topY)
                        lineTo(leftX, topY)
                        lineTo(leftX, midY)
                        lineTo(rightX, midY)
                        lineTo(rightX, botY)
                        lineTo(leftX, botY)
                    }
                    drawPath(
                        path = gPath,
                        color = goldColor,
                        style = Stroke(width = radius * 0.08f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                    )
                    drawPath(
                        path = sPath,
                        color = goldColor,
                        style = Stroke(width = radius * 0.08f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                    )
                }
                "Master Ball" -> {
                    // Two pink circular bumps
                    val bumpRadius = radius * 0.22f
                    drawCircle(
                        color = Color(0xFFF72585),
                        radius = bumpRadius,
                        center = Offset(center.x - radius * 0.45f, center.y - radius * 0.45f)
                    )
                    drawCircle(
                        color = Color(0xFFF72585),
                        radius = bumpRadius,
                        center = Offset(center.x + radius * 0.45f, center.y - radius * 0.45f)
                    )
                    // White letter 'M' using path
                    val path = Path().apply {
                        val mSize = radius * 0.28f
                        val topY = center.y - radius * 0.70f
                        val botY = center.y - radius * 0.42f
                        val midY = center.y - radius * 0.55f
                        val leftX = center.x - mSize / 2
                        val rightX = center.x + mSize / 2

                        moveTo(leftX, botY)
                        lineTo(leftX, topY)
                        lineTo(center.x, midY)
                        lineTo(rightX, topY)
                        lineTo(rightX, botY)
                    }
                    drawPath(
                        path = path,
                        color = Color.White,
                        style = Stroke(width = radius * 0.08f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                    )
                }
            }

            // Top half shading (highlight gradient)
            drawArc(
                brush = Brush.radialGradient(
                    colors = listOf(Color.White.copy(alpha = 0.22f), Color.Transparent),
                    center = Offset(center.x - radius * 0.3f, center.y - radius * 0.5f),
                    radius = radius * 0.8f
                ),
                startAngle = 180f,
                sweepAngle = 180f,
                useCenter = true,
                topLeft = Offset(center.x - radius, center.y - radius),
                size = androidx.compose.ui.geometry.Size(radius * 2, radius * 2)
            )

            // 3. Draw black horizontal center line (band) - red for Premier Ball
            val bandColor = if (ballType == "Premier Ball") Color(0xFFE63946) else Color(0xFF2B2D42)
            drawRect(
                color = bandColor,
                topLeft = Offset(center.x - radius, center.y - radius * 0.08f),
                size = androidx.compose.ui.geometry.Size(radius * 2, radius * 0.16f)
            )

            // 4. Center button (outer ring) - red for Premier Ball
            drawCircle(
                color = bandColor,
                radius = radius * 0.28f,
                center = center
            )

            // Center button (inner white circle)
            drawCircle(
                color = if (glow) Color(0xFF52B788) else Color.White,
                radius = radius * 0.20f,
                center = center
            )

            // Center button core detail
            drawCircle(
                color = if (glow) Color.White else Color(0xFFE5E5E5),
                radius = radius * 0.10f,
                center = center
            )
        }
    }
}

private val EaseOutBounce = Easing { fraction ->
    val n1 = 7.5625f
    val d1 = 2.75f
    when {
        fraction < 1f / d1 -> n1 * fraction * fraction
        fraction < 2f / d1 -> {
            val f = fraction - 1.5f / d1
            n1 * f * f + 0.75f
        }
        fraction < 2.5f / d1 -> {
            val f = fraction - 2.25f / d1
            n1 * f * f + 0.9375f
        }
        else -> {
            val f = fraction - 2.625f / d1
            n1 * f * f + 0.984375f
        }
    }
}

private val EaseOutBack = Easing { fraction ->
    val c1 = 1.70158f
    val c3 = c1 + 1f
    val f = fraction - 1f
    1f + c3 * f * f * f + c1 * f * f
}

private val EaseInBack = Easing { fraction ->
    val c1 = 1.70158f
    val c3 = c1 + 1f
    c3 * fraction * fraction * fraction - c1 * fraction * fraction
}

