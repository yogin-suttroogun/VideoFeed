//
//  VideoPrefetchManager.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import Foundation
import Network
import AVFoundation
import Combine

// MARK: - Enums

/**
 Represents the type of network connection currently available.
 
 Used to determine appropriate video prefetching strategies based on bandwidth
 and data usage considerations.
 */
enum ConnectionType {
    /// WiFi connection - typically unlimited data with high bandwidth
    case wifi
    /// Cellular connection - may have data limits and variable bandwidth
    case cellular
    /// Unknown or no connection - conservative approach recommended
    case unknown
}

/**
 Defines video prefetching strategies based on network conditions and user preferences.
 
 Each strategy determines how many videos ahead of the current position should be
 prefetched to balance smooth playback with resource usage.
 */
enum PrefetchStrategy {
    /// Prefetch many videos ahead - suitable for WiFi connections
    case aggressive
    /// Moderate prefetching - suitable for good cellular connections
    case conservative
    /// Minimal prefetching - suitable for poor connections or data-sensitive scenarios
    case minimal
    
    /**
     The number of videos to prefetch ahead of the current position.
     
     - Returns: Integer representing the prefetch count for this strategy.
     */
    var prefetchCount: Int {
        switch self {
        case .aggressive:
            return 7
        case .conservative:
            return 3
        case .minimal:
            return 1
        }
    }
}

/**
 Manages intelligent video prefetching based on network conditions and user behavior.
 
 `VideoPrefetchManager` monitors network connectivity and automatically adjusts
 video prefetching strategies to optimize the balance between smooth playback
 and resource usage (bandwidth, battery, memory).
 
 ## Key Features
 - Network-aware prefetching strategies
 - Automatic strategy adjustment based on connection type
 - Intelligent asset cleanup to prevent memory growth
 - Reactive updates through Combine publishers
 - Delegate pattern for strategy change notifications
 
 ## Network Strategy Mapping
 - **WiFi**: Aggressive prefetching (7 videos)
 - **Cellular**: Conservative prefetching (3 videos)
 - **Unknown**: Minimal prefetching (1 video)
 
 ## Usage
 ```swift
 let manager = VideoPrefetchManager()
 
 // Monitor strategy changes
 prefetchManager.prefetchStrategyPublisher.sink { strategy in
     // Update UI or logging based on strategy
 }
 
 // Trigger prefetching around current position
 manager.prefetchVideos(around: currentIndex, videos: videoArray)
 ```
 */
class VideoPrefetchManager {
    
    // MARK: - Properties
    
    /// Network path monitor for detecting connection changes
    private let monitor = NWPathMonitor()
    /// Background queue for network monitoring operations
    private let queue = DispatchQueue(label: "prefetch.monitor")
    /// Cache of prefetched video assets mapped by video index
    private var prefetchedAssets: [Int: AVAsset] = [:]
    
    // MARK: - Publishers
    /// Subject for publishing prefetch strategy changes
    private let strategySubject = CurrentValueSubject<PrefetchStrategy, Never>(.conservative)
    /// Subject for publishing connection type changes
    private let connectionTypeSubject = CurrentValueSubject<ConnectionType, Never>(.cellular)
    
    // MARK: - Public Publishers
    /**
     Publisher that emits when the prefetch strategy changes.
     
     Subscribe to this to react to network-driven strategy changes:
     ```swift
     prefetchManager.prefetchStrategyPublisher.sink { strategy in
        print("Strategy changed to: \(strategy)")
     }
     ```
     */
    var prefetchStrategyPublisher: AnyPublisher<PrefetchStrategy, Never> {
        strategySubject.eraseToAnyPublisher()
    }
    /**
     Publisher that emits when the connection type changes.
     
     Useful for UI updates or analytics tracking of network conditions.
     */
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        connectionTypeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    
    /**
     The current network connection type.
     
     Updated automatically as network conditions change.
     */
    private(set) var currentConnectionType: ConnectionType = .cellular {
        didSet {
            connectionTypeSubject.send(currentConnectionType)
        }
    }
    
    /**
     The current prefetch strategy being used.
     
     Automatically determined based on network conditions but can be observed
     for UI updates or behavior adjustments.
     */
    private(set) var prefetchStrategy: PrefetchStrategy = .conservative {
        didSet {
            if prefetchStrategy != oldValue {
                strategySubject.send(prefetchStrategy)
            }
        }
    }
    
    // MARK: - Initialization
        
    /**
     Initializes the prefetch manager and starts network monitoring.
     
     Automatically begins monitoring network conditions and will update
     prefetch strategies as connectivity changes.
     */
    init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
        
