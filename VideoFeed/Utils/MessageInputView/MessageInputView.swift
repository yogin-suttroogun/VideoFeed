//
//  MessageInputView.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-19.
//

import UIKit
import Combine

/**
 A custom view that provides text input functionality with reaction buttons for video feed interaction.
 
 `MessageInputView` implements a sophisticated input system that adapts to user interaction using
 Combine publishers for reactive data flow, maintaining consistency with the existing architecture.
 
 ## Key Features
 - Multi-line text input with 5-line maximum before internal scrolling
 - Reaction buttons (heart and share) in unfocused state
 - Send button that appears when text is entered
 - Keyboard-aware layout adjustments
 - Smooth state transition animations
 - Reactive publishers for all user interactions
 
 ## Publishers
 - `focusStatePublisher`: Emits focus state changes
 - `messageSentPublisher`: Emits sent messages
 - `heartTappedPublisher`: Emits heart reaction events
 - `shareTappedPublisher`: Emits share reaction events
 
 ## Usage
 ```swift
 let inputView = MessageInputView()
 
 inputView.focusStatePublisher.sink { isFocused in
     // Handle focus state changes
 }.store(in: &cancellables)
 
 inputView.messageSentPublisher.sink { message in
     // Handle message sending
 }.store(in: &cancellables)
 ```
 */
final class MessageInputView: UIView {
    
    // MARK: - Constants
    
    private struct Constants {
        static let maxLines = 5
        static let minHeight: CGFloat = 50
        static let maxHeight: CGFloat = 120
        static let containerPadding: CGFloat = 16
        static let buttonSize: CGFloat = 44
        static let cornerRadius: CGFloat = 25
        static let animationDuration: TimeInterval = 0.3
        static let placeholderText = "Send message"
    }
    
    // MARK: - Publishers
    
    /// Publisher that emits focus state changes
    private let focusStateSubject = CurrentValueSubject<Bool, Never>(false)
    /// Publisher that emits sent messages
    private let messageSentSubject = PassthroughSubject<String, Never>()
    /// Publisher that emits heart reaction events
    private let heartTappedSubject = PassthroughSubject<Void, Never>()
    /// Publisher that emits share reaction events
    private let shareTappedSubject = PassthroughSubject<Void, Never>()
    
    // MARK: - Public Publishers
    
    /**
     Publisher that emits when the focus state changes.
     
     Emits `true` when the input becomes focused, `false` when it loses focus.
     */
    var focusStatePublisher: AnyPublisher<Bool, Never> {
        focusStateSubject.eraseToAnyPublisher()
    }
    
    /**
     Publisher that emits when a message is sent.
     
     Emits the trimmed message string when the send button is tapped.
     */
    var messageSentPublisher: AnyPublisher<String, Never> {
        messageSentSubject.eraseToAnyPublisher()
    }
    
    /**
     Publisher that emits when the heart reaction button is tapped.
     */
    var heartTappedPublisher: AnyPublisher<Void, Never> {
        heartTappedSubject.eraseToAnyPublisher()
    }
    
    /**
     Publisher that emits when the share reaction button is tapped.
     */
    var shareTappedPublisher: AnyPublisher<Void, Never> {
        shareTappedSubject.eraseToAnyPublisher()
    }
    
    // MARK: - UI Components
    
