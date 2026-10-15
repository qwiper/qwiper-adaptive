package com.qwiper.qwiper_adaptive

/** Each measurement is independent: unavailable signals are omitted, never invented. */
internal interface ResourceProbe {
    fun logicalProcessors(): Int?
    fun isLowRamDevice(): Boolean?
    fun memoryClassMb(): Int?
    fun totalMemoryBytes(): Long?
    fun availableStorageBytes(): Long?
}

/** Plain Kotlin boundary so partial failures and wire types can be tested on the JVM. */
internal class ResourceCollector(private val probe: ResourceProbe) {
    fun read(): Map<String, Any> = buildMap {
        measure { probe.logicalProcessors()?.takeIf { it > 0 } }
            ?.let { put("logicalProcessors", it) }
        measure { probe.isLowRamDevice() }
            ?.let { put("isLowRamDevice", it) }
        measure { probe.memoryClassMb()?.takeIf { it > 0 } }
            ?.let { put("memoryClassMb", it) }
        measure { probe.totalMemoryBytes()?.takeIf { it > 0L } }
            ?.let { put("totalMemoryBytes", it) }
        measure { probe.availableStorageBytes()?.takeIf { it >= 0L } }
            ?.let { put("availableStorageBytes", it) }
    }

    private fun <T> measure(block: () -> T?): T? = try {
        block()
    } catch (_: Exception) {
        // OEM service failures, unavailable storage and permission failures are
        // absence of evidence. Do not expose exception messages, paths or logs.
        // VM errors deliberately propagate; they are not missing measurements.
        null
    }
}
