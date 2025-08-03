package com.example.lockity_flutter

import androidx.multidex.MultiDexApplication
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}

class MyApplication : MultiDexApplication() {
    override fun onCreate() {
        super.onCreate()
    }
}