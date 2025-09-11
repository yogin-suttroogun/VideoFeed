//
//  VideoPlayerPool.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import UIKit
import Combine
import AVFoundation

/**
 A pool manager for efficient AVPlayer instance reuse and lifecycle management.
 
 `VideoPlayerPool` implements the Object Pool pattern to optimize memory usage and performance
 when displaying multiple videos in a feed. Instead of creating and destroying players for each
 video cell, it maintains a pool of reusable players.
 
 ## Key Features
 - Limits concurrent player instances to prevent memory issues
 - Automatically configures audio session for video playback
 - Handles player readiness monitoring and notifications
 - Manages video looping and playback state
 - Provides reactive updates through Combine publishers
 
 ## Memory Management
 The pool maintains a maximum of 5 active players and reuses them as videos scroll.
 This prevents memory growth while maintaining smooth playback performance.
 
 ## Usage
 ```swift
 let videoPlayerPool = VideoPlayerPool()
 let player = videoPlayerPool.getPlayer(for: 0, url: videoURL)
 
 // Monitor readiness
 pool.playerReadinessPublisher.sink { index in
     // Player at index is ready for playback
 }
 
 // Clean up when done
 pool.releasePlayer(for: 0)
 ```
 */

class VideoPlayerPool: NSObject {
    // MARK: - Configuration
        
    /// Maximum number of concurrent AVPlayer instances to maintain
    private let maxPlayers = 5
    
    // MARK: - Private Properties
        
    /// Pool of available player instances ready for reuse
    private var playerPool: [AVPlayer] = []
    /// Active player assignments mapped by video index
    private var activeAssignments: [Int: AVPlayer] = [:]
    /// Tracks readiness state of each player
    private var playerReadiness: [AVPlayer: Bool] = [:]
    
    // MARK: - Publishers
        
    /// Publisher that emits when a player becomes ready for playback
    let playerReadinessPublisher = PassthroughSubject<Int, Never>()
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /**
     Initializes the video player pool.
     
     Sets up the audio session for video playback and configures notification observers
     for handling video completion events.
     */
    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    // MARK: - Audio Session Setup
    
