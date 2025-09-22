//
//  VideoFeedViewModel.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-07.
//

import Foundation
import Combine
import AVFoundation

/**
 Represents the various states of the video feed.
 
 Used to communicate loading status between the view model and view controller,
 enabling appropriate UI updates for each state.
 */
enum VideoFeedState: Equatable {
    /// Currently loading video manifest or preparing data
    case loading
    /// Successfully loaded with videos available for display
    case loaded
    /// Failed to load due to network or parsing errors
    case error(ErrorHandler)
}

/**
 The view model responsible for managing video feed business logic and data flow.
 
 `VideoFeedViewModel` coordinates between multiple services to provide a seamless video feed experience:
 - Manages video data loading and state
 - Coordinates video player assignment and lifecycle
 - Handles intelligent video prefetching
 - Manages current video index and playback state
 - Provides reactive data binding through Combine publishers
 - Handles message input functionality and user interactions
 - Manages keyboard state and focus handling
 
 ## Architecture
 The view model follows MVVM principles and uses dependency injection for testability.
 It acts as the central coordinator between services and the view layer.
 
 ## Message Input Integration
 Provides comprehensive message input handling including:
 - Focus state management that disables video scrolling during typing
 - Message sending with user feedback
 - Reaction handling (heart and share buttons)
 - Keyboard-aware layout coordination
 
 ## Usage
 ```swift
 let viewModel = VideoFeedViewModel()
 
 // Observe state changes
 viewModel.loadingState.sink { state in
     // Update UI based on state
 }
 
 // Handle message input
 viewModel.inputFocusedSubject.sink { isFocused in
     // Update UI for focus state
 }
 
 // Load video data
 viewModel.loadVideos()
 ```
 */
final class VideoFeedViewModel {
    // MARK: - Dependencies
    
    /// Service responsible for loading video manifest from network
    private let videoService: VideoServiceProtocol
    /// Pool manager for efficient video player reuse
    private let playerPool: VideoPlayerPool
    /// Manager for intelligent video prefetching based on network conditions
    private let prefetchManager: VideoPrefetchManager
    
    // MARK: - Output Subjects
    
    /// Publisher for video data changes
    let videoItems = CurrentValueSubject<[VideoItem], Never>([])
    /// Publisher for loading state changes
    let loadingState = CurrentValueSubject<VideoFeedState, Never>(.loading)
    /// Publisher for current video index changes
    let currentVideoIndex = CurrentValueSubject<Int, Never>(0)
    /// Publisher for prefetch strategy updates
    let prefetchStrategy = CurrentValueSubject<PrefetchStrategy, Never>(.conservative)
    /// Publisher for connection type updates
    let connectionType = CurrentValueSubject<ConnectionType, Never>(.cellular)
    /// Publisher for keyboard information and state changes
    let keyboardInfo = CurrentValueSubject<KeyboardInfo, Never>(.hidden)
    
    // MARK: - Private Properties
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    /// Publisher for tracking scroll state to optimize playback
    private let scrollingSubject = CurrentValueSubject<Bool, Never>(false)
    /// Publisher for tracking when message input view is focused
    let inputFocusedSubject = CurrentValueSubject<Bool, Never>(false)
    
    // MARK: - Message Input Publishers
    
    /// Publisher that emits temporary user feedback messages
    let temporaryFeedbackPublisher = PassthroughSubject<String, Never>()
    /// Publisher that emits video indices for share options presentation
    let shareOptionsPresentationPublisher = PassthroughSubject<Int, Never>()

    
    // MARK: - Computed Properties
    
    /// Current scrolling state of the video feed
    var isScrolling: Bool {
        scrollingSubject.value
    }
    /// Current array of video items
    var videos: [VideoItem] {
        videoItems.value
    }
    /// Current focus state of the message input
    var isInputFocused: Bool {
        inputFocusedSubject.value
    }
    
    // MARK: - Initialization
    
