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
 
 ## Architecture
 The view model follows MVVM principles and uses dependency injection for testability.
 It acts as the central coordinator between services and the view layer.
 
 ## Usage
 ```swift
 let viewModel = VideoFeedViewModel()
 
 // Observe state changes
 viewModel.loadingState.sink { state in
     // Update UI based on state
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
    
    // MARK: - Private Properties
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    /// Publisher for tracking scroll state to optimize playback
    private let scrollingSubject = CurrentValueSubject<Bool, Never>(false)
    /// Keep track of when message input view is focused
    private var isFocused: Bool = false
    
    // MARK: - Computed Properties
    
    /// Current scrolling state of the video feed
    var isScrolling: Bool {
        scrollingSubject.value
    }
    /// Current array of video items
    var videos: [VideoItem] {
        videoItems.value
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
        Publishers.CombineLatest(scrollingSubject, currentVideoIndex)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] isScrolling, index in
                guard
                    let strongSelf = self,
                    !isScrolling else
                {
                    self?.updatePlayback(for: index)
                    return
                }
                strongSelf.updatePlayback(for: index)
            }
            .store(in: &cancellables)
        
        // Auto-play when video ready
        playerPool.playerReadinessPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                if self?.loadingState.value == .loaded && !(self?.isFocused ?? false) {
                    self?.playerPool.playPlayer(for: index)
                } else {
                    self?.playerPool.pauseAllPlayers()
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
    
    func updateCurrentVideoIndex(_ index: Int) {
        currentVideoIndex.send(index)
    }
    
    func setScrolling(_ isScrolling: Bool) {
        scrollingSubject.send(isScrolling)
    }
    
    func getPlayer(for index: Int) -> AVPlayer? {
        guard index < videos.count,
              let url = videos[index].url else { return nil }
        return playerPool.getPlayer(for: index, url: url)
    }
    
    func releasePlayer(for index: Int) {
        playerPool.releasePlayer(for: index)
    }
    
    func isPlayerReady(for index: Int) -> Bool {
        return playerPool.isPlayerReady(for: index)
    }
    
    func pauseAllPlayers() {
        playerPool.pauseAllPlayers()
    }
    
    func cleanUp() {
        playerPool.cleanUp()
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
        
    /**
     Updates video playback state for the specified index.
     
     - Parameter index: The index of the video to update playback for.
     
     This method:
     1. Skips if currently scrolling (performance optimization)
     2. Pauses all videos first
     3. Plays the current video if it's ready
     
     Called automatically when scrolling stops or video index changes.
     */
    private func updatePlayback(for index: Int) {
        guard !isScrolling else { return }
        
        // Pause all videos first
        playerPool.pauseAllPlayers()
        
        // Play current video if ready
        if playerPool.isPlayerReady(for: index) {
            playerPool.playPlayer(for: index)
        }
    }
    
    // MARK: - Life cycle
    func appDidEnterBackground() {
        playerPool.pauseAllPlayers()
    }

    func appWillEnterForeground() {
        let index = currentVideoIndex.value
        updatePlayback(for: index)
    }
    
    // MARK: - Message Input Focus
    
    /**
     Handles focus changes in the message input view.
     
     - Parameter isFocused: Whether the input view is currently focused.
     
     When focused:
     - Disables table view scrolling
     - Pauses video playback to avoid conflicts
     - Updates scroll state in view model
     
     When unfocused:
     - Re-enables table view scrolling
     - Resumes normal video feed behavior
     */
    func handleInputFocusChange(_ isFocused: Bool) {
        self.isFocused = isFocused
        if isFocused {
            // Pause current video when starting to type
            pauseAllPlayers()
            setScrolling(true) // Inform view model that scrolling is disabled
        } else {
            // Resume normal video behavior when done typing
            setScrolling(false)
            // Allow the view model to resume playback naturally
        }
    }
}
