package com.qwiper.qwiper_adaptive

import android.app.ActivityManager
import android.content.Context
import android.os.StatFs

/** Collects only public Android signals; no runtime or manifest permission is needed. */
internal class AndroidResourceProbe(private val applicationContext: Context) : ResourceProbe {
    override fun logicalProcessors(): Int = Runtime.getRuntime().availableProcessors()

    override fun isLowRamDevice(): Boolean? = activityManager()?.isLowRamDevice

    override fun memoryClassMb(): Int? = activityManager()?.memoryClass

    override fun totalMemoryBytes(): Long? {
        val manager = activityManager() ?: return null
        return ActivityManager.MemoryInfo().also(manager::getMemoryInfo).totalMem
    }

    override fun availableStorageBytes(): Long =
        StatFs(applicationContext.filesDir.absolutePath).availableBytes

    private fun activityManager(): ActivityManager? =
        applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
}
