//
//  VideoFeedViewModelTests.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-10.
//

import XCTest
import Combine
import AVFoundation
@testable import VideoFeed

final class VideoFeedViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    var viewModel: VideoFeedViewModel!
    var mockVideoService: MockVideoService!
    var mockPlayerPool: MockVideoPlayerPool!
    var mockPrefetchManager: MockVideoPrefetchManager!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        super.setUp()
        mockVideoService = MockVideoService()
        mockPlayerPool = MockVideoPlayerPool()
        mockPrefetchManager = MockVideoPrefetchManager()
        cancellables = Set<AnyCancellable>()
        
        viewModel = VideoFeedViewModel(
            videoService: mockVideoService,
            playerPool: mockPlayerPool,
            prefetchManager: mockPrefetchManager
        )
    }
    
    override func tearDownWithError() throws {
        cancellables.removeAll()
        viewModel.cleanUp()
        viewModel = nil
        mockVideoService = nil
        mockPlayerPool = nil
        mockPrefetchManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Given & When - initialization happens in setup
        
        // Then
        XCTAssertEqual(viewModel.loadingState.value, .loading)
        XCTAssertTrue(viewModel.videos.isEmpty)
        XCTAssertEqual(viewModel.currentVideoIndex.value, 0)
        XCTAssertEqual(viewModel.prefetchStrategy.value, .conservative)
        XCTAssertEqual(viewModel.connectionType.value, .cellular)
        XCTAssertFalse(viewModel.isScrolling)
        XCTAssertFalse(viewModel.isInputFocused)
    }
    
    // MARK: - Load Videos Tests
    
    func testLoadVideos_Success() {
        // Given
        let expectedVideos = createMockVideoItems(count: 3)
        mockVideoService.mockResult = .success(expectedVideos)
        
        let loadingStateExpectation = expectation(description: "Loading state changes")
        loadingStateExpectation.expectedFulfillmentCount = 1 // loading -> loaded
        
        let videoItemsExpectation = expectation(description: "Video items updated")
        
        // When
        viewModel.loadingState
            .dropFirst() // Skip initial loading state
            .sink { state in
                if state == .loaded {
                    loadingStateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.videoItems
            .dropFirst() // Skip initial empty array
            .sink { videos in
                if !videos.isEmpty {
                    videoItemsExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.loadVideos()
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(viewModel.videos.count, 3)
        XCTAssertEqual(viewModel.loadingState.value, .loaded)
        XCTAssertTrue(mockVideoService.loadManifestCalled)
    }
    
    func testLoadVideos_EmptyResponse() {
        // Given
        mockVideoService.mockResult = .success([])
        
        let errorStateExpectation = expectation(description: "Error state for empty response")
        
        // When
        viewModel.loadingState
            .dropFirst() // Skip initial loading state
            .sink { state in
                if case .error(let error) = state, error == .empty {
                    errorStateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.loadVideos()
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(viewModel.videos.isEmpty)
        if case .error(let error) = viewModel.loadingState.value {
            XCTAssertEqual(error, .empty)
        } else {
            XCTFail("Expected error state with .empty error")
        }
    }
    
    func testLoadVideos_NetworkError() {
        // Given
        let expectedError = ErrorHandler.noInternetConnection
        mockVideoService.mockResult = .failure(expectedError)
        
        let errorStateExpectation = expectation(description: "Error state for network failure")
        
        // When
        viewModel.loadingState
            .dropFirst() // Skip initial loading state
            .sink { state in
                if case .error(let error) = state, error == expectedError {
                    errorStateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.loadVideos()
        
        // Then
        waitForExpectations(timeout: 1.0)
        if case .error(let error) = viewModel.loadingState.value {
            XCTAssertEqual(error, expectedError)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Current Video Index Tests
    
    func testUpdateCurrentVideoIndex() {
        // Given
        let newIndex = 2
        let indexUpdateExpectation = expectation(description: "Video index updated")
        
        // When
        viewModel.currentVideoIndex
            .dropFirst() // Skip initial value
            .sink { index in
                if index == newIndex {
                    indexUpdateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.updateCurrentVideoIndex(newIndex)
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(viewModel.currentVideoIndex.value, newIndex)
    }
    
    func testCurrentVideoIndexTriggersPrefetching() {
        // Given
        let videos = createMockVideoItems(count: 5)
        viewModel.videoItems.send(videos)
        let newIndex = 2
        
        // When
        viewModel.updateCurrentVideoIndex(newIndex)
        
        // Give some time for debounced prefetching
        let prefetchExpectation = expectation(description: "Prefetching triggered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            prefetchExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Then
        XCTAssertTrue(mockPrefetchManager.prefetchVideosCalled)
        XCTAssertEqual(mockPrefetchManager.lastPrefetchIndex, newIndex)
    }
    
    // MARK: - Scrolling State Tests
    
    func testSetScrolling() {
        // Given
        let scrollingExpectation = expectation(description: "Scrolling state updated")
        
        // When
        viewModel.setScrolling(true)
        
        DispatchQueue.main.async {
            scrollingExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Then
        XCTAssertTrue(viewModel.isScrolling)
        
        // Test setting back to false
        viewModel.setScrolling(false)
        XCTAssertFalse(viewModel.isScrolling)
    }
    
    func testScrollingPreventsPlayback() {
        // Given
        viewModel.setScrolling(true)
        mockPlayerPool.mockPlayerReady = true
        
        // When - simulate scrolling stops and index changes
        viewModel.setScrolling(false)
        viewModel.updateCurrentVideoIndex(1)
        
        // Give time for debounced playback update
        let playbackExpectation = expectation(description: "Playback updated after scrolling stops")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Then
        XCTAssertTrue(mockPlayerPool.pauseAllPlayersCalled)
        XCTAssertTrue(mockPlayerPool.playPlayerCalled)
    }
    
    // MARK: - Input Focus State Tests
    
    func testSetInputFocused() {
        // Given
        let focusExpectation = expectation(description: "Input focus state updated")
        
        // When
        viewModel.inputFocusedSubject
            .dropFirst() // Skip initial value
            .sink { isFocused in
                if isFocused {
                    focusExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.setInputFocused(true)
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(viewModel.isInputFocused)
        XCTAssertTrue(mockPlayerPool.pauseAllPlayersCalled)
        
        // Test setting back to false
        viewModel.setInputFocused(false)
        XCTAssertFalse(viewModel.isInputFocused)
    }
    
    func testInputFocusedPreventsPlayback() {
        // Given
        viewModel.setInputFocused(true)
        mockPlayerPool.mockPlayerReady = true
        
        // When - simulate input unfocused and index changes
        viewModel.setInputFocused(false)
        viewModel.updateCurrentVideoIndex(1)
        
        // Give time for debounced playback update
        let playbackExpectation = expectation(description: "Playback updated after input unfocused")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Then
        XCTAssertTrue(mockPlayerPool.playPlayerCalled)
    }
    
    func testInputFocusedWhileScrollingPreventsPlayback() {
        // Given
        viewModel.setScrolling(true)
        viewModel.setInputFocused(true)
        mockPlayerPool.mockPlayerReady = true
        
        // When - simulate both scrolling and input focus stopping
        viewModel.setScrolling(false)
        viewModel.setInputFocused(false)
        viewModel.updateCurrentVideoIndex(1)
        
        // Give time for debounced playback update
        let playbackExpectation = expectation(description: "Playback updated after both states clear")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            playbackExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Then
        XCTAssertTrue(mockPlayerPool.playPlayerCalled)
    }
    
    // MARK: - Message Input Handling Tests
    
    func testHandleMessageSent() {
        // Given
        let testMessage = "Test message"
        let feedbackExpectation = expectation(description: "Temporary feedback published")
        
        // When
        viewModel.temporaryFeedbackPublisher
            .sink { message in
                if message == "Message sent!" {
                    feedbackExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.handleMessageSent(testMessage)
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    func testHandleHeartReaction() {
        // Given
        let heartExpectation = expectation(description: "Heart reaction feedback published")
        
        // When
        viewModel.temporaryFeedbackPublisher
            .sink { message in
                if message == "♥️" {
                    heartExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.handleHeartReaction()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    func testHandleShareReaction() {
        // Given
        let currentIndex = 3
        viewModel.updateCurrentVideoIndex(currentIndex)
        let shareExpectation = expectation(description: "Share options presentation published")
        
        // When
        viewModel.shareOptionsPresentationPublisher
            .sink { videoIndex in
                if videoIndex == currentIndex {
                    shareExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.handleShareReaction()
        
        // Then
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Keyboard Info Tests
    
    func testKeyboardInfoInitialState() {
        // Given & When - initialization happens in setup
        
        // Then
        let keyboardInfo = viewModel.keyboardInfo.value
        XCTAssertFalse(keyboardInfo.isVisible)
        XCTAssertEqual(keyboardInfo.height, 0)
        XCTAssertEqual(keyboardInfo.animationDuration, 0.25)
    }
    
    func testKeyboardInfoUpdates() {
        // Given
        let testKeyboardInfo = KeyboardInfo(
            isVisible: true,
            height: 300,
            animationDuration: 0.5,
            animationOptions: .curveEaseInOut
        )
        let keyboardExpectation = expectation(description: "Keyboard info updated")
        
        // When
        viewModel.keyboardInfo
            .dropFirst() // Skip initial value
            .sink { keyboardInfo in
                if keyboardInfo.isVisible && keyboardInfo.height == 300 {
                    keyboardExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.keyboardInfo.send(testKeyboardInfo)
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(viewModel.keyboardInfo.value.isVisible)
        XCTAssertEqual(viewModel.keyboardInfo.value.height, 300)
    }
    
    // MARK: - Player Management Tests
    
    func testGetPlayer_ValidIndex() {
        // Given
        let videos = createMockVideoItems(count: 3)
        viewModel.videoItems.send(videos)
        let mockPlayer = AVPlayer()
        mockPlayerPool.mockPlayer = mockPlayer
        
        // When
        let player = viewModel.getPlayer(for: 1)
        
        // Then
        XCTAssertEqual(player, mockPlayer)
        XCTAssertTrue(mockPlayerPool.getPlayerCalled)
        XCTAssertEqual(mockPlayerPool.lastPlayerIndex, 1)
        XCTAssertEqual(mockPlayerPool.lastPlayerURL, videos[1].url)
    }
    
    func testGetPlayer_InvalidIndex() {
        // Given
        let videos = createMockVideoItems(count: 2)
        viewModel.videoItems.send(videos)
        
        // When
        let player = viewModel.getPlayer(for: 5)
        
        // Then
        XCTAssertNil(player)
        XCTAssertFalse(mockPlayerPool.getPlayerCalled)
    }
    
    func testGetPlayer_InvalidURL() {
        // Given
        let videoWithNilURL = VideoItem(urlString: nil, index: 0)
        viewModel.videoItems.send([videoWithNilURL])
        
        // When
        let player = viewModel.getPlayer(for: 0)
        
        // Then
        XCTAssertNil(player)
        XCTAssertFalse(mockPlayerPool.getPlayerCalled)
    }
    
    func testReleasePlayer() {
        // Given
        let index = 2
        
        // When
        viewModel.releasePlayer(for: index)
        
        // Then
        XCTAssertTrue(mockPlayerPool.releasePlayerCalled)
        XCTAssertEqual(mockPlayerPool.lastReleasedIndex, index)
    }
    
    func testIsPlayerReady() {
        // Given
        let index = 1
        mockPlayerPool.mockPlayerReady = true
        
        // When
        let isReady = viewModel.isPlayerReady(for: index)
        
        // Then
        XCTAssertTrue(isReady)
        XCTAssertTrue(mockPlayerPool.isPlayerReadyCalled)
        XCTAssertEqual(mockPlayerPool.lastCheckedIndex, index)
    }
    
    func testPauseAllPlayers() {
        // When
        viewModel.pauseAllPlayers()
        
        // Then
        XCTAssertTrue(mockPlayerPool.pauseAllPlayersCalled)
    }
    
    // MARK: - Prefetch Strategy Tests
    
    func testPrefetchStrategyBinding() {
        // Given
        let newStrategy = PrefetchStrategy.aggressive
        let strategyExpectation = expectation(description: "Strategy updated")
        
        // When
        viewModel.prefetchStrategy
            .sink { strategy in
                if strategy == newStrategy {
                    strategyExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockPrefetchManager.strategySubject.send(newStrategy)
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(viewModel.prefetchStrategy.value, newStrategy)
    }
    
    func testConnectionTypeBinding() {
        // Given
        let newConnectionType = ConnectionType.wifi
        let connectionExpectation = expectation(description: "Connection type updated")
        
        // When
        viewModel.connectionType
            .sink { connectionType in
                if connectionType == newConnectionType {
                    connectionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockPrefetchManager.connectionSubject.send(newConnectionType)
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(viewModel.connectionType.value, newConnectionType)
    }
    
    // MARK: - Player Pool Integration Tests
    
    func testPlayerReadinessTriggersPlayback() {
        // Given
        let readyIndex = 1
        viewModel.loadingState.send(.loaded) // Ensure loaded state
        let playbackExpectation = expectation(description: "Playback triggered on ready")
        
        // When - simulate player ready signal
        mockPlayerPool.playerReadinessPublisher.send(readyIndex)
        
        // Give some time for the binding to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            playbackExpectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(mockPlayerPool.playPlayerCalled)
        XCTAssertEqual(mockPlayerPool.lastPlayedIndex, readyIndex)
    }
    
    func testPlayerReadinessDoesNotTriggerPlaybackWhenInputFocused() {
        // Given
        let readyIndex = 1
        viewModel.loadingState.send(.loaded)
        viewModel.setInputFocused(true) // Focus input to prevent playback
        
        // Reset mock state
        mockPlayerPool.playPlayerCalled = false
        mockPlayerPool.pauseAllPlayersCalled = false
        
        let pauseExpectation = expectation(description: "Playback paused when input focused")
        
        // When - simulate player ready signal
        mockPlayerPool.playerReadinessPublisher.send(readyIndex)
        
        // Give some time for the binding to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pauseExpectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertFalse(mockPlayerPool.playPlayerCalled)
        XCTAssertTrue(mockPlayerPool.pauseAllPlayersCalled)
    }
    
    // MARK: - App Lifecycle Tests
    
    func testAppDidEnterBackground() {
        // When
        viewModel.appDidEnterBackground()
        
        // Then
        XCTAssertTrue(mockPlayerPool.pauseAllPlayersCalled)
        XCTAssertFalse(viewModel.isInputFocused)
    }
    
    func testAppWillEnterForeground() {
        // Given
        let currentIndex = 2
        viewModel.updateCurrentVideoIndex(currentIndex)
        mockPlayerPool.mockPlayerReady = true
        
        // Reset mock state
        mockPlayerPool.pauseAllPlayersCalled = false
        mockPlayerPool.playPlayerCalled = false
        
        // When
        viewModel.appWillEnterForeground()
        
        // Give time for playback update
        let foregroundExpectation = expectation(description: "Foreground playback updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            foregroundExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        // Then
        XCTAssertTrue(mockPlayerPool.pauseAllPlayersCalled)
        XCTAssertTrue(mockPlayerPool.playPlayerCalled)
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanUp() {
        // When
        viewModel.cleanUp()
        
        // Then
        XCTAssertTrue(mockPlayerPool.cleanUpCalled)
    }
}

// MARK: - Helper Methods

extension VideoFeedViewModelTests {
    
    private func createMockVideoItems(count: Int) -> [VideoItem] {
        return (0..<count).map { index in
            VideoItem(urlString: "https://example.com/video\(index).mp4", index: index)
        }
    }
}
