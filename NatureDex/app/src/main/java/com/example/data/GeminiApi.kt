package com.example.data

import com.squareup.moshi.Json
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import okhttp3.OkHttpClient
import okhttp3.ResponseBody
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.Body
import retrofit2.http.POST
import retrofit2.http.Query
import java.util.concurrent.TimeUnit
import com.example.BuildConfig

// --- Gemini API Models ---

data class GeminiRequest(
    val contents: List<GeminiContent>,
    val generationConfig: GeminiGenerationConfig? = null,
    val systemInstruction: GeminiInstructionContent? = null
)

data class GeminiInstructionContent(
    val parts: List<GeminiTextPart>
)

data class GeminiTextPart(
    val text: String
)

data class GeminiContent(
    val parts: List<GeminiPartConcrete>
)

// Custom Moshi JSON adapter to serialize/deserialize sealed classes like GeminiPart
// Actually, let's make GeminiPart a standard concrete class with optional fields to avoid needing a custom sealed class adapter!
// This is infinitely safer for Moshi compilation.

data class GeminiPartConcrete(
    val text: String? = null,
    @Json(name = "inlineData") val inlineData: GeminiInlineData? = null
)

data class GeminiInlineData(
    @Json(name = "mimeType") val mimeType: String,
    val data: String // Base64 string
)

data class GeminiGenerationConfig(
    val responseMimeType: String? = null,
    val temperature: Float? = null,
    val maxOutputTokens: Int? = null
)

data class GeminiResponse(
    val candidates: List<GeminiCandidate>?
)

data class GeminiCandidate(
    val content: GeminiResponseContent?,
    val finishReason: String?
)

data class GeminiResponseContent(
    val parts: List<GeminiResponsePart>?
)

data class GeminiResponsePart(
    val text: String?
)

// --- Structuring Gemini Scanning Response ---

data class ScannedCreatureResponse(
    val name: String,
    @Json(name = "scientific_name") val scientificName: String,
    val category: String, // Animals, Birds, Fish, Insects, Reptiles, Plants
    val rarity: String, // Common, Uncommon, Rare, Legendary
    @Json(name = "threat_level") val threatLevel: String, // None, Low, Medium, High, Deadly
    val confidence: Int,
    val habitat: String,
    val diet: String,
    val distribution: String,
    @Json(name = "iucn_status") val iucnStatus: String, // e.g. Vulnerable, Least Concern...
    @Json(name = "fun_facts") val funFacts: List<String>
)

// --- Retrofit Interface ---

interface GeminiApiService {
    @POST("v1beta/models/{model}:generateContent")
    suspend fun generateContent(
        @retrofit2.http.Path("model") model: String,
        @Query("key") apiKey: String,
        @Body request: GeminiRequest
    ): GeminiResponse
}

object GeminiClient {
    private const val BASE_URL = "https://generativelanguage.googleapis.com/"

