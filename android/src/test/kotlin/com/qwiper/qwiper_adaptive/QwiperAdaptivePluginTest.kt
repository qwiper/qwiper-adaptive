package com.qwiper.qwiper_adaptive

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame

internal class QwiperAdaptivePluginTest {
    @Test
    fun registersOnAnEngineOwnedBackgroundQueueWithTheApplicationContext() {
        val fixture = Fixture()
        fixture.plugin.onAttachedToEngine(fixture.binding)

        assertEquals("com.qwiper.adaptive/resources", fixture.messenger.channel)
        assertSame(fixture.messenger.backgroundQueue, fixture.messenger.handlerQueue)
        assertNotNull(fixture.messenger.handler)
        assertSame(fixture.context, fixture.collectorContext)
    }

    @Test
    fun attachedReadReturnsExactlyOneSnapshot() {
        val fixture = Fixture()
        fixture.plugin.onAttachedToEngine(fixture.binding)
        val result = RecordingResult()

        fixture.plugin.onMethodCall(MethodCall("readResources", null), result)

        assertEquals(1, result.replies)
        assertEquals(ResourceCollector(fixture.probe).read(), result.value)
        assertNull(result.errorCode)
    }

    @Test
    fun unrecognizedMethodIsNotImplemented() {
        val result = RecordingResult()
        QwiperAdaptivePlugin().onMethodCall(MethodCall("unknownMethod", null), result)

        assertEquals(1, result.replies)
        assertEquals(true, result.notImplemented)
    }

    @Test
    fun unattachedReadReturnsAnErrorWithoutSensitiveDetails() {
        val result = RecordingResult()
        QwiperAdaptivePlugin().onMethodCall(MethodCall("readResources", null), result)

        assertEquals(1, result.replies)
        assertEquals("unavailable", result.errorCode)
        assertEquals("The resource collector is not attached.", result.errorMessage)
        assertNull(result.errorDetails)
    }

    @Test
    fun detachingRemovesTheHandlerAndCollectorAndSupportsReattaching() {
        val fixture = Fixture()
        fixture.plugin.onAttachedToEngine(fixture.binding)
        fixture.plugin.onDetachedFromEngine(fixture.binding)

        assertNull(fixture.messenger.handler)
        val detached = RecordingResult()
        fixture.plugin.onMethodCall(MethodCall("readResources", null), detached)
        assertEquals("unavailable", detached.errorCode)
        assertEquals(1, detached.replies)

        fixture.plugin.onAttachedToEngine(fixture.binding)
        val attached = RecordingResult()
        fixture.plugin.onMethodCall(MethodCall("readResources", null), attached)
        assertEquals(ResourceCollector(fixture.probe).read(), attached.value)
        assertEquals(1, attached.replies)
    }

    private class Fixture {
        val context: Context = Mockito.mock(Context::class.java)
        val messenger = RecordingMessenger()
        val binding: FlutterPluginBinding = Mockito.mock(FlutterPluginBinding::class.java).also {
            Mockito.`when`(it.applicationContext).thenReturn(context)
            Mockito.`when`(it.binaryMessenger).thenReturn(messenger)
        }
        val probe = FakeResourceProbe()
        var collectorContext: Context? = null
        val plugin = QwiperAdaptivePlugin { suppliedContext ->
            collectorContext = suppliedContext
            ResourceCollector(probe)
        }
    }

    private class RecordingMessenger : BinaryMessenger {
        val backgroundQueue = object : BinaryMessenger.TaskQueue {}
        var channel: String? = null
        var handler: BinaryMessenger.BinaryMessageHandler? = null
        var handlerQueue: BinaryMessenger.TaskQueue? = null

        override fun makeBackgroundTaskQueue(): BinaryMessenger.TaskQueue = backgroundQueue

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
            taskQueue: BinaryMessenger.TaskQueue?,
        ) {
            this.channel = channel
            this.handler = handler
            handlerQueue = taskQueue
        }

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) = error("The plugin must register on its background queue")

        override fun send(channel: String, message: ByteBuffer?) =
            error("This plugin does not send unsolicited messages")

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) = error("This plugin does not send unsolicited messages")
    }

    private class RecordingResult : MethodChannel.Result {
        var replies = 0
        var value: Any? = null
        var errorCode: String? = null
        var errorMessage: String? = null
        var errorDetails: Any? = null
        var notImplemented = false

        override fun success(result: Any?) {
            replies++
            value = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            replies++
            this.errorCode = errorCode
            this.errorMessage = errorMessage
            this.errorDetails = errorDetails
        }

        override fun notImplemented() {
            replies++
            notImplemented = true
        }
    }
}
