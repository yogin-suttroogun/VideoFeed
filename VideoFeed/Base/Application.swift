//
//  Application.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-09.
//

import UIKit

/**
 Application coordinator responsible for managing the main app setup and navigation flow.
 
 `Application` acts as a central coordinator that handles the initial application setup,
 dependency injection, and root view controller configuration. This class separates
 the application bootstrapping logic from the AppDelegate, following the single
 responsibility principle.
 
 ## Key Responsibilities
 - Creates and configures the main application window
 - Sets up the initial view controller hierarchy
 - Manages navigation controller configuration
 - Coordinates dependency injection for the video feed feature
 
 ## Architecture Benefits
 - Separates app lifecycle management from UI setup
 - Provides a clean entry point for dependency injection
 - Enables easier testing of app initialization logic
 - Centralizes navigation flow configuration
 
 ## Usage
 ```swift
 let application = Application(window: window)
 application.start()
 ```
 */
public class Application: NSObject {
    // MARK: - Private Properties
        
    /// The main application window for displaying content
    private var window: UIWindow?
    /// Navigation controller managing the view hierarchy
    private var navController: UINavigationController?
    
    // MARK: - Initialization
        
    /**
     Initializes the application coordinator with a window.
     
     - Parameter window: The main application window to manage.
     
     The window should be properly configured with the correct frame
     and window scene before being passed to this initializer.
     */
    init(window: UIWindow) {
        self.window = window
        super.init()
    }
    
    // MARK: - App Lifecycle
        
    /**
     Starts the application by setting up the initial view controller hierarchy.
     
     This method performs the following setup:
     1. Creates the main video feed view model with default dependencies
     2. Initializes the video feed view controller
     3. Sets up navigation controller with hidden navigation bar
     4. Configures the window with the root view controller
     5. Makes the window visible
     
     ## Dependency Configuration
     The method uses default implementations for all services, but could be
     extended to support custom dependency injection for testing or different
     app configurations.
     
     ## Navigation Setup
     The navigation bar is hidden to provide a full-screen video experience
     similar to TikTok or Instagram Reels.
     */
    func start() {
        // Create the main view model with default dependencies
        let viewModel = VideoFeedViewModel()
        // Initialize the root view controller
        let viewController =  VideoFeedViewController(viewModel: viewModel)
        // Set up navigation controller with full-screen presentation
        navController = UINavigationController(rootViewController: viewController)
        navController?.navigationBar.isHidden = true
        // Configure and display the window
        window?.rootViewController = navController
        window?.makeKeyAndVisible()
    }
}
