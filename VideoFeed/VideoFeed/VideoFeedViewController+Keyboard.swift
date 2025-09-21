//
//  VideoFeedViewController+Keyboard.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-21.
//

import UIKit

// MARK: - Keyboard Handling

/**
 Extension providing keyboard functionality.
 
 Manages the keyboard integration and its behvaior
 */

extension VideoFeedViewController {
    internal func setupKeyboardDismissOnTap() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTableViewTap))
        tapGesture.cancelsTouchesInView = false // allow didSelectRowAt to still work
        tableView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTableViewTap() {
        messageInputView.setFocused(false, animated: true)
    }
    
    /**
     Handles keyboard appearance with smooth layout adjustments.
     
     - Parameter userInfo: Keyboard notification user info containing frame and animation details.
     
     Adjusts the message input view position to stay above the keyboard
     while maintaining video feed visibility in the background.
     */
    internal func keyboardWillShow(userInfo: [AnyHashable: Any]) {
        guard let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let safeAreaBottom = view.safeAreaInsets.bottom
        
        // Update message input bottom constraint to sit on top of keyboard
        messageInputBottomConstraint.constant = -(keyboardHeight - safeAreaBottom + 8)
        
        // Animate the layout change
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve),
            animations: {
                self.view.layoutIfNeeded()
            }
        )
    }
    
    /**
     Handles keyboard dismissal with smooth layout restoration.
     
     - Parameter userInfo: Keyboard notification user info containing animation details.
     
     Restores the message input view to its original position at the bottom of the screen.
     */
    internal func keyboardWillHide(userInfo: [AnyHashable: Any]) {
        guard let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        // Restore message input to bottom position
        messageInputBottomConstraint.constant = -16
        
        // Animate the layout change
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve),
            animations: {
                self.view.layoutIfNeeded()
            }
        )
    }
}
