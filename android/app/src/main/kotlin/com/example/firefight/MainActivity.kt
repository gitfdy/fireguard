package com.example.firefight

import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fireguard.alarm/audio"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarmStream" -> {
                    try {
                        // 设置音频流类型为ALARM，这样即使在静音模式下也能播放
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            audioManager.adjustStreamVolume(
                                AudioManager.STREAM_ALARM,
                                AudioManager.ADJUST_SAME,
                                0
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to set alarm stream", e.message)
                    }
                }
                "playSystemAlarm" -> {
                    try {
                        playSystemAlarmSound()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to play alarm", e.message)
                    }
                }
                "stopAlarmSound" -> {
                    try {
                        stopAlarmSound()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to stop alarm", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun playSystemAlarmSound() {
        try {
            // 停止之前的播放
            stopAlarmSound()
            
            // 获取系统默认的报警音
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (alarmUri != null) {
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(applicationContext, alarmUri)
                    setAudioStreamType(AudioManager.STREAM_ALARM) // 使用ALARM音频流
                    isLooping = true // 循环播放
                    prepare()
                    start()
                }
            } else {
                // 如果系统没有默认报警音，使用通知音
                val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                if (notificationUri != null) {
                    mediaPlayer = MediaPlayer().apply {
                        setDataSource(applicationContext, notificationUri)
                        setAudioStreamType(AudioManager.STREAM_ALARM)
                        isLooping = true
                        prepare()
                        start()
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAlarmSound() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
            mediaPlayer = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarmSound()
    }
}