    /**
     Configures the AVAudioSession for video playback.
     
     Sets the audio session category to `.playback` with default mode to ensure
     videos can play audio even when the device is in silent mode.
     
     - Note: Errors are currently logged to console. Consider implementing
     proper error handling for production use.
     */
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error)")
        }
    }
    
    // MARK: - Notification Handling
        
    /**
     Sets up notification observers for player lifecycle events.
     
     Currently observes `AVPlayerItemDidPlayToEndTime` to implement automatic
     video looping functionality.
     */
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] notification in
                self?.playerVideoDidReachEnd(notification)
            }
            .store(in: &cancellables)
    }
    
    /**
     Handles video completion notifications to implement looping.
     
     - Parameter notification: The notification containing the completed player item.
     
     When a video reaches its end, this method automatically seeks back to the beginning
     and restarts playback to create a seamless loop.
     */
    @objc private func playerVideoDidReachEnd(_ notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem,
              let player = activeAssignments.values.first(where: { $0.currentItem == playerItem }) else {
            return
        }
        
        player.seek(to: .zero)
        player.play()
    }
    
    /**
     Pauses all currently active video players.
     
     Used when the app enters background, during scrolling, or when switching
     between videos to prevent audio conflicts and conserve resources.
     */
    func pauseAllPlayers() {
        for (_, player) in activeAssignments {
            player.pause()
        }
    }
    
    /**
     Retrieves or creates a player for the specified video index and URL.
     
     - Parameters:
     - index: The unique index identifying the video position.
     - url: The URL of the video to be played.
     
     - Returns: An `AVPlayer` instance configured for the specified video.
     
     ## Behavior
     - Returns existing player if already assigned to the index
     - Creates new player if pool is empty
     - Reuses available player from pool otherwise
     - Configures player with the provided URL and monitoring
     */
    func getPlayer(for index: Int, url: URL) -> AVPlayer {
        // Return existing player if already assigned
        if let existingPlayer = activeAssignments[index] {
            return existingPlayer
        }
        
        // Get or create a player
        let player: AVPlayer
        if playerPool.isEmpty {
            player = AVPlayer()
            player.automaticallyWaitsToMinimizeStalling = true
        } else {
            player = playerPool.removeFirst()
        }
        
        // Configure the player
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.actionAtItemEnd = .none
        playerReadiness[player] = false
        
        // Monitor readiness
        playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        
        activeAssignments[index] = player
        return player
    }
    
    /**
     Key-Value Observing callback for monitoring player item status changes.
     
     - Parameters:
     - keyPath: The key path being observed ("status").
     - object: The object being observed (AVPlayerItem).
     - change: Dictionary of change information.
     - context: Context pointer (unused).
     
     Monitors when player items become ready to play and publishes readiness events.
     */
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status",
           let playerItem = object as? AVPlayerItem,
           let player = activeAssignments.values.first(where: { $0.currentItem == playerItem }) {
            
            if playerItem.status == .readyToPlay {
                playerReadiness[player] = true
                if let index = activeAssignments.first(where: { $0.value == player })?.key {
                    playerReadinessPublisher.send(index)
                }
            }
        }
    }
    
    /**
     Checks if the player for the specified index is ready for playback.
     
     - Parameter index: The video index to check.
     - Returns: `true` if the player is ready to play, `false` otherwise.
     
     A player is considered ready when its current item has loaded successfully
     and is prepared for playback.
     */
    func isPlayerReady(for index: Int) -> Bool {
        guard let player = activeAssignments[index] else { return false }
        return playerReadiness[player] ?? false
    }
    
    /**
     Releases a player associated with the specified index.
     
     - Parameter index: The video index whose player should be released.
     
     ## Process
     1. Removes the player from active assignments
     2. Pauses playback and clears the current item
     3. Removes KVO observer to prevent memory leaks
     4. Returns player to pool if under capacity
     5. Cleans up readiness tracking
     
     - Note: Consider adding error handling for observer removal failures.
     */
    func releasePlayer(for index: Int) {
        guard
            let player = activeAssignments.removeValue(forKey: index)
        else {
            return
        }
        
        player.pause()
        player.currentItem?.removeObserver(self, forKeyPath: "status")
        player.replaceCurrentItem(with: nil)
        playerReadiness.removeValue(forKey: player)
        
        // Return to pool if not at capacity
        if playerPool.count < maxPlayers {
            playerPool.append(player)
        }
    }
    
    /**
     Starts playback for the player at the specified index.
     
     - Parameter index: The video index to start playing.
     
     Only starts playback if the player exists and is ready. This prevents
     attempting to play videos that haven't finished loading.
     
     - Note: Consider adding error handling for playback failures.
     */
    func playPlayer(for index: Int) {
        guard
            let player = activeAssignments[index],
            playerReadiness[player] == true
        else {
            return
        }
        player.play()
    }
    
    /**
     Performs comprehensive cleanup of all players and resources.
     
     ## Cleanup Process
     1. Pauses all active players
     2. Removes all KVO observers
     3. Clears player items to release video assets
     4. Removes all tracking dictionaries
     5. Clears the player pool
     6. Removes notification center observers
     
     Should be called when the pool is no longer needed to prevent memory leaks.
     */
    func cleanUp() {
        for (_, player) in activeAssignments {
            player.pause()
            player.currentItem?.removeObserver(self, forKeyPath: "status")
            player.replaceCurrentItem(with: nil)
        }
        activeAssignments.removeAll()
        playerReadiness.removeAll()
        playerPool.removeAll()
        cancellables.removeAll()
        
        NotificationCenter.default.removeObserver(self)
    }
    /**
     Deinitializer that ensures proper cleanup when the pool is deallocated.
     
     Automatically calls `cleanUp()` to prevent resource leaks.
     */
    deinit {
        cleanUp()
    }
}
