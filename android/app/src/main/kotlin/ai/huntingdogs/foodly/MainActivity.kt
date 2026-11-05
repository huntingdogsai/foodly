package ai.huntingdogs.foodly

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

/**
 * Foodly's "voice note" feature talks to this native recorder over a method channel. It records a few
 * seconds from the phone's microphone (AudioRecord) and reports how long it heard sound for and the loudest
 * sample, so the app can show the shopper that their note was captured. A method-channel result must be
 * delivered on the main thread, so the recording runs on a background thread and the answer is posted back.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "foodly/voice")
            .setMethodCallHandler { call, result ->
                if (call.method == "record") {
                    val seconds = call.argument<Int>("seconds") ?: 3
                    thread {
                        val reply: Map<String, Any> = try {
                            recordNote(seconds)
                        } catch (e: Exception) {
                            mapOf("error" to (e.message ?: "recording failed"))
                        }
                        Handler(Looper.getMainLooper()).post { result.success(reply) }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun recordNote(seconds: Int): Map<String, Any> {
        val rate = 16000
        val minBuffer = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            rate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBuffer, rate * 2),
        )
        recorder.startRecording()
        val buffer = ShortArray(rate)
        var peak = 0
        var samples = 0L
        val end = System.currentTimeMillis() + seconds * 1000L
        while (System.currentTimeMillis() < end) {
            val read = recorder.read(buffer, 0, buffer.size, AudioRecord.READ_NON_BLOCKING)
            if (read > 0) {
                for (i in 0 until read) {
                    val amplitude = Math.abs(buffer[i].toInt())
                    if (amplitude > peak) peak = amplitude
                    samples += 1
                }
            }
            Thread.sleep(20)
        }
        recorder.stop()
        recorder.release()
        return mapOf("ms" to (samples * 1000 / rate).toInt(), "peak" to peak, "samples" to samples.toInt())
    }
}
