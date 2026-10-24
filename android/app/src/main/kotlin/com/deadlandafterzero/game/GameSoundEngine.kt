package com.deadlandafterzero.game

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.ArrayDeque

/**
 * Low-latency game sound effects on top of Android [SoundPool].
 *
 * Why not MediaPlayer (audioplayers' default)?
 *  - every MediaPlayer requests audio focus, so each new shot made the other
 *    players lose focus and pause -> sounds cutting in and out;
 *  - devices only have a limited number of MediaPlayer decoders;
 *  - stop/seek/prepare per shot adds 50-150 ms of latency and many
 *    platform-channel round trips per sound.
 *
 * SoundPool decodes every clip to PCM once and mixes up to [MAX_STREAMS]
 * voices in the native mixer with no audio focus at all. Each play is a
 * single channel message.
 */
class GameSoundEngine(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "deadland/sfx"
        private const val MAX_STREAMS = 32
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    private val pool: SoundPool = SoundPool.Builder()
        .setMaxStreams(MAX_STREAMS)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        .build()

    /** asset path -> SoundPool sample id */
    private val ids = HashMap<String, Int>()
    private val loaded = HashSet<Int>()

    /** sample id -> callbacks waiting for the decode to finish */
    private val waiting = HashMap<Int, MutableList<() -> Unit>>()

    /** voice group -> active stream ids (oldest first) */
    private val groups = HashMap<Int, ArrayDeque<Int>>()

    init {
        channel.setMethodCallHandler(this)
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) loaded.add(sampleId)
            waiting.remove(sampleId)?.forEach { it() }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "play" -> {
                    // [sampleId, group, volume, pan, rate, maxVoices, priority, loop]
                    val a = call.arguments as List<*>
                    play(
                        (a[0] as Number).toInt(),
                        (a[1] as Number).toInt(),
                        (a[2] as Number).toFloat(),
                        (a[3] as Number).toFloat(),
                        (a[4] as Number).toFloat(),
                        (a[5] as Number).toInt(),
                        (a[6] as Number).toInt(),
                        (a[7] as Number).toInt(),
                    )
                    result.success(null)
                }
                "stopGroup" -> {
                    stopGroup((call.arguments as Number).toInt())
                    result.success(null)
                }
                "stopAll" -> {
                    for (g in groups.keys.toList()) stopGroup(g)
                    result.success(null)
                }
                "pauseAll" -> {
                    pool.autoPause()
                    result.success(null)
                }
                "resumeAll" -> {
                    pool.autoResume()
                    result.success(null)
                }
                "load" -> load(call.arguments as List<*>, result)
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("sfx", e.message, null)
        }
    }

    /** Loads all assets and replies with {asset: sampleId} once decoded. */
    private fun load(assets: List<*>, result: MethodChannel.Result) {
        val out = HashMap<String, Int>()
        var pending = 0
        var replied = false
        fun done() {
            if (!replied && pending <= 0) {
                replied = true
                result.success(out)
            }
        }
        for (raw in assets) {
            val asset = raw as String
            val known = ids[asset]
            if (known != null) {
                if (loaded.contains(known)) out[asset] = known
                continue
            }
            val id = loadOne(asset) ?: continue
            ids[asset] = id
            pending++
            waiting.getOrPut(id) { mutableListOf() }.add {
                if (loaded.contains(id)) out[asset] = id
                pending--
                done()
            }
        }
        done()
        // Safety net: never leave Dart waiting forever.
        main.postDelayed({
            pending = 0
            done()
        }, 8000)
    }

    private fun loadOne(asset: String): Int? {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        return try {
            context.assets.openFd(key).use { fd -> pool.load(fd, 1) }
        } catch (_: Throwable) {
            // Asset is compressed inside the APK: copy it to the cache once.
            try {
                val f = File(context.cacheDir, "sfx_" + asset.replace('/', '_'))
                if (!f.exists() || f.length() == 0L) {
                    context.assets.open(key).use { input ->
                        f.outputStream().use { input.copyTo(it) }
                    }
                }
                pool.load(f.absolutePath, 1)
            } catch (_: Throwable) {
                null
            }
        }
    }

    private fun play(
        sampleId: Int,
        group: Int,
        volume: Float,
        pan: Float,
        rate: Float,
        maxVoices: Int,
        priority: Int,
        loop: Int,
    ) {
        if (!loaded.contains(sampleId)) return
        val v = volume.coerceIn(0f, 1f)
        if (v <= 0.001f) return
        val p = pan.coerceIn(-1f, 1f)
        val left = v * minOf(1f, 1f - p)
        val right = v * minOf(1f, 1f + p)
        val q = groups.getOrPut(group) { ArrayDeque() }
        // Voice limit per group: steal the oldest voice of this group only.
        while (maxVoices > 0 && q.size >= maxVoices) {
            pool.stop(q.pollFirst()!!)
        }
        val stream = pool.play(sampleId, left, right, priority, loop, rate.coerceIn(0.5f, 2f))
        if (stream != 0) q.addLast(stream)
    }

    private fun stopGroup(group: Int) {
        val q = groups[group] ?: return
        while (q.isNotEmpty()) pool.stop(q.pollFirst()!!)
    }

    fun pause() = pool.autoPause()

    fun resume() = pool.autoResume()

    fun dispose() {
        channel.setMethodCallHandler(null)
        main.removeCallbacksAndMessages(null)
        pool.release()
    }
}
