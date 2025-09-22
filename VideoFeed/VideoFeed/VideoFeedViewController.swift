//
//  VideoFeedViewController.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import UIKit
import Combine

/**
 A view controller that displays a vertical scrolling feed of videos with message input functionality.
 
 The `VideoFeedViewController` manages a full-screen table view where each cell contains a video player,
 enhanced with a sophisticated message input system that allows users to send messages and reactions
 while maintaining smooth video playback performance.
 
 ## Key Features
 - Full-screen vertical scrolling video feed with TikTok-style presentation
 - Automatic video playback and pausing based on visibility and focus states
 - Integrated message input with reaction buttons (heart and share)
 - Keyboard-aware layout adjustments that preserve video visibility
 - Scroll disabling during text input to prevent accidental navigation
 - Comprehensive state management (loading, error, empty, loaded)
 - Background/foreground lifecycle management with playback coordination
 - Memory-efficient video player reuse through table view cell recycling
 
 ## Message Input Integration
 - Text input bar with expandable multi-line support
 - Heart and share reaction buttons in unfocused state
 - Focus-aware UI that disables video scrolling during typing
 - Keyboard-aware layout that keeps input visible above keyboard
 - Send button that appears dynamically when typing
 - Smooth animations between input states with spring physics
 - Tap-to-dismiss functionality for intuitive keyboard management
 ## Usage
 ```swift
 let viewModel = VideoFeedViewModel()
 let controller = VideoFeedViewController(viewModel: viewModel)
 navigationController.pushViewController(controller, animated: true)
 ```
 */
final class VideoFeedViewController: UIViewController {
    
    // MARK: - Dependencies
    
    /// The view model that manages business logic and data for the video feed
    internal let viewModel: VideoFeedViewModel
    
    // MARK: - Private Properties
    
    /// Set of Combine cancellables for managing reactive subscriptions
    private var cancellables = Set<AnyCancellable>()
    /// Bottom constraint for the message input view (adjusted for keyboard visibility)
    internal var messageInputBottomConstraint: NSLayoutConstraint!
    /// Original table view bottom constraint (maintains relationship with input view)
    private var tableViewBottomConstraint: NSLayoutConstraint!
    
    // MARK: - UI Components
    
