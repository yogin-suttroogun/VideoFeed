//
//  VideoFeedViewController+Keyboard.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-21.
//

import UIKit

// MARK: - Keyboard Handling

/**
 Represents keyboard state and animation parameters.
 */
struct KeyboardInfo {
    let isVisible: Bool
    let height: CGFloat
    let animationDuration: TimeInterval
    let animationOptions: UIView.AnimationOptions
    
    static let hidden = KeyboardInfo(
        isVisible: false,
        height: 0,
        animationDuration: 0.25,
        animationOptions: []
    )
}

/**
 Adjusts the input view position when the keyboard appears or hides,
 ensuring the message input remains accessible without covering content.
 */

extension VideoFeedViewController {
    internal func setupKeyboardDismissOnTap() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTableViewTap))
        tapGesture.cancelsTouchesInView = false // allow didSelectRowAt to still work
        tableView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTableViewTap() {
        viewModel.setInputFocused(false)
    }
    
    /**
     Handles keyboard appearance with smooth layout adjustments.
     
     - Parameter userInfo: Keyboard notification user info containing frame and animation details.
     
     Adjusts the message input view position to stay above the keyboard
     while maintaining video feed visibility in the background.
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
     
     Restores the message input view to its original position at the bottom of the screen.
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
    
    internal func handleKeyboardChange(_ keyboardInfo: KeyboardInfo) {
        let keyboardHeight = keyboardInfo.height
        let safeAreaBottom = view.safeAreaInsets.bottom
        
        if keyboardInfo.isVisible {
            messageInputBottomConstraint.constant = -(keyboardHeight - safeAreaBottom + 8)
        } else {
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