    /**
     Initializes the view model with its required dependencies.
     
     - Parameters:
     - videoService: Service for loading video manifest. Defaults to `VideoService()`.
     - playerPool: Pool for managing video players. Defaults to `VideoPlayerPool()`.
     - prefetchManager: Manager for video prefetching. Defaults to `VideoPrefetchManager()`.
     
     ## Dependency Injection
     This initializer enables dependency injection for better testability and flexibility:
     ```swift
     let mockService = MockVideoService()
     let viewModel = VideoFeedViewModel(videoService: mockService)
     ```
     */
    init(
        videoService: VideoServiceProtocol = VideoService(),
        playerPool: VideoPlayerPool = VideoPlayerPool(),
        prefetchManager: VideoPrefetchManager = VideoPrefetchManager()
    ) {
        self.videoService = videoService
        self.playerPool = playerPool
        self.prefetchManager = prefetchManager
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    /**
     Establishes reactive bindings between dependencies and internal state.
     
     Sets up the following reactive chains:
     - Prefetch strategy updates from network conditions
     - Automatic prefetching when video index changes
     - Playback control when scrolling stops
     - Auto-play when video players are ready
     - Message input focus state coordination
     */
    private func setupBindings() {
        // Monitor prefetch strategy changes
        prefetchManager.prefetchStrategyPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] strategy in
                self?.prefetchStrategy.send(strategy)
            }
            .store(in: &cancellables)
        
