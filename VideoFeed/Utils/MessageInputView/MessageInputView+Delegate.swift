//
//  MessageInputView+Delegate.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-20.
//

import UIKit
import Combine

// MARK: - UITextViewDelegate

/**
 Provides text view delegate methods for `MessageInputView`.

 Manages placeholder visibility, send button state, and newline behavior.
 */
extension MessageInputView: UITextViewDelegate {
    /// Updates placeholder and layout when text changes.
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        updateSendButtonVisibility()
        adjustTextViewHeight()
    }
    /// Marks the input as focused when editing begins.
    func textViewDidBeginEditing(_ textView: UITextView) {
        setFocused(true, animated: true)
    }
    
    /// Handles newline behavior. Dismisses keyboard if empty, otherwise inserts line break.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            let currentText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if currentText.isEmpty {
                // When empty dismiss keyboard, do not insert newline
                setFocused(false, animated: true)
                return false
            } else {
                // When there is text, allow newline
                return true
            }
        }
        
        // For all other characters, allow the change
        return true
    }
}