    /// Container view with rounded background
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.layer.cornerRadius = Constants.cornerRadius
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// Text view for multi-line input
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textColor = .white
        textView.textAlignment = .left
        textView.textContainerInset = UIEdgeInsets(
            top: Constants.containerPadding,
            left: Constants.containerPadding,
            bottom: Constants.containerPadding,
            right: Constants.containerPadding
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    /// Placeholder label displayed when text view is empty
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = Constants.placeholderText
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// Heart reaction button
    private lazy var heartButton: UIButton = {
        let button = UIButton()
        let image = UIImage(systemName: "heart.fill")?.withRenderingMode(.alwaysOriginal).withTintColor(.red)
        button.setImage(image, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = Constants.buttonSize / 2
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(heartButtonTapped), for: .touchUpInside)
        return button
    }()
    
    /// Share reaction button
    private lazy var shareButton: UIButton = {
        let button = UIButton()
        let image = UIImage(systemName: "square.and.arrow.up.fill")?.withRenderingMode(.alwaysOriginal).withTintColor(.white)
        button.setImage(image, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = Constants.buttonSize / 2
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        return button
    }()
    
    /// Send button that appears when typing
    private lazy var sendButton: UIButton = {
        let button = UIButton()
        let image = UIImage(systemName: "paperplane.fill")?.withRenderingMode(.alwaysOriginal).withTintColor(.white)
        button.setImage(image, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = Constants.buttonSize / 2
        button.isHidden = true
        button.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        return button
    }()
    
    /// Stack view containing reaction buttons
    private lazy var reactionButtonsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [heartButton, shareButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Properties
    
    /// Current focus state of the input
    var isInputFocused: Bool {
        focusStateSubject.value
    }
    
    /// Height constraint for the container view
    private var containerHeightConstraint: NSLayoutConstraint!
    /// Trailing constraint for the text view (adjusts based on button visibility)
    private var textViewTrailingConstraint: NSLayoutConstraint!
    /// Leading constraint for reaction buttons
    private var reactionButtonsLeadingConstraint: NSLayoutConstraint!
    
    /// Haptic feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupGestureRecognizers()
        observeKeyboardNotifications()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(containerView)
        containerView.addSubview(textView)
        containerView.addSubview(placeholderLabel)
        containerView.addSubview(reactionButtonsStack)
        containerView.addSubview(sendButton)
    }
    
    private func setupConstraints() {
        // Container view constraints
        containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: Constants.minHeight)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerHeightConstraint
        ])
        
        // Text view constraints
        textViewTrailingConstraint = textView.trailingAnchor.constraint(equalTo: reactionButtonsStack.leadingAnchor, constant: -8)
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            textViewTrailingConstraint
        ])
        
        // Placeholder label constraints
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: Constants.containerPadding + 4),
            placeholderLabel.centerYAnchor.constraint(equalTo: textView.centerYAnchor)
        ])
        
        // Reaction buttons stack constraints
        reactionButtonsLeadingConstraint = reactionButtonsStack.leadingAnchor.constraint(greaterThanOrEqualTo: textView.trailingAnchor, constant: 8)
        
        NSLayoutConstraint.activate([
            reactionButtonsLeadingConstraint,
            reactionButtonsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            reactionButtonsStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            heartButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            heartButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize),
            shareButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            shareButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize)
        ])
        
        // Send button constraints
        NSLayoutConstraint.activate([
            sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            sendButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize)
        ])
    }
    
    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(containerTapped))
        containerView.addGestureRecognizer(tapGesture)
    }
    
    private func observeKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Actions
    
    @objc private func containerTapped() {
        if !isInputFocused {
            setFocused(true, animated: true)
        }
    }
    
    @objc private func heartButtonTapped() {
        impactFeedback.impactOccurred()
        
        // Animate button press
        heartButton.animateTap()
        
        // Emit event through publisher
        heartTappedSubject.send(())
    }
    
    @objc private func shareButtonTapped() {
        impactFeedback.impactOccurred()
        
        // Animate button press
        shareButton.animateTap()
        
        // Emit event through publisher
        shareTappedSubject.send(())
    }
    
    @objc internal func sendButtonTapped() {
        let trimmedText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedText.isEmpty
        else { return }
        
        impactFeedback.impactOccurred()
        
        // Send message through publisher
        messageSentSubject.send(trimmedText)
        
        // Clear text and reset state
        clearText()
        
        // Optionally dismiss keyboard
        setFocused(false, animated: true)
    }
    
    // MARK: - Keyboard Handling
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        // Keyboard handling is managed by the parent view controller
        // This method is here for potential future keyboard-specific animations
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        // Keyboard handling is managed by the parent view controller
        // This method is here for potential future keyboard-specific animations
    }
    
    // MARK: - Public Methods
    
    /**
     Sets the focus state of the input view.
     
     - Parameters:
     - focused: Whether the input should be focused.
     - animated: Whether to animate the transition.
     */
    func setFocused(_ focused: Bool, animated: Bool) {
        guard
            isInputFocused != focused
        else { return }
        
        // Update the focus state subject
        focusStateSubject.send(focused)
        
        updateUI(when: focused)
    }
    
    /**
     Perform the UI changes
     */
    private func updateUI(when focused: Bool) {
        updateSendButtonVisibility()
        if focused {
            self.textView.becomeFirstResponder()
            self.reactionButtonsStack.isHidden = true
        } else {
            self.textView.resignFirstResponder()
            self.reactionButtonsStack.isHidden = false
        }
        
        layoutIfNeeded()
    }
    
    /**
     Clears the text input.
     */
    func clearText() {
        textView.text = ""
        updatePlaceholderVisibility()
        updateSendButtonVisibility()
        adjustTextViewHeight()
    }
    
    // MARK: - Internal Methods
    
    internal func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    internal func updateSendButtonVisibility() {
        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let shouldShow = isInputFocused && hasText
        
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.sendButton.isHidden = shouldShow ? false : true
            self.sendButton.transform = shouldShow ? .identity : CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
    }
    
    internal func adjustTextViewHeight() {
        let fixedWidth = textView.frame.width
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let newHeight = max(Constants.minHeight, min(Constants.maxHeight, newSize.height))
        
        containerHeightConstraint.constant = newHeight
        
        // Enable scrolling if content exceeds max height
        textView.isScrollEnabled = newSize.height > Constants.maxHeight
        
        UIView.animate(withDuration: 0.2) {
            self.superview?.layoutIfNeeded()
        }
    }
}