        prefetchManager.connectionTypePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connection in
                self?.connectionType.send(connection)
            }.store(in: &cancellables)
        
        // Auto-prefetch when video index changes
        Publishers.CombineLatest(currentVideoIndex, videoItems)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] index, videos in
                guard let strongSelf = self, !videos.isEmpty else { return }
                strongSelf.prefetchManager.prefetchVideos(around: index, videos: videos)
            }
            .store(in: &cancellables)
        
        // Auto-update playback when scrolling stops
        Publishers.CombineLatest3(scrollingSubject, currentVideoIndex, inputFocusedSubject)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] isScrolling, index, isInputFocused in
                self?.updatePlayback(for: index, isScrolling: isScrolling, isInputFocused: isInputFocused)
            }
            .store(in: &cancellables)
        
        // Auto-play when video ready
        playerPool.playerReadinessPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                guard let strongSelf = self else { return }
                let shouldPlay = strongSelf.loadingState.value == .loaded &&
                               !strongSelf.isInputFocused &&
                               !strongSelf.isScrolling
                
                if shouldPlay {
                    strongSelf.playerPool.playPlayer(for: index)
                } else {
                    strongSelf.playerPool.pauseAllPlayers()
                }
                
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    /**
     Initiates loading of the video manifest from the network.
     
     Updates the loading state and fetches video data through the video service.
     Handles success and failure cases, updating the appropriate state publishers.
     
     ## State Flow
     1. Sets state to `.loading`
     2. Calls video service to fetch manifest
     3. On success: Updates video items and sets state to `.loaded` or `.empty`
     4. On failure: Sets state to `.error`
     */
    func loadVideos() {
        loadingState.send(.loading)
        
        videoService.loadManifest { [weak self] result in
            DispatchQueue.main.async {
                guard let strongSelf = self else { return }
                
                switch result {
                case .success(let videos):
                    if videos.isEmpty {
                        strongSelf.loadingState.send(.error(.empty))
                    } else {
                        strongSelf.videoItems.send(videos)
                        strongSelf.loadingState.send(.loaded)
                    }
                case .failure(let error):
                    strongSelf.loadingState.send(.error(error))
                }
            }
        }
    }
    
    /**
     Updates the current video index and triggers related operations.
     
     - Parameter index: The new video index to set as current.
     
     This method updates the current video index publisher, which triggers:
     - Video prefetching around the new index
     - Playback state updates (if not scrolling or input focused)
     - Player assignment for the new video
     */
    func updateCurrentVideoIndex(_ index: Int) {
        currentVideoIndex.send(index)
    }
    
    /**
     Updates the scrolling state of the video feed.
     
     - Parameter isScrolling: Whether the feed is currently being scrolled.
     
     ## Behavior
     When scrolling is active, video playback is paused to improve performance
     and prevent audio conflicts during rapid view changes.
     */
    func setScrolling(_ isScrolling: Bool) {
        scrollingSubject.send(isScrolling)
    }
    
    /**
     Updates the focus state of the message input.
     
     - Parameter isFocused: Whether the message input is currently focused.
     
     ## Behavior
     When input is focused:
     - All video playback is paused
     - Scroll view is typically disabled in the view controller
     - Keyboard layout adjustments are coordinated
     */
    func setInputFocused(_ isFocused: Bool) {
        inputFocusedSubject.send(isFocused)
        
        if isFocused {
            pauseAllPlayers()
        }
    }
    
    // MARK: - Player Management
    
    /**
     Retrieves or creates a video player for the specified index.
     
     - Parameter index: The video index to get a player for.
     - Returns: An `AVPlayer` instance if valid, `nil` if index is invalid or URL is missing.
     
     ## Validation
     - Checks index bounds against video array
     - Verifies video URL is valid
     - Delegates to player pool for actual player management
     */
    func getPlayer(for index: Int) -> AVPlayer? {
        guard index < videos.count,
              let url = videos[index].url else { return nil }
        return playerPool.getPlayer(for: index, url: url)
    }
    
    /**
     Releases the video player for the specified index.
     
     - Parameter index: The video index whose player should be released.
     
     Delegates to the player pool for proper cleanup and potential reuse.
     */
    func releasePlayer(for index: Int) {
        playerPool.releasePlayer(for: index)
    }
    
    /**
     Checks if the video player for the specified index is ready for playback.
     
     - Parameter index: The video index to check.
     - Returns: `true` if the player is ready, `false` otherwise.
     */
    func isPlayerReady(for index: Int) -> Bool {
        return playerPool.isPlayerReady(for: index)
    }
    
    /**
     Pauses all currently active video players.
     
     Used during scrolling, input focus, app backgrounding, or when switching videos.
     */
    func pauseAllPlayers() {
        playerPool.pauseAllPlayers()
    }
    
    /**
     Performs comprehensive cleanup of all resources and subscriptions.
     
     ## Cleanup Operations
     - Cancels all Combine subscriptions
     - Cleans up video player pool
     - Releases all retained resources
     
     Should be called when the view model is no longer needed to prevent memory leaks.
     */
    func cleanUp() {
        playerPool.cleanUp()
        cancellables.removeAll()
    }
    
    // MARK: - Message Input Handling
    
    /**
     Handles message sending from the input view.
     
     - Parameter message: The message text that was sent.
     
     ## Current Implementation
     Provides user feedback through the temporary feedback publisher.
     Can be extended to handle actual message sending logic.
     */
    func handleMessageSent(_ message: String) {
        temporaryFeedbackPublisher.send("Message sent!")
    }
    
    /**
     Handles heart reaction button tap.
     
     ## Current Implementation
     Provides visual feedback with a heart emoji.
     Can be extended to handle like/heart functionality for the current video.
     */
    func handleHeartReaction() {
        temporaryFeedbackPublisher.send("❤️")
    }
    
    /**
     Handles share reaction button tap.
     
     ## Current Implementation
     Triggers share options presentation for the current video.
     The view controller handles the actual sharing UI presentation.
     */
    func handleShareReaction() {
        shareOptionsPresentationPublisher.send(currentVideoIndex.value)
    }
    
    // MARK: - Private Methods
        
    /**
     Updates video playback state for the specified index.
     
     - Parameters:
     - index: The index of the video to update playback for.
     - isScrolling: Whether the feed is currently scrolling.
     - isInputFocused: Whether the message input is focused.
     
     ## Playback Logic
     Videos only play when:
     - Not currently scrolling (performance optimization)
     - Message input is not focused (prevents audio conflicts)
     - Player is ready for the specified index
     
     This method is called automatically through reactive bindings when
     scrolling stops, input focus changes, or video index updates.
     */
    private func updatePlayback(for index: Int, isScrolling: Bool, isInputFocused: Bool) {
        guard !isScrolling && !isInputFocused else {
            pauseAllPlayers()
            return
        }
        
        // Pause all videos first
        playerPool.pauseAllPlayers()
        
        // Play current video if ready
        if playerPool.isPlayerReady(for: index) {
            playerPool.playPlayer(for: index)
        }
    }
    
    // MARK: - App Lifecycle
    
    /**
     Handles app entering background state.
     
     ## Background Behavior
     - Pauses all video playback to conserve battery
     - Dismisses message input focus to hide keyboard
     - Prepares for app suspension
     */
    func appDidEnterBackground() {
        playerPool.pauseAllPlayers()
        setInputFocused(false)
    }

    /**
     Handles app returning to foreground state.
     
     ## Foreground Behavior
     - Resumes video playback for current index
     - Respects current scrolling and input focus states
     - Restores normal playback behavior
     */
    func appWillEnterForeground() {
        let index = currentVideoIndex.value
        updatePlayback(for: index, isScrolling: isScrolling, isInputFocused: isInputFocused)
    }
}
