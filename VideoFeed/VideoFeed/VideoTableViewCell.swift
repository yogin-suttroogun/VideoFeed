//
//  VideoTableViewCell.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-05.
//

import UIKit
import AVFoundation

/**
 A custom table view cell that displays a full-screen video player.
 
 `VideoTableViewCell` is designed for TikTok-style video feeds where each cell
 occupies the entire screen height and displays a single video with auto-fit scaling.
 
 ## Key Features
 - Full-screen video display with aspect fill scaling
 - Integrated loading indicator for video preparation
 - Automatic player status monitoring via KVO
 - Memory-efficient player reuse through proper cleanup
 - Black background for optimal video presentation
 
 ## Usage
 ```swift
 let cell = tableView.dequeueReusableCell(withIdentifier: VideoTableViewCell.identifier) as! VideoTableViewCell
 cell.configure(with: player, video: videoItem)
 ```
 
 ## Key Value Observing (KVO) Safety
 The cell properly manages KVO observers to prevent crashes and memory leaks
 when cells are reused or deallocated.
 */
final class VideoTableViewCell: UITableViewCell {
    /// Reuse identifier for table view cell registration
    static let identifier = "VideoTableViewCell"
    /// The AVPlayer instance currently assigned to this cell
    private var player: AVPlayer?
    /// Layer that renders the video content with customizable video gravity
    private lazy var playerLayer: AVPlayerLayer = {
        let playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspectFill
        return playerLayer
    }()
    /// Loading indicator shown while video is preparing for playback
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()
    /// Reference to the current video item for context
    private var video: VideoItem?
    
    /**
     Initializes the cell with the specified style and reuse identifier.
     
     - Parameters:
     - style: The cell style (ignored for this custom implementation).
     - reuseIdentifier: The reuse identifier for cell dequeue operations.
     
     Sets up the UI layout and prepares the cell for video display.
     */
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    /**
     Required initializer for storyboard/XIB instantiation.
     
     - Parameter coder: The coder used for initialization.
     
     - Note: This implementation will trigger a runtime error as this cell
     is designed for programmatic use only.
     */
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    // MARK: - UI Setup
    
    /**
     Configures the cell's user interface components.
     
     Sets up:
     - Black background for optimal video contrast
     - No selection style to maintain immersive experience
     - Player layer as the primary content layer
     - Loading indicator with proper constraints
     */
    private func setupUI() {
        backgroundColor = .black
        selectionStyle = .none
        
        contentView.layer.addSublayer(playerLayer)
        contentView.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    // MARK: - Configuration
    
    /**
     Configures the cell with a video player and video item.
     
     - Parameters:
     - player: The AVPlayer instance to display in this cell.
     - video: The VideoItem containing metadata about the video.
     
     ## Process
     1. Safely removes any existing KVO observers
     2. Assigns the new player and updates the player layer
     3. Starts the loading indicator
     4. Sets up KVO monitoring for the new player's status
     5. Performs initial status check
     
     ## KVO Safety
     This method ensures proper cleanup of previous observers before adding new ones,
     preventing potential crashes from duplicate or stale observers.
     */
    func configure(with player: AVPlayer, video: VideoItem) {
        // Clean up previous player observation
        if let previousPlayer = self.player {
            previousPlayer.removeObserver(self, forKeyPath: "currentItem.status")
        }
        
        self.player = player
        self.video = video
        
        // Update player layer
        playerLayer.player = player
        
        // Start loading indicator
        loadingIndicator.startAnimating()
        
        // Monitor player status
        player.addObserver(self, forKeyPath: "currentItem.status", options: [.new], context: nil)
        checkForCurrentLoaderStatus()
    }
    
    /**
     Key-Value Observing callback for monitoring player status changes.
     
     - Parameters:
     - keyPath: The key path being observed ("currentItem.status").
     - object: The object being observed (AVPlayer).
     - change: Dictionary containing change information.
     - context: Context pointer (unused in this implementation).
     
     Responds to player status changes by updating the loading indicator visibility.
     */
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "currentItem.status" {
            checkForCurrentLoaderStatus()
        }
    }
    
    /**
     Checks the current player status and updates the loading indicator accordingly.
     
     ## Status Handling
     - `.readyToPlay`: Hides the loading indicator
     - Other states: Shows the loading indicator
     
     Dispatches UI updates to the main queue to ensure thread safety.
     */
    private func checkForCurrentLoaderStatus() {
        DispatchQueue.main.async {
            if self.player?.currentItem?.status == .readyToPlay {
                self.loadingIndicator.stopAnimating()
            } else {
                self.loadingIndicator.startAnimating()
            }
        }
    }
    
    // MARK: - Layout
    
    /**
     Updates the player layer frame to match the content view bounds.
     
     Called automatically when the cell's layout changes, ensuring the video
     always fills the entire cell area regardless of device rotation or size changes.
     */
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = contentView.bounds
    }
    
    // MARK: - Cell Lifecycle
    
    /**
     Prepares the cell for reuse by cleaning up current state.
     
     ## Cleanup Process
     1. Safely removes KVO observers from the current player
     2. Resets player and video references
     3. Clears the player layer
     4. Stops and hides the loading indicator
     
     This prevents state bleeding between different video items when cells are reused.
     */
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Clean up observer
        if let player = self.player {
            player.removeObserver(self, forKeyPath: "currentItem.status")
        }
        
        // Reset state
        player = nil
        video = nil
        playerLayer.player = nil
        loadingIndicator.stopAnimating()
    }
    
    deinit {
        // Safety cleanup
        if let player = self.player {
            player.removeObserver(self, forKeyPath: "currentItem.status")
        }
    }
}
