//
//  MockVideoPlayerPool.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-10.
//
import Foundation
import AVFoundation
@testable import VideoFeed


class MockVideoPlayerPool: VideoPlayerPool {
    // Track method calls
    var getPlayerCalled = false
    var releasePlayerCalled = false
    var isPlayerReadyCalled = false
    var playPlayerCalled = false
    var pauseAllPlayersCalled = false
    var cleanUpCalled = false
    
    // Track parameters
    var lastPlayerIndex: Int?
    var lastPlayerURL: URL?
    var lastReleasedIndex: Int?
    var lastCheckedIndex: Int?
    var lastPlayedIndex: Int?
    
    // Mock return values
    var mockPlayer: AVPlayer?
    var mockPlayerReady = false
    
    override func getPlayer(for index: Int, url: URL) -> AVPlayer {
        getPlayerCalled = true
        lastPlayerIndex = index
        lastPlayerURL = url
        return mockPlayer ?? AVPlayer()
    }
    
    override func releasePlayer(for index: Int) {
        releasePlayerCalled = true
        lastReleasedIndex = index
    }
    
    override func isPlayerReady(for index: Int) -> Bool {
        isPlayerReadyCalled = true
        lastCheckedIndex = index
        return mockPlayerReady
    }
    
    override func playPlayer(for index: Int) {
        playPlayerCalled = true
        lastPlayedIndex = index
    }
    
    override func pauseAllPlayers() {
        pauseAllPlayersCalled = true
    }
    
    override func cleanUp() {
        cleanUpCalled = true
    }
}
