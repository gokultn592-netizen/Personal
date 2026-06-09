package com.example.data

import com.squareup.moshi.Json
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.GET
import retrofit2.http.Query
import java.util.concurrent.TimeUnit

// --- API Models ---

data class TaxaResponse(
    @Json(name = "total_results") val totalResults: Int,
    @Json(name = "page") val page: Int,
    @Json(name = "per_page") val perPage: Int,
    @Json(name = "results") val results: List<Taxon>
)

data class Taxon(
    @Json(name = "id") val id: Int,
    @Json(name = "name") val name: String, // Scientific name
    @Json(name = "preferred_common_name") val preferredCommonName: String?, // Common name
    @Json(name = "default_photo") val defaultPhoto: DefaultPhoto?,
    @Json(name = "iconic_taxon_name") val iconicTaxonName: String?, // e.g. Aves, Mammalia, Insecta
    @Json(name = "wikipedia_url") val wikipediaUrl: String?
)

data class DefaultPhoto(
    @Json(name = "id") val id: Int,
    @Json(name = "url") val url: String?, // Small url
    @Json(name = "medium_url") val mediumUrl: String?, // Medium url
    @Json(name = "square_url") val squareUrl: String? // Square url
) {
    fun getDisplayUrl(): String {
        return mediumUrl ?: url ?: squareUrl ?: ""
    }
}

// --- Retrofit Interface ---

interface INaturalistService {
    @GET("v1/taxa")
    suspend fun searchTaxa(
        @Query("q") query: String,
        @Query("rank") rank: String = "species",
        @Query("per_page") perPage: Int = 15,
        @Query("iconic_taxa") iconicTaxa: String? = null
    ): TaxaResponse

    @GET("v1/taxa/autocomplete")
    suspend fun autocompleteTaxa(
        @Query("q") query: String,
        @Query("rank") rank: String = "species",
        @Query("per_page") perPage: Int = 15,
        @Query("iconic_taxa") iconicTaxa: String? = null
    ): TaxaResponse

    @GET("v1/taxa")
    suspend fun getPopularTaxa(
        @Query("is_active") isActive: Boolean = true,
        @Query("rank") rank: String = "species",
        @Query("per_page") perPage: Int = 20,
        @Query("iconic_taxa") iconicTaxa: String? = null
    ): TaxaResponse
}

// --- API Client ---

object INaturalistClient {
    private const val BASE_URL = "https://api.inaturalist.org/"

    private val moshi = Moshi.Builder()
        .addLast(KotlinJsonAdapterFactory())
        .build()

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    val service: INaturalistService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(INaturalistService::class.java)
    }
}