    /**
     Starts monitoring network path changes.
     
     Sets up the NWPathMonitor to detect changes in network connectivity
     and automatically update prefetch strategies accordingly.
     */
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStrategy(for: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    /**
     Updates connection type and prefetch strategy based on network path.
     
     - Parameter path: The current network path from NWPath.
     
     ## Strategy Logic
     - WiFi connection → Aggressive prefetching
     - Cellular connection → Conservative prefetching
     - No/unknown connection → Minimal prefetching
     */
    private func updateConnectionStrategy(for path: NWPath) {
        let newConnectionType: ConnectionType
        let newStrategy: PrefetchStrategy
        
        if path.usesInterfaceType(.wifi) {
            newConnectionType = .wifi
            newStrategy = .aggressive
        } else if path.usesInterfaceType(.cellular) {
            newConnectionType = .cellular
            newStrategy = .conservative
        } else {
            newConnectionType = .unknown
            newStrategy = .minimal
        }
        
        currentConnectionType = newConnectionType
        prefetchStrategy = newStrategy
    }
    
    // MARK: - Prefetching
        
    /**
     Prefetches videos around the specified current index.
     
     - Parameters:
     - currentIndex: The index of the currently playing video.
     - videos: The complete array of video items available.
     
     ## Behavior
     - Prefetches videos according to current strategy
     - Starts from one position before current index
     - Extends forward based on strategy's prefetch count
     - Automatically cleans up old prefetched assets
     - Skips videos that are already prefetched
     */
    func prefetchVideos(around currentIndex: Int, videos: [VideoItem]) {
        let count = prefetchStrategy.prefetchCount
        let startIndex = max(0, currentIndex - 1)
        let endIndex = min(videos.count - 1, currentIndex + count)
        
        for index in startIndex...endIndex {
            if prefetchedAssets[index] == nil && index < videos.count {
                prefetchVideo(videos[index])
            }
        }
        
        cleanUpPrefetches(currentIndex: currentIndex, totalVideos: videos.count)
    }
    
    /**
     Prefetches a single video asset.
     
     - Parameter video: The video item to prefetch.
     
     Creates an AVURLAsset and begins loading essential properties like
     duration and playability. The asset is stored in the prefetch cache
     for quick access when needed.
     */
    private func prefetchVideo(_ video: VideoItem) {
        guard let url = video.url,
              let index = video.index else { return }
        
        let asset = AVURLAsset(url: url)
        prefetchedAssets[index] = asset
        
        // Start loading key values asynchronously
        asset.loadValuesAsynchronously(forKeys: ["duration", "playable"])
    }
    
    /**
     Removes prefetched assets that are no longer needed.
     
     - Parameters:
     - currentIndex: The current video position.
     - totalVideos: The total number of videos available.
     
     Maintains a reasonable cache size by removing assets that are far from
     the current position and unlikely to be needed soon.
     */
    private func cleanUpPrefetches(currentIndex: Int, totalVideos: Int) {
        let keepRange = (currentIndex - 2)...(currentIndex + prefetchStrategy.prefetchCount + 2)
        let indicesToRemove = prefetchedAssets.keys.filter { !keepRange.contains($0) }
        
        for index in indicesToRemove {
            prefetchedAssets.removeValue(forKey: index)
        }
    }
    
    // MARK: - Asset Access
    
    /**
     Retrieves a prefetched asset for the specified index.
     
     - Parameter index: The video index to retrieve.
     - Returns: The prefetched `AVAsset` if available, `nil` otherwise.
     
     Use this to check if a video has been prefetched before creating players.
     */
    func getPrefetchedAsset(for index: Int) -> AVAsset? {
        return prefetchedAssets[index]
    }
    
    /**
     Checks if a video at the specified index has been prefetched.
     
     - Parameter index: The video index to check.
     - Returns: `true` if the video has been prefetched, `false` otherwise.
     
     Useful for UI indicators or deciding whether to show loading states.
     */
    func isPrefetched(index: Int) -> Bool {
        return prefetchedAssets[index] != nil
    }
    
    // MARK: - Cleanup
    /**
     Performs comprehensive cleanup of all resources.
     
     ## Cleanup Process
     1. Cancels network monitoring
     2. Clears all prefetched assets
     3. Completes Combine subjects
     
     Should be called when the manager is no longer needed to prevent
     resource leaks and unnecessary network monitoring.
     */
    func cleanUp() {
        monitor.cancel()
        prefetchedAssets.removeAll()
        strategySubject.send(completion: .finished)
        connectionTypeSubject.send(completion: .finished)
    }
    
    deinit {
        cleanUp()
    }
}
