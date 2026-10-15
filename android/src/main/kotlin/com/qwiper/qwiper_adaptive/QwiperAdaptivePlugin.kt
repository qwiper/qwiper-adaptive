package com.qwiper.qwiper_adaptive

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Reads coarse resource signals using the application context, without an Activity. */
class QwiperAdaptivePlugin internal constructor(
    private val createCollector: (Context) -> ResourceCollector,
) : FlutterPlugin, MethodChannel.MethodCallHandler {
    constructor() : this({ context -> ResourceCollector(AndroidResourceProbe(context)) })

    private var channel: MethodChannel? = null

    // Method calls run on the engine's background task queue; lifecycle callbacks run
    // on the platform thread. A call already in progress may finish during detach.
    @Volatile
    private var collector: ResourceCollector? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        collector = createCollector(binding.applicationContext)
        channel = MethodChannel(
            binding.binaryMessenger,
            CHANNEL_NAME,
            StandardMethodCodec.INSTANCE,
            binding.binaryMessenger.makeBackgroundTaskQueue(),
        ).also { it.setMethodCallHandler(this) }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "readResources") {
            result.notImplemented()
            return
        }

        val currentCollector = collector
        if (currentCollector == null) {
            result.error("unavailable", "The resource collector is not attached.", null)
            return
        }
        result.success(currentCollector.read())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        collector = null
        // The task queue is owned and disposed by Flutter's engine. This plugin
        // owns no executor, Activity reference, observer, or persistent cache.
    }

    private companion object {
        const val CHANNEL_NAME = "com.qwiper.adaptive/resources"
    }
}
