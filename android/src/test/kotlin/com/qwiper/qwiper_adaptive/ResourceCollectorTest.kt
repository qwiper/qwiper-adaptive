package com.qwiper.qwiper_adaptive

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs

internal class ResourceCollectorTest {
    @Test
    fun preservesTheWireContractAnd64BitByteCounts() {
        val data = ResourceCollector(FakeResourceProbe()).read()

        assertEquals(
            mapOf(
                "logicalProcessors" to 8,
                "isLowRamDevice" to false,
                "memoryClassMb" to 256,
                "totalMemoryBytes" to 8_589_934_592L,
                "availableStorageBytes" to 128_849_018_880L,
            ),
            data,
        )
        assertIs<Long>(data["totalMemoryBytes"])
        assertIs<Long>(data["availableStorageBytes"])
    }

    @Test
    fun eachFailurePreservesAllOtherSignals() {
        val failures: List<(FakeResourceProbe) -> Unit> = listOf(
            { it.processors = { throw IllegalStateException("sensitive detail") } },
            { it.lowRam = { throw SecurityException("sensitive detail") } },
            { it.memoryClass = { throw UnsupportedOperationException("sensitive detail") } },
            { it.totalMemory = { throw IllegalArgumentException("sensitive detail") } },
            { it.storage = { throw SecurityException("private path") } },
        )
        val expected = ResourceCollector(FakeResourceProbe()).read()
        val keys = expected.keys.toList()
        for ((index, fail) in failures.withIndex()) {
            val probe = FakeResourceProbe().also(fail)
            assertEquals(expected - keys[index], ResourceCollector(probe).read())
        }
    }

    @Test
    fun allUnavailableSignalsProduceAnEmptyMap() {
        val probe = FakeResourceProbe().apply {
            processors = { null }
            lowRam = { null }
            memoryClass = { null }
            totalMemory = { null }
            storage = { null }
        }
        assertEquals(emptyMap(), ResourceCollector(probe).read())
    }

    @Test
    fun invalidCountsAreOmittedButAnExactlyFullDiskIsPreserved() {
        val probe = FakeResourceProbe().apply {
            processors = { 0 }
            lowRam = { true }
            memoryClass = { -1 }
            totalMemory = { 0L }
            storage = { 0L }
        }
        assertEquals(
            mapOf("isLowRamDevice" to true, "availableStorageBytes" to 0L),
            ResourceCollector(probe).read(),
        )
    }

    @Test
    fun negativeStorageIsUnavailable() {
        val probe = FakeResourceProbe().apply { storage = { -1L } }
        val expected = ResourceCollector(FakeResourceProbe()).read() - "availableStorageBytes"
        assertEquals(expected, ResourceCollector(probe).read())
    }

    @Test
    fun aNewReadRefreshesEverySignal() {
        val probe = FakeResourceProbe()
        val collector = ResourceCollector(probe)
        val first = collector.read()
        probe.storage = { 0L }
        probe.lowRam = { true }

        assertEquals(0L, collector.read()["availableStorageBytes"])
        assertEquals(true, collector.read()["isLowRamDevice"])
        assertEquals(128_849_018_880L, first["availableStorageBytes"])
    }

    @Test
    fun virtualMachineErrorsAreNotHiddenAsUnavailableData() {
        val probe = FakeResourceProbe().apply {
            processors = { throw OutOfMemoryError("test failure") }
        }
        assertFailsWith<OutOfMemoryError> { ResourceCollector(probe).read() }
    }
}

internal class FakeResourceProbe : ResourceProbe {
    var processors: () -> Int? = { 8 }
    var lowRam: () -> Boolean? = { false }
    var memoryClass: () -> Int? = { 256 }
    var totalMemory: () -> Long? = { 8_589_934_592L }
    var storage: () -> Long? = { 128_849_018_880L }

    override fun logicalProcessors(): Int? = processors()
    override fun isLowRamDevice(): Boolean? = lowRam()
    override fun memoryClassMb(): Int? = memoryClass()
    override fun totalMemoryBytes(): Long? = totalMemory()
    override fun availableStorageBytes(): Long? = storage()
}
