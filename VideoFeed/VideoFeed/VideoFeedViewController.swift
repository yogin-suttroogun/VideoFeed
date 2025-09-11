//
//  VideoFeedViewController.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import UIKit
import Combine

/**
 A view controller that displays a vertical scrolling feed of videos similar to TikTok or Instagram Reels.
 
 The `VideoFeedViewController` manages a full-screen table view where each cell contains a video player.
 It coordinates with `VideoFeedViewModel` to handle video loading, playback, and prefetching.
 
 ## Key Features
 - Full-screen vertical scrolling video feed
 - Automatic video playback and pausing based on visibility
 - Loading, error, and empty state handling
 - Background/foreground lifecycle management
 - Memory-efficient video player reuse
 
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
    
    /// Set of Combine cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI Components
    
    /// Main table view that displays video cells in a paginated, full-screen format
    private lazy var tableView: UITableView = {
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
     
     - Parameter coder: The coder to use for initialization.
     */
    required init?(coder: NSCoder) {
        self.viewModel = VideoFeedViewModel()
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.loadVideos()
        setupNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.pauseAllPlayers()
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
     
     Sets up the main table view, loading view, and error view with proper constraints.
     Also configures the error view's retry action.
     */
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(errorView)
        
        setupConstraints()
        setupErrorViewAction()
    }
    
    /**
     Establishes Auto Layout constraints for all UI components.

     Ensures that the table view, loading view, and error view all fill the entire screen.
     */
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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
     
     Sets up Combine subscriptions to:
     - Update UI based on loading state changes
     - Reload table view when video items change
     - Monitor prefetch strategy changes (for debugging/analytics)
     */
    private func bindViewModel() {
        // Bind loading state
        viewModel.loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
        
        // Bind video items
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
            .sink { connectionType in
                if connectionType == .unknown {
                    self.showErrorState(with: .noInternetConnection)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - UI State Management
    
    /**
     Updates the UI based on the current video feed state.
     
     - Parameter state: The current state of the video feed (loading, loaded, error, empty).
     
     Manages visibility of loading, error, and table view based on the provided state.
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
    
    private func showVideoFeed(_ isShown: Bool) {
        loadingView.isHidden = isShown
        tableView.isHidden = !isShown
        errorView.isHidden = true
    }
    
    private func showErrorState(with error: ErrorHandler) {
        loadingView.isHidden = true
        tableView.isHidden = true
        errorView.isHidden = false
        errorView.configure(with: error)
    }
    
    // MARK: - Notification observers for life cycle
        
    /**
     Configures notification observers for app lifecycle events.
     
     Monitors for:
     - App entering background: Pauses video playback
     - App entering foreground: Resumes video playback
     
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
    }
}
