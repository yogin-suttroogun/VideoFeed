//
//  ErrorView.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import UIKit

/**
 A custom view that displays error states with retry functionality.
 
 `ErrorView` provides a consistent error experience across the application,
 featuring an error icon, descriptive text, and a retry button to allow
 users to attempt recovery from error states.
 
 ## Features
 - System error icon with appropriate color coding
 - Configurable error messages via ErrorHandler
 - Integrated retry button with closure-based action handling
 - Responsive layout that adapts to different screen sizes
 
 ## Usage
 ```swift
 let errorView = ErrorView()
 errorView.configure(with: .somethingWentWrong)
 errorView.onRetry = {
     // Handle retry action
 }
 ```
 */
final class ErrorView: UIView {
    // MARK: - UI Component
    
    /// System warning icon to visually indicate error state
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        imageView.tintColor = .systemRed
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    /// Primary error title label
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ErrorHandler.somethingWentWrong.errorTitle
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// Detailed error description label
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.text = ErrorHandler.somethingWentWrong.errorDescription
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// Retry button for error recovery actions
    private lazy var retryButton: UIButton = {
        let button = UIButton()
        button.setTitle("Try Again", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .red
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
        
    /// Closure called when the retry button is tapped
    var onRetry: (() -> Void)?
    
    // MARK: - Initialization
        
    /**
     Initializes the error view with the specified frame.
     
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
     Configures the UI layout with vertically stacked error components.
     
     Creates a centered layout with icon, title, message, and retry button
     arranged vertically with appropriate spacing and margins.
     */
    private func setupUI() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(messageLabel)
        addSubview(retryButton)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -80),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Configuration
        
    /**
     Configures the error view with a specific error type.
     
     - Parameter error: The ErrorHandler case to display.
     
     Updates the icon and labels with the error's user-friendly description
     */
    func configure(with error: ErrorHandler) {
        iconImageView.image = UIImage(systemName: error.iconName ?? "exclamationmark.triangle")
        titleLabel.text = error.errorTitle
        messageLabel.text = error.errorDescription
    }
    
    /**
     Handles retry button tap events.
     
     Calls the onRetry closure if it has been set, allowing the parent
     view or controller to respond to retry attempts.
     */
    @objc private func retryTapped() {
        onRetry?()
    }
}
