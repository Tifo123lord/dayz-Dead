package com.deadlandafterzero.game

import android.media.AudioManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var sfx: GameSoundEngine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Hardware volume keys control the media stream (game audio).
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sfx?.dispose()
        sfx = GameSoundEngine(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sfx?.dispose()
        sfx = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onPause() {
        sfx?.pause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        sfx?.resume()
    }
}
