//
//  VideoFeedViewController+Keyboard.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-21.
//

import UIKit

// MARK: - Keyboard Handling

/**
 Represents keyboard state and animation parameters for smooth layout transitions.
 
 Encapsulates all necessary keyboard information to perform coordinated layout
 animations that match the system keyboard behavior.
 */
struct KeyboardInfo {
    /// Whether the keyboard is currently visible on screen
    let isVisible: Bool
    /// The height of the keyboard in points
    let height: CGFloat
    /// Duration of the keyboard show/hide animation
    let animationDuration: TimeInterval
    /// Animation curve options to match keyboard transitions
    let animationOptions: UIView.AnimationOptions
    
    /**
     Default keyboard info representing the hidden state.
     
     Used as the initial state and when keyboard is dismissed.
     */
    static let hidden = KeyboardInfo(
        isVisible: false,
        height: 0,
        animationDuration: 0.25,
        animationOptions: []
    )
}

/**
 Extension providing keyboard-aware layout management for video feed.
 
 This extension handles the complex coordination between keyboard visibility,
 message input positioning, and video feed layout to ensure an optimal user
 experience during text input interactions.
 
 */
extension VideoFeedViewController {
    
    // MARK: - Tap Gesture Setup
    
    /**
     Sets up tap gesture recognition for keyboard dismissal.
     
     Configures a tap gesture recognizer on the table view that allows users
     to dismiss the keyboard by tapping on video content or empty areas.
     
     ## Gesture Configuration
     - Non-canceling: Preserves table view's normal touch handling
     - Applied to table view: Covers the main content area
     - Coordinated with input focus: Updates view model state
     
     This method should be called during view controller setup to ensure
     proper keyboard dismissal behavior throughout the user session.
     */
    internal func setupKeyboardDismissOnTap() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTableViewTap))
        tapGesture.cancelsTouchesInView = false // allow didSelectRowAt to still work
        tableView.addGestureRecognizer(tapGesture)
    }
    
    /**
     Handles tap gestures on the table view for keyboard dismissal.
     
     Called when the user taps on the video feed content while the message
     input is focused, providing an intuitive way to dismiss the keyboard
     and return to normal video browsing.
     */
    @objc private func handleTableViewTap() {
        viewModel.setInputFocused(false)
    }
    
    // MARK: - Keyboard Event Handling
    
    /**
     Handles keyboard appearance with smooth layout adjustments.
     
     - Parameter userInfo: Keyboard notification user info containing frame and animation details.
     
     Adjusts the message input view position to stay above the keyboard
     while maintaining video feed visibility in the background. The input
     view smoothly animates to its new position using the system keyboard's
     animation parameters.

     */
    internal func handleKeyboardWillShow(userInfo: [AnyHashable: Any]) {
        guard let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        let keyboardInfo = KeyboardInfo(
            isVisible: true,
            height: keyboardFrame.height,
            animationDuration: duration,
            animationOptions: UIView.AnimationOptions(rawValue: curve)
        )
        
        handleKeyboardChange(keyboardInfo)
    }
    
    /**
     Handles keyboard dismissal with smooth layout restoration.
     
     - Parameter userInfo: Keyboard notification user info containing animation details.
     
     Restores the message input view to its original position at the bottom
     of the screen, accounting for safe area insets. The animation matches
     the system keyboard dismissal for seamless visual continuity.
     */
    internal func handleKeyboardWillHide(userInfo: [AnyHashable: Any]) {
        guard let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        let keyboardInfo = KeyboardInfo(
            isVisible: false,
            height: 0,
            animationDuration: duration,
            animationOptions: UIView.AnimationOptions(rawValue: curve)
        )
        
        handleKeyboardChange(keyboardInfo)
    }
    
    /**
     Unified keyboard change handler that performs layout adjustments.
     
     - Parameter keyboardInfo: Structured keyboard information including visibility,
     height, and animation parameters.
     
     ## Layout Calculation
     Calculates the appropriate bottom constraint value for the message input view:
     - **Keyboard visible**: Positions input above keyboard, accounting for safe area
     - **Keyboard hidden**: Positions input at bottom with standard margin
     */
    internal func handleKeyboardChange(_ keyboardInfo: KeyboardInfo) {
        let keyboardHeight = keyboardInfo.height
        let safeAreaBottom = view.safeAreaInsets.bottom
        
        if keyboardInfo.isVisible {
            // Position input above keyboard, accounting for safe area overlap
            messageInputBottomConstraint.constant = -(keyboardHeight - safeAreaBottom + 8)
        } else {
            // Return to default bottom position with standard margin
            messageInputBottomConstraint.constant = -16
        }
        
        UIView.animate(
            withDuration: keyboardInfo.animationDuration,
            delay: 0,
            options: keyboardInfo.animationOptions,
            animations: {
                self.view.layoutIfNeeded()
            }
        )
    }
}
