package com.example

import android.os.Bundle
import android.view.HapticFeedbackConstants
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.ui.screens.*
import com.example.ui.theme.MyApplicationTheme
import com.example.ui.viewmodel.NatureDexViewModel
import coil.Coil
import coil.ImageLoader
import okhttp3.OkHttpClient

sealed class NavTab(
    val label: String,
    val filledIcon: ImageVector,
    val outlinedIcon: ImageVector,
    val testTag: String
) {
    data object Index : NavTab("Index", Icons.Filled.GridView, Icons.Outlined.GridView, "nav_index")
    data object Capture : NavTab("Capture", Icons.Filled.Camera, Icons.Outlined.Camera, "nav_capture")
    data object Profile : NavTab("Profile", Icons.Filled.Person, Icons.Outlined.Person, "nav_profile")
    data object Map : NavTab("Map", Icons.Filled.Map, Icons.Outlined.Map, "nav_map")
}

class MainActivity : androidx.fragment.app.FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val imageLoader = ImageLoader.Builder(this)
            .crossfade(true)
            .crossfade(200)
            .okHttpClient {
                OkHttpClient.Builder()
                    .addInterceptor { chain ->
                        val request = chain.request()
                        val url = request.url
                        val host = url.host
                        val isLocal = url.scheme == "file" || url.scheme == "content" || host.isEmpty()
                        val allowedHosts = listOf(
                            "images.unsplash.com",
                            "upload.wikimedia.org",
                            "inaturalist.org",
                            "static.inaturalist.org",
                            "inaturalist-open-data.s3.amazonaws.com",
                            "lh3.googleusercontent.com"
                        )
                        val isAllowed = isLocal || allowedHosts.any { allowed ->
                            host == allowed || host.endsWith(".$allowed")
                        }
                        if (!isAllowed) {
                            throw SecurityException("Access to domain $host is blocked for security reasons.")
                        }
                        val newRequest = request.newBuilder()
                            .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) NatureDex/1.0")
                            .build()
                        chain.proceed(newRequest)
                    }
                    .build()
            }
            .build()
        Coil.setImageLoader(imageLoader)

        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                MainAppLayout()
            }
        }
    }
}

@Composable
fun MainAppLayout() {
    val viewModel: NatureDexViewModel = viewModel()
    val currentTab by viewModel.currentTab.collectAsState()
    val showDetail by viewModel.showDetail.collectAsState()
    val selectedSpecies by viewModel.selectedSpecies.collectAsState()

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            AnimatedVisibility(
                visible = !showDetail,
                enter = slideInVertically(tween(180, easing = FastOutSlowInEasing)) { it } + fadeIn(tween(120)),
                exit = slideOutVertically(tween(120, easing = FastOutSlowInEasing)) { it } + fadeOut(tween(80))
            ) {
                NatureDexBottomBar(
                    currentTab = currentTab,
                    onTabSelected = { viewModel.selectTab(it) }
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            AnimatedContent(
                targetState = showDetail to selectedSpecies,
                transitionSpec = {
                    if (targetState.first) {
                        // Detail opening: fast slide up + fade in
                        (slideInVertically(tween(200, easing = FastOutSlowInEasing)) { it / 3 } +
                         fadeIn(tween(150))) togetherWith
                        fadeOut(tween(80))
                    } else {
                        // Detail closing: quick fade in + slide down
                        fadeIn(tween(100)) togetherWith
                        (slideOutVertically(tween(150, easing = FastOutSlowInEasing)) { it / 3 } +
                         fadeOut(tween(100)))
                    }
                },
                label = "detailTransition"
            ) { (show, species) ->
                if (show && species != null) {
                    SpeciesDetailScreen(
                        species = species,
                        viewModel = viewModel,
                        onBack = { viewModel.closeSpeciesDetail() }
                    )
                } else {
                    AnimatedContent(
                        targetState = currentTab,
                        transitionSpec = {
                            fadeIn(tween(120)) togetherWith fadeOut(tween(80))
                        },
                        label = "tabTransition"
                    ) { tab ->
                        when (tab) {
                            is NavTab.Index -> IndexScreen(
                                viewModel = viewModel,
                                onSpeciesClick = { viewModel.showSpeciesDetail(it) }
                            )
                            is NavTab.Capture -> CaptureScreen(viewModel = viewModel)
                            is NavTab.Map -> MapScreen(viewModel = viewModel)
                            is NavTab.Profile -> ProfileScreen(viewModel = viewModel)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun NatureDexBottomBar(
    currentTab: NavTab,
    onTabSelected: (NavTab) -> Unit
) {
    val tabs = listOf(NavTab.Index, NavTab.Capture, NavTab.Map, NavTab.Profile)
    val haptic = LocalHapticFeedback.current
    val view = LocalView.current

    NavigationBar(
        containerColor = MaterialTheme.colorScheme.surface,
        tonalElevation = 8.dp,
        modifier = Modifier.windowInsetsPadding(WindowInsets.navigationBars)
    ) {
        val navColors = NavigationBarItemDefaults.colors(
            indicatorColor = com.example.ui.theme.VibrantSoftGreenHighlight,
            selectedIconColor = com.example.ui.theme.VibrantHeaderGreen,
            selectedTextColor = com.example.ui.theme.VibrantHeaderGreen,
            unselectedIconColor = Color.Gray.copy(alpha = 0.7f),
            unselectedTextColor = Color.Gray.copy(alpha = 0.7f)
        )

        tabs.forEach { tab ->
            NavigationBarItem(
                selected = currentTab == tab,
                onClick = {
                    if (currentTab != tab) {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                        onTabSelected(tab)
                    }
                },
                icon = {
                    Icon(
                        imageVector = if (currentTab == tab) tab.filledIcon else tab.outlinedIcon,
                        contentDescription = "${tab.label} Tab"
                    )
                },
                label = { Text(tab.label) },
                modifier = Modifier.testTag(tab.testTag),
                colors = navColors
            )
        }
    }
}
