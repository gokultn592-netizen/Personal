package com.example.data

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import java.util.UUID

class NatureDexRepository(private val dao: NatureDexDao) {

    // --- Database Flows ---
    val capturedList: Flow<List<CapturedCreature>> = dao.getAllCaptured()
    val wishlist: Flow<List<WishlistCreature>> = dao.getWishlist()
    val inventoryTools: Flow<List<InventoryTool>> = dao.getInventoryTools()
    val playerStats: Flow<PlayerStats?> = dao.getPlayerStats()
    val completedAchievements: Flow<List<CompletedAchievement>> = dao.getCompletedAchievements()

    // --- Captured Creatures ---
    suspend fun insertCaptured(creature: CapturedCreature) = dao.insertCaptured(creature)
    suspend fun isCreatureCaptured(speciesId: Int): Int = dao.isCreatureCaptured(speciesId)
    suspend fun getCapturedListOnce(): List<CapturedCreature> = dao.getCapturedListOnce()

    // --- Wishlist ---
    suspend fun insertWishlist(creature: WishlistCreature) = dao.insertWishlist(creature)
    suspend fun deleteWishlistById(speciesId: Int) = dao.deleteWishlistById(speciesId)
    suspend fun isWishlisted(speciesId: Int): Int = dao.isWishlisted(speciesId)

    // --- Tools ---
    suspend fun updateTool(tool: InventoryTool) = dao.updateTool(tool)
    suspend fun insertTool(tool: InventoryTool) = dao.insertTool(tool)
    suspend fun clearAllTools() = dao.clearAllTools()
    suspend fun resetDailyUses() = dao.resetDailyUses()

    // --- Player Stats ---
    suspend fun insertPlayerStats(stats: PlayerStats) = dao.insertPlayerStats(stats)

    // --- Achievements ---
    suspend fun insertCompletedAchievement(achievement: CompletedAchievement) =
        dao.insertCompletedAchievement(achievement)

    suspend fun clearAllCaptured() = dao.clearAllCaptured()
    suspend fun clearAllAchievements() = dao.clearAllAchievements()

    // --- API: iNaturalist ---
    suspend fun searchINaturalistTaxa(
        query: String,
        iconicTaxa: String? = null,
        perPage: Int = 15
    ): List<Taxon> = withContext(Dispatchers.IO) {
        try {
            val response = INaturalistClient.service.searchTaxa(
                query = query,
                rank = "species",
                perPage = perPage,
                iconicTaxa = iconicTaxa
            )
            response.results
        } catch (e: Exception) {
            Log.e("NatureDex", "iNaturalist search failed: ${e.message}")
            emptyList()
        }
    }

    suspend fun autocompleteINaturalist(
        query: String,
        iconicTaxa: String? = null,
        perPage: Int = 15
    ): List<Taxon> = withContext(Dispatchers.IO) {
        try {
            val response = INaturalistClient.service.autocompleteTaxa(
                query = query,
                rank = "species",
                perPage = perPage,
                iconicTaxa = iconicTaxa
            )
            response.results
        } catch (e: Exception) {
            Log.e("NatureDex", "iNaturalist autocomplete failed: ${e.message}")
            emptyList()
        }
    }

    // --- API: Wikipedia ---
    suspend fun fetchWikipediaImage(scientificName: String): String? = withContext(Dispatchers.IO) {
        try {
            val wikiResponse = WikipediaClient.service.getPageImage(titles = scientificName)
            val sourceUrl = wikiResponse.query?.pages?.values
                ?.firstOrNull { it.pageid != -1 }
                ?.thumbnail?.source
            normalizeImageUrl(sourceUrl)
        } catch (e: Exception) {
            Log.e("NatureDex", "Wikipedia image fetch failed: ${e.message}")
            null
        }
    }

    // --- API: Gemini ---
    suspend fun scanImageWithGemini(base64Image: String): ScannedCreatureResponse? =
        withContext(Dispatchers.IO) {
            GeminiClient.scanImageForWildlife(base64Image)
        }

    suspend fun fetchSpeciesDetailFromGemini(
        speciesName: String,
        scientificName: String? = null
    ): ScannedCreatureResponse? = withContext(Dispatchers.IO) {
        GeminiClient.fetchSpeciesDetailFromGemini(speciesName, scientificName)
    }

