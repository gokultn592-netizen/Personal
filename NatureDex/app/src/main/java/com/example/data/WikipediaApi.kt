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

// --- Wikipedia API Models ---

data class WikipediaResponse(
    @Json(name = "query") val query: WikipediaQuery?
)

data class WikipediaQuery(
    @Json(name = "pages") val pages: Map<String, WikipediaPage>?
)

data class WikipediaPage(
    @Json(name = "pageid") val pageid: Int?,
    @Json(name = "title") val title: String?,
    @Json(name = "thumbnail") val thumbnail: WikipediaThumbnail?
)

data class WikipediaThumbnail(
    @Json(name = "source") val source: String?,
    @Json(name = "width") val width: Int?,
    @Json(name = "height") val height: Int?
)

// --- Retrofit Interface ---

interface WikipediaService {
    @GET("w/api.php")
    suspend fun getPageImage(
        @Query("action") action: String = "query",
        @Query("prop") prop: String = "pageimages",
        @Query("format") format: String = "json",
        @Query("piprop") piprop: String = "thumbnail",
        @Query("pithumbsize") pithumbsize: Int = 800,
        @Query("titles") titles: String,
        @Query("redirects") redirects: Int = 1
    ): WikipediaResponse
}

// --- API Client ---

object WikipediaClient {
    private const val BASE_URL = "https://en.wikipedia.org/"

    private val moshi = Moshi.Builder()
        .addLast(KotlinJsonAdapterFactory())
        .build()

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    val service: WikipediaService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
            .create(WikipediaService::class.java)
    }
}