    private val moshi = Moshi.Builder()
        .addLast(KotlinJsonAdapterFactory())
        .build()

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    val service: GeminiApiService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(GeminiApiService::class.java)
    }

    suspend fun scanImageForWildlife(
        base64Image: String,
        mimeType: String = "image/jpeg"
    ): ScannedCreatureResponse? {
        val apiKey = BuildConfig.GEMINI_API_KEY
        if (apiKey.isEmpty() || apiKey == "MY_GEMINI_API_KEY") {
            throw IllegalStateException("API Key is placeholder or missing. Please add your GEMINI_API_KEY inside the Secrets panel.")
        }
        val model = try {
            if (BuildConfig.GEMINI_MODEL.isNotEmpty()) BuildConfig.GEMINI_MODEL else "gemini-flash-latest"
        } catch (e: Exception) {
            "gemini-flash-latest"
        }

        val prompt = """
            Analyze the provided image and identify the primary organism/creature/plant visible in it.
            You must return a raw JSON object strictly conforming to this schema without markdown code blocks:
            {
              "name": "Common Species Name",
              "scientific_name": "Scientific name styled in cursive",
              "category": "Select exactly one of: Animals, Birds, Fish, Insects, Reptiles, Plants",
              "rarity": "Select exactly one of: Common, Uncommon, Rare, Legendary",
              "threat_level": "Select exactly one of: None, Low, Medium, High, Deadly. Determine the threat level strictly based on documented physical attacks and fatalities caused by this particular animal/organism to humans.",
              "confidence": 85, (your belief percentage, 1-100),
              "habitat": "Short description of habitat",
              "diet": "Short description of diet",
              "distribution": "Short description of distribution",
              "iucn_status": "Select exactly one of: Least Concern, Near Threatened, Vulnerable, Endangered, Critically Endangered, Extinct",
              "fun_facts": ["Fact 1", "Fact 2"]
            }
            Do not return any other text, html or wrapper tags - only the raw JSON string. If you don't find any clear biological species in the image, you must identify what closest creature is implied, or detect any environment background animal and return a valid wildlife object.
        """.trimIndent()

        val request = GeminiRequest(
            contents = listOf(
                GeminiContent(
                    parts = listOf(
                        GeminiPartConcrete(text = prompt),
                        GeminiPartConcrete(inlineData = GeminiInlineData(mimeType = mimeType, data = base64Image))
                    )
                )
            ),
            generationConfig = GeminiGenerationConfig(
                responseMimeType = "application/json",
                temperature = 0.2f
            )
        )

        try {
            android.util.Log.d("NatureDex", "scanImageForWildlife: Sending generateContent request to Gemini ($model)...")
            val response = service.generateContent(model, apiKey, request)
            android.util.Log.d("NatureDex", "scanImageForWildlife: Received response from Gemini: $response")
            val text = response.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text
            android.util.Log.d("NatureDex", "scanImageForWildlife: Raw response text = $text")
            if (text == null) {
                android.util.Log.e("NatureDex", "scanImageForWildlife: Response text is null")
                return null
            }

            val trimmed = text.trim()
            val cleanedJson = if (trimmed.startsWith("```")) {
                val startIndex = trimmed.indexOf("{")
                val endIndex = trimmed.lastIndexOf("}")
                if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
                    trimmed.substring(startIndex, endIndex + 1)
                } else {
                    trimmed
                }
            } else {
                trimmed
            }
            android.util.Log.d("NatureDex", "scanImageForWildlife: Cleaned JSON = $cleanedJson")

            val result = moshi.adapter(ScannedCreatureResponse::class.java).fromJson(cleanedJson)
            android.util.Log.d("NatureDex", "scanImageForWildlife: Successfully parsed ScannedCreatureResponse: $result")
            return result
        } catch (e: Exception) {
            android.util.Log.e("NatureDex", "scanImageForWildlife: Exception occurred", e)
            throw e
        }
    }

    suspend fun fetchSpeciesDetailFromGemini(
        speciesName: String,
        scientificName: String? = null
    ): ScannedCreatureResponse? {
        val apiKey = BuildConfig.GEMINI_API_KEY
        if (apiKey.isEmpty() || apiKey == "MY_GEMINI_API_KEY") {
            throw IllegalStateException("API Key is missing")
        }
        val model = try {
            if (BuildConfig.GEMINI_MODEL.isNotEmpty()) BuildConfig.GEMINI_MODEL else "gemini-flash-latest"
        } catch (e: Exception) {
            "gemini-flash-latest"
        }

        val prompt = """
            Provide full wildlife profile details for the species: ${speciesName}${if (scientificName != null) " ($scientificName)" else ""}.
            Return raw JSON strictly matching this schema:
            {
              "name": "Common Name",
              "scientific_name": "Scientific Name",
              "category": "Select exactly one of: Animals, Birds, Fish, Insects, Reptiles, Plants",
              "rarity": "Select exactly one of: Common, Uncommon, Rare, Legendary",
              "threat_level": "Select exactly one of: None, Low, Medium, High, Deadly. Determine the threat level strictly based on documented physical attacks and fatalities caused by this particular animal/organism to humans.",
              "confidence": 100,
              "habitat": "Details about habitat",
              "diet": "Details about diet",
              "distribution": "Details about distribution",
              "iucn_status": "Select exactly one of: Least Concern, Near Threatened, Vulnerable, Endangered, Critically Endangered, Extinct",
              "fun_facts": ["Fact 1", "Fact 2", "Fact 3"]
            }
            No explanation language or markdown ticks. Only raw JSON.
        """.trimIndent()

        val request = GeminiRequest(
            contents = listOf(
                GeminiContent(
                    parts = listOf(
                        GeminiPartConcrete(text = prompt)
                    )
                )
            ),
            generationConfig = GeminiGenerationConfig(
                responseMimeType = "application/json",
                temperature = 0.3f
            )
        )

        val response = service.generateContent(model, apiKey, request)
        val text = response.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text
            ?: return null

        val trimmed = text.trim()
        val cleanedJson = if (trimmed.startsWith("```")) {
            val startIndex = trimmed.indexOf("{")
            val endIndex = trimmed.lastIndexOf("}")
            if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
                trimmed.substring(startIndex, endIndex + 1)
            } else {
                trimmed
            }
        } else {
            trimmed
        }

        return moshi.adapter(ScannedCreatureResponse::class.java).fromJson(cleanedJson)
    }
}
