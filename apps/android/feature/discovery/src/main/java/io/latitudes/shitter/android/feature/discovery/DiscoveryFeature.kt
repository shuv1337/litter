package io.latitudes.shitter.android.feature.discovery

import io.latitudes.shitter.android.core.network.DiscoveredServer
import io.latitudes.shitter.android.core.network.ServerDiscoveryService

class DiscoveryFeature(
    private val discoveryService: ServerDiscoveryService,
) {
    fun discoverServers(): List<DiscoveredServer> = discoveryService.discover()
}