    // --- Image Resolution ---
    suspend fun resolveRealSpeciesImage(
        commonName: String,
        scientificName: String
    ): String? {
        // Step 1: iNaturalist by scientific name
        try {
            val response = withContext(Dispatchers.IO) {
                INaturalistClient.service.searchTaxa(
                    query = scientificName,
                    rank = "species",
                    perPage = 1
                )
            }
            val logo = response.results.firstOrNull()?.defaultPhoto?.getDisplayUrl()
            if (!logo.isNullOrEmpty()) {
                Log.d("NatureDex", "Found iNaturalist photo for scientific name $scientificName: $logo")
                return normalizeImageUrl(logo)
            }
        } catch (e: Exception) {
            Log.e("NatureDex", "iNaturalist scientific name query failed: ${e.message}")
        }

        // Step 2: iNaturalist by common name
        try {
            val response = withContext(Dispatchers.IO) {
                INaturalistClient.service.searchTaxa(
                    query = commonName,
                    rank = "species",
                    perPage = 1
                )
            }
            val logo = response.results.firstOrNull()?.defaultPhoto?.getDisplayUrl()
            if (!logo.isNullOrEmpty()) {
                Log.d("NatureDex", "Found iNaturalist photo for common name $commonName: $logo")
                return normalizeImageUrl(logo)
            }
        } catch (e: Exception) {
            Log.e("NatureDex", "iNaturalist common name query failed: ${e.message}")
        }

        // Step 3: Wikipedia by scientific name
        fetchWikipediaImage(scientificName)?.let { return it }

        // Step 4: Wikipedia by common name
        fetchWikipediaImage(commonName)?.let { return it }

        return null
    }

    suspend fun resolveSpeciesImage(species: DefaultSpecies): String {
        return try {
            val taxaResponse = withContext(Dispatchers.IO) {
                INaturalistClient.service.searchTaxa(
                    query = species.scientificName,
                    rank = "species",
                    perPage = 1
                )
            }
            val inatUrl = taxaResponse.results
                .firstOrNull()
                ?.defaultPhoto
                ?.getDisplayUrl()

            val finalUrl = if (!inatUrl.isNullOrBlank()) {
                inatUrl
            } else {
                fetchWikipediaImage(species.scientificName) ?: species.imageUrl
            }
            normalizeImageUrl(finalUrl) ?: species.imageUrl
        } catch (e: Exception) {
            fetchWikipediaImage(species.scientificName) ?: species.imageUrl
        }
    }

    suspend fun mapINaturalistResultsToSpecies(
        results: List<Taxon>,
        category: String
    ): List<DefaultSpecies> {
        return results.mapIndexed { idx, t ->
            val wikiImage = fetchWikipediaImage(t.name)
            val rawImage = wikiImage ?: t.defaultPhoto?.getDisplayUrl()
                ?: "https://images.unsplash.com/photo-1472214222555-d40d5cca4987?w=500"
            val finalImage = normalizeImageUrl(rawImage)
                ?: "https://images.unsplash.com/photo-1472214222555-d40d5cca4987?w=500"

            val categoryMapped = when (t.iconicTaxonName) {
                "Aves" -> "Birds"
                "Actinopterygii" -> "Fish"
                "Insecta", "Arachnida" -> "Insects"
                "Reptilia" -> "Reptiles"
                "Plantae" -> "Plants"
                else -> "Animals"
            }

            val rarity = when {
                idx % 7 == 0 -> "Legendary"
                idx % 4 == 0 -> "Rare"
                idx % 3 == 0 -> "Uncommon"
                else -> "Common"
            }

            val threat = when {
                categoryMapped == "Plants" -> "None"
                rarity == "Legendary" -> "Deadly"
                rarity == "Rare" && idx % 2 == 0 -> "High"
                idx % 5 == 0 -> "Medium"
                idx % 3 == 0 -> "Low"
                else -> "None"
            }

            DefaultSpecies(
                id = t.id,
                name = t.preferredCommonName ?: t.name,
                scientificName = t.name,
                category = categoryMapped,
                rarity = rarity,
                threatLevel = threat,
                imageUrl = finalImage,
                habitat = "Natural environment worldwide",
                diet = "Standard wild sustenance",
                distribution = "Wild distribution",
                iucnStatus = "Least Concern",
                funFacts = listOf(
                    "Discovered via the global iNaturalist repository.",
                    "Scientific taxonic branch: ${t.name}",
                    "Click wishlist to save this species catalog safely for offline learning!"
                )
            )
        }
    }

    companion object {
        fun normalizeImageUrl(url: String?): String? {
            if (url.isNullOrBlank()) return null
            return when {
                url.startsWith("//") -> "https:$url"
                url.startsWith("http://") -> url.replace("http://", "https://")
                else -> url
            }
        }

        fun generateSpeciesId(): Int {
            return UUID.randomUUID().mostSignificantBits.toInt()
        }
    }
}
