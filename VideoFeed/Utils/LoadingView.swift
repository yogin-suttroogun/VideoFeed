//
//  LoadingView.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import UIKit

/**
 A custom view that displays a loading indicator with descriptive text.
 
 `LoadingView` provides a consistent loading experience across the application
 with a centered activity indicator and accompanying message.
 
 ## Design
 - White activity indicator and text on transparent background
 - Centered layout that works across different screen sizes
 - System font with medium weight for readability
 
 ## Usage
 ```swift
 let loadingView = LoadingView()
 view.addSubview(loadingView)
 // Configure constraints to fill desired area
 ```
 */
final class LoadingView: UIView {
    // MARK: - UI Component
    
    /// Large-style activity indicator with white color for dark backgrounds
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()
    
    /// Descriptive label explaining the loading state
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.text = "Loading videos..."
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    /**
     Initializes the loading view with the specified frame.
     
     - Parameter frame: The initial frame for the view.
     
     Automatically sets up the UI layout during initialization.
     */
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    /**
     Required initializer for storyboard/XIB instantiation.
     
     - Parameter coder: The coder used for initialization.
     
     Not supported for this view - will cause a runtime error.
     */
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup UI
    
    /**
     Configures the UI layout with centered activity indicator and label.
     
     Sets up Auto Layout constraints to center both components with
     appropriate spacing between the indicator and text label.
     */
    private func setupUI() {
        addSubview(activityIndicator)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20)
        ])
    }
}