    /// Main table view that displays video cells in a paginated, full-screen format
    internal lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isPagingEnabled = true
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .none
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(VideoTableViewCell.self, forCellReuseIdentifier: VideoTableViewCell.identifier)
        return tableView
    }()
    
    /// Loading view displayed while fetching video manifest
    private lazy var loadingView: LoadingView = {
        let loadingView = LoadingView()
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        return loadingView
    }()
    
    /// Error view displayed when video loading fails, with retry functionality
    private lazy var errorView: ErrorView = {
        let errorView = ErrorView()
        errorView.isHidden = true
        errorView.translatesAutoresizingMaskIntoConstraints = false
        return errorView
    }()
    
    /// Message input view with reaction buttons
    internal lazy var messageInputView: MessageInputView = {
        let inputView = MessageInputView()
        inputView.translatesAutoresizingMaskIntoConstraints = false
        return inputView
    }()
    
    // MARK: - Initialization
    
    /**
     Initializes the video feed view controller with a specified view model.
     
     - Parameter viewModel: The view model instance to manage data and business logic.
     Defaults to a new `VideoFeedViewModel` instance.
     
     ## Example
     ```swift
     let customViewModel = VideoFeedViewModel()
     let controller = VideoFeedViewController(viewModel: customViewModel)
     ```
     */
    init(viewModel: VideoFeedViewModel = VideoFeedViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    /**
     Required initializer for storyboard instantiation.
     
     Creates a default `VideoFeedViewModel` instance when initialized from storyboard.
     Note that dependency injection is not available through this initializer.
     
     - Parameter coder: The coder to use for initialization.
     */
    required init?(coder: NSCoder) {
        self.viewModel = VideoFeedViewModel()
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    /**
     Configures the view controller after the view loads.
     
     ## Setup Process
     1. Configures UI layout and constraints
     2. Establishes reactive bindings with view model
     3. Sets up message input event handling
     4. Initiates video data loading
     5. Registers for system notifications
     6. Configures keyboard dismissal behavior
     
     This method coordinates all necessary setup for a fully functional
     video feed with message input capabilities.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        bindMessageInput()
        viewModel.loadVideos()
        setupNotifications()
        setupKeyboardDismissOnTap()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.pauseAllPlayers()
        viewModel.setInputFocused(false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            viewModel.cleanUp()
        }
    }
    
    // MARK: - Setup
    
    /**
     Configures the user interface layout and adds subviews.
     
     Sets up the main table view, loading view, error view, and message input view
     with proper constraints and keyboard-aware positioning.
     */
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(errorView)
        view.addSubview(messageInputView)
        
        setupConstraints()
        setupErrorViewAction()
    }
    
    /**
     Establishes Auto Layout constraints for all UI components.
     
     Ensures proper layout with keyboard-aware positioning for the message input view
     and maintains full-screen video display while accommodating the input interface.
     */
    private func setupConstraints() {
        // Table view constraints
        tableViewBottomConstraint = tableView.bottomAnchor.constraint(equalTo: messageInputView.topAnchor, constant: -8)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableViewBottomConstraint
        ])
        
        // Loading view constraints
        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Error view constraints
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Message input view constraints
        messageInputBottomConstraint = messageInputView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            messageInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            messageInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            messageInputBottomConstraint
        ])
    }
    
    /**
     Configures the error view's retry button action.
     
     When the retry button is tapped, it triggers the view model to reload videos.
     */
    private func setupErrorViewAction() {
        errorView.onRetry = { [weak self] in
            self?.viewModel.loadVideos()
        }
    }
    
    // MARK: - Binding
    
    /**
     Establishes reactive bindings between the view model and UI components.
     
     ## Publisher Subscriptions
     Sets up Combine subscriptions to observe:
     - Loading state changes for UI mode switching
     - Video items updates for table view reloading
     - Prefetch strategy changes for debugging/analytics
     - Network connectivity changes for error handling
     - Input focus state for keyboard coordination
     - Keyboard information for layout adjustments
     - User feedback messages for temporary display
     - Share options presentation for sharing workflows
     */
    private func bindViewModel() {
        // Bind loading state
        viewModel.loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
        
        // Bind video items for table view
        viewModel.videoItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        // Bind prefetch strategy changes
        viewModel.prefetchStrategy
            .receive(on: DispatchQueue.main)
            .sink { strategy in
                print("Prefetch strategy changed to: \(strategy)")
                // Could show network status indicator here
            }
            .store(in: &cancellables)
        
        // Bind network changes
        viewModel.connectionType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectionType in
                if connectionType == .unknown {
                    self?.showErrorState(with: .noInternetConnection)
                }
            }
            .store(in: &cancellables)
        
        // Bind message input view
        viewModel.inputFocusedSubject
            .sink { [weak self] isFocused in
                self?.messageInputView.setFocused(isFocused, animated: true)
            }
            .store(in: &cancellables)
        
        // Bind keyboard info
        viewModel.keyboardInfo
            .sink { [weak self] keyboardInfo in
                self?.handleKeyboardChange(keyboardInfo)
            }
            .store(in: &cancellables)
        
        // Bind temporary feedback
        viewModel.temporaryFeedbackPublisher
            .sink { [weak self] message in
                self?.showTemporaryFeedback(message)
            }
            .store(in: &cancellables)
        
        // Bind share options presentation
        viewModel.shareOptionsPresentationPublisher
            .sink { [weak self] videoIndex in
                self?.presentShareOptions(for: videoIndex)
            }
            .store(in: &cancellables)
    }
    
    /**
     Establishes reactive bindings for message input functionality.

     Connects message input view publishers to appropriate view model methods:
     - Focus state changes disable/enable table view scrolling
     - Message sending triggers view model message handling
     - Heart reactions trigger view model heart handling
     - Share reactions trigger view model share handling
     */
    private func bindMessageInput() {
        // Handle focus changes
        messageInputView.focusStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFocused in
                self?.tableView.isScrollEnabled = !isFocused
                self?.viewModel.setInputFocused(isFocused)
            }
            .store(in: &cancellables)
        
        // Handle message sending
        messageInputView.messageSentPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.viewModel.handleMessageSent(message)
            }
            .store(in: &cancellables)
        
        // Handle heart reaction
        messageInputView.heartTappedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.viewModel.handleHeartReaction()
            }
            .store(in: &cancellables)
        
        // Handle share reaction
        messageInputView.shareTappedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.viewModel.handleShareReaction()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - UI State Management
    
    /**
     Updates the UI based on the current video feed state.
     
     - Parameter state: The current state of the video feed (loading, loaded, error).
     
     Manages visibility and configuration of all major UI components based on
     the current application state:
     - Loading: Shows loading indicator, hides other components
     - Loaded: Shows video feed and message input, hides loading/error views
     - Error: Shows error view with retry functionality, hides other components
     
     */
    private func updateUI(for state: VideoFeedState) {
        switch state {
        case .loading:
            showVideoFeed(false)
        case .loaded:
            showVideoFeed(true)
        case .error(let error):
            showErrorState(with: error)
        }
    }
    
    /**
     Controls the visibility of video feed components.
     
     - Parameter isShown: Whether the video feed should be visible.
     
     ## Component Coordination
     Manages the visibility state of related UI components to ensure
     only appropriate views are shown for the current application state.
     */
    private func showVideoFeed(_ isShown: Bool) {
        loadingView.isHidden = isShown
        tableView.isHidden = !isShown
        messageInputView.isHidden = !isShown
        errorView.isHidden = true
    }
    
    /**
     Displays error state UI with appropriate error information.
     
     - Parameter error: The specific error to display to the user.
     
     ## Error Display
     Configures the error view with user-friendly messages and appropriate
     iconography based on the error type, while hiding all other UI components.
     */
    private func showErrorState(with error: ErrorHandler) {
        loadingView.isHidden = true
        tableView.isHidden = true
        messageInputView.isHidden = true
        errorView.isHidden = false
        errorView.configure(with: error)
    }
    
    // MARK: - Notification Setup
    
    /**
     Configures notification observers for app lifecycle events and keyboard changes.
     
     ## Monitored Events
     - App entering background: Pauses video playback and dismisses keyboard
     - App entering foreground: Resumes appropriate video playback
     - Keyboard show/hide: Adjusts layout to keep message input visible
     
     Uses Combine publishers for reactive notification handling.
     */
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.viewModel.appDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.viewModel.appWillEnterForeground()
            }
            .store(in: &cancellables)
        
        // Keyboard notifications
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo }
            .sink { [weak self] userInfo in
                self?.handleKeyboardWillShow(userInfo: userInfo)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { $0.userInfo }
            .sink { [weak self] userInfo in
                self?.handleKeyboardWillHide(userInfo: userInfo)
            }
            .store(in: &cancellables)
    }
}
