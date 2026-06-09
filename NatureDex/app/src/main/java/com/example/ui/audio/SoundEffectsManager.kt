package com.example.ui.audio

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import kotlin.math.sin

object SoundEffectsManager {
    enum class SoundType {
        THROW, HIT, WOBBLE, SUCCESS, ESCAPE
    }

    private var bgmPlayer: android.media.MediaPlayer? = null
    private var isSyntheticBgmPlaying = false
    private var syntheticBgmTrack: AudioTrack? = null
    
    @Volatile
    var isMuted = false

    fun startBgm(context: android.content.Context) {
        synchronized(this) {
            if (isMuted) return
            if (bgmPlayer != null || isSyntheticBgmPlaying) return // Already playing

            // Assign a preparing MediaPlayer to bgmPlayer to prevent other threads from starting BGM
            val player = android.media.MediaPlayer().apply {
                setAudioStreamType(AudioManager.STREAM_MUSIC)
            }
            bgmPlayer = player

            Thread {
                try {
                    val url = "https://www.televisiontunes.com/uploads/audio/Pokemon%20-%20Anime%20Sound%20Collection%20-%20Kanto%20Wild%20Pokemon%20Battle.mp3"
                    player.setDataSource(url)
                    player.isLooping = true
                    player.prepare()

                    synchronized(this) {
                        if (isMuted || bgmPlayer != player) {
                            try {
                                player.release()
                            } catch (e: Exception) {}
                            if (bgmPlayer == player) {
                                bgmPlayer = null
                            }
                            return@Thread
                        }
                        player.start()
                    }
                } catch (e: Exception) {
                    android.util.Log.e("SoundEffectsManager", "Failed to play online BGM, playing synthetic background music instead", e)
                    synchronized(this) {
                        try {
                            player.release()
                        } catch (ex: Exception) {}
                        val wasActivePlayer = (bgmPlayer == player)
                        if (wasActivePlayer) {
                            bgmPlayer = null
                        }
                        if (wasActivePlayer && !isMuted) {
                            playSyntheticBgm()
                        }
                    }
                }
            }.start()
        }
    }

    fun stopBgm() {
        synchronized(this) {
            val player = bgmPlayer
            bgmPlayer = null
            if (player != null) {
                Thread {
                    try {
                        player.stop()
                    } catch (e: Exception) {}
                    try {
                        player.release()
                    } catch (e: Exception) {}
                }.start()
            }
            stopSyntheticBgm()
        }
    }

    private fun playSyntheticBgm() {
        synchronized(this) {
            if (isMuted) return
            if (isSyntheticBgmPlaying) return
            isSyntheticBgmPlaying = true
        }

        Thread {
            var track: AudioTrack? = null
            try {
                val sampleRate = 22050
                // Retro chiptune bass loop notes (repeating sequence)
                val notes = floatArrayOf(110f, 110f, 130f, 146f) // A2, C3, D3
                val noteDurationMs = 250
                val numSamples = (sampleRate * (noteDurationMs / 1000f)).toInt()
                val shortBuffers = notes.map { freq ->
                    val buf = ShortArray(numSamples)
                    for (i in 0 until numSamples) {
                        val angle = 2.0 * Math.PI * freq * (i.toFloat() / sampleRate)
                        val sine = sin(angle).toFloat()
                        // Authentic 8-bit square wave
                        buf[i] = ((if (sine > 0f) 0.15f else -0.15f) * Short.MAX_VALUE).toInt().toShort()
                    }
                    buf
                }

                @Suppress("DEPRECATION")
                val localTrack = AudioTrack(
                    AudioManager.STREAM_MUSIC,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    numSamples * 2,
                    AudioTrack.MODE_STREAM
                )
                
                synchronized(this) {
                    if (isMuted || !isSyntheticBgmPlaying) {
                        try {
                            localTrack.release()
                        } catch (e: Exception) {}
                        return@Thread
                    }
                    track = localTrack
                    syntheticBgmTrack = localTrack
                }

                localTrack.play()

                var noteIndex = 0
                while (true) {
                    synchronized(this) {
                        if (isMuted || !isSyntheticBgmPlaying || syntheticBgmTrack != localTrack) {
                            return@Thread
                        }
                    }
                    val buf = shortBuffers[noteIndex]
                    localTrack.write(buf, 0, buf.size)
                    noteIndex = (noteIndex + 1) % shortBuffers.size
                }
            } catch (e: Exception) {
                android.util.Log.e("SoundEffectsManager", "Failed playing synthetic BGM", e)
            } finally {
                synchronized(this) {
                    if (syntheticBgmTrack == track) {
                        syntheticBgmTrack = null
                    }
                    isSyntheticBgmPlaying = false
                }
                if (track != null) {
                    try {
                        track?.stop()
                    } catch (e: Exception) {}
                    try {
                        track?.release()
                    } catch (e: Exception) {}
                }
            }
        }.start()
    }

    private fun stopSyntheticBgm() {
        synchronized(this) {
            isSyntheticBgmPlaying = false
            val track = syntheticBgmTrack
            syntheticBgmTrack = null
            if (track != null) {
                Thread {
                    try {
                        track.stop()
                    } catch (e: Exception) {}
                    try {
                        track.release()
                    } catch (e: Exception) {}
                }.start()
            }
        }
    }

