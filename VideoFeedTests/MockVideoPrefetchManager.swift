//
//  MockVideoPrefetchManager.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-10.
//

import Combine
@testable import VideoFeed

class MockVideoPrefetchManager: VideoPrefetchManager {
    // Track method calls
    var prefetchVideosCalled = false
    var lastPrefetchIndex: Int?
    
    // Subjects for testing
    let strategySubject = CurrentValueSubject<PrefetchStrategy, Never>(.conservative)
    let connectionSubject = CurrentValueSubject<ConnectionType, Never>(.cellular)
    
    override var prefetchStrategyPublisher: AnyPublisher<PrefetchStrategy, Never> {
        strategySubject.eraseToAnyPublisher()
    }
    
    override var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        connectionSubject.eraseToAnyPublisher()
    }
    
    override func prefetchVideos(around currentIndex: Int, videos: [VideoItem]) {
        prefetchVideosCalled = true
        lastPrefetchIndex = currentIndex
    }
}