    fun playSound(context: android.content.Context, type: SoundType) {
        synchronized(this) {
            if (isMuted) return
        }
        val resourceName = when (type) {
            SoundType.THROW -> "poke_throw"
            SoundType.HIT -> "poke_hit"
            SoundType.WOBBLE -> "poke_wobble"
            SoundType.SUCCESS -> "poke_success"
            SoundType.ESCAPE -> "poke_escape"
        }

        val resId = context.resources.getIdentifier(resourceName, "raw", context.packageName)
        if (resId != 0) {
            try {
                val mp = android.media.MediaPlayer.create(context, resId)
                mp.setOnCompletionListener { it.release() }
                synchronized(this) {
                    if (isMuted) {
                        mp.release()
                        return
                    }
                }
                mp.start()
                return
            } catch (e: Exception) {
                android.util.Log.e("SoundEffectsManager", "Failed to play raw resource: $resourceName", e)
            }
        }

        // Fallback: Generate custom 8-bit retro sound synthetically via AudioTrack
        playSyntheticSound(type)
    }

    private fun playSyntheticSound(type: SoundType) {
        synchronized(this) {
            if (isMuted) return
        }
        Thread {
            try {
                val sampleRate = 22050
                val durationMs = when (type) {
                    SoundType.THROW -> 150
                    SoundType.HIT -> 120
                    SoundType.WOBBLE -> 180
                    SoundType.SUCCESS -> 800
                    SoundType.ESCAPE -> 250
                }
                val numSamples = (sampleRate * (durationMs / 1000f)).toInt()
                val samples = FloatArray(numSamples)

                when (type) {
                    SoundType.THROW -> {
                        // Rising frequency sweep (zip sound) - Square Wave
                        for (i in 0 until numSamples) {
                            val t = i.toFloat() / numSamples
                            val freq = 220f + t * 900f
                            val angle = 2.0 * Math.PI * freq * (i.toFloat() / sampleRate)
                            val sine = sin(angle).toFloat()
                            samples[i] = (if (sine > 0f) 0.35f else -0.35f) * (1f - t)
                        }
                    }
                    SoundType.HIT -> {
                        // Hit Sound: Short white-noise crunch
                        val random = java.util.Random()
                        for (i in 0 until numSamples) {
                            val t = i.toFloat() / numSamples
                            val noise = random.nextFloat() * 2f - 1f
                            samples[i] = noise * 0.5f * (1f - t) * (1f - t)
                        }
                    }
                    SoundType.WOBBLE -> {
                        // Double click shake sound: C6 followed by G5
                        for (i in 0 until numSamples) {
                            val t = i.toFloat() / numSamples
                            val freq = if (t < 0.35f) 1046.50f else 783.99f
                            val angle = 2.0 * Math.PI * freq * (i.toFloat() / sampleRate)
                            val sine = sin(angle).toFloat()
                            val volume = if (t in 0.30f..0.40f) 0f else 0.4f
                            samples[i] = (if (sine > 0f) volume else -volume)
                        }
                    }
                    SoundType.SUCCESS -> {
                        // Fanfare: G5, G5, G5, G5, Bb5, C6, Bb5, C6
                        val notes = floatArrayOf(783.99f, 783.99f, 783.99f, 783.99f, 932.33f, 1046.50f, 932.33f, 1046.50f)
                        val noteDuration = numSamples / notes.size
                        for (i in 0 until numSamples) {
                            val noteIdx = (i / noteDuration).coerceIn(0, notes.lastIndex)
                            val freq = notes[noteIdx]
                            val angle = 2.0 * Math.PI * freq * (i.toFloat() / sampleRate)
                            val sine = sin(angle).toFloat()
                            samples[i] = (if (sine > 0f) 0.3f else -0.3f)
                        }
                    }
                    SoundType.ESCAPE -> {
                        // Buzzer breakout: descending sawtooth wave
                        for (i in 0 until numSamples) {
                            val t = i.toFloat() / numSamples
                            val freq = 550f - t * 350f
                            samples[i] = (((i * freq / sampleRate) % 1.0f) * 2f - 1f) * 0.35f * (1f - t)
                        }
                    }
                }

                // Convert float samples to 16-bit PCM bytes
                val buffer = ShortArray(numSamples)
                for (i in 0 until numSamples) {
                    buffer[i] = (samples[i] * Short.MAX_VALUE).toInt().toShort()
                }

                @Suppress("DEPRECATION")
                val audioTrack = AudioTrack(
                    AudioManager.STREAM_MUSIC,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    buffer.size * 2,
                    AudioTrack.MODE_STATIC
                )

                synchronized(this) {
                    if (isMuted) {
                        try {
                            audioTrack.release()
                        } catch (e: Exception) {}
                        return@Thread
                    }
                }

                audioTrack.write(buffer, 0, buffer.size)
                audioTrack.play()

                Thread.sleep(durationMs.toLong() + 50)
                try {
                    audioTrack.stop()
                } catch (e: Exception) {}
                try {
                    audioTrack.release()
                } catch (e: Exception) {}
            } catch (e: Exception) {
                android.util.Log.e("SoundEffectsManager", "Failed to play synthetic sound", e)
            }
        }.start()
    }
}
