//
//  VideoFeedViewController+MessageInput.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-21.
//

import UIKit

extension VideoFeedViewController {
    // MARK: - Message Input Handling

    /**
     Handles message sending from the input view.
     
     - Parameter message: The message text to send.
     
     This method can be extended to integrate with a messaging service,
     analytics tracking, or other message handling systems.
     */
    internal func handleMessageSent(_ message: String) {
        // Add haptic feedback for successful send
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        print("Message sent: \(message)")
        
        // For now, we'll just log it and provide user feedback
        showTemporaryFeedback("Message sent!")
    }
    
    /**
     Handles heart reaction button tap.
     
     Provides visual feedback and can be extended to handle like/heart
     functionality for the current video.
     */
    internal func handleHeartReaction() {
        print("Heart reaction tapped for video at index: \(viewModel.currentVideoIndex.value)")
        showTemporaryFeedback("❤️")
    }
    
    /**
     Handles share reaction button tap.
     
     Can be extended to present sharing options or directly share
     the current video content.
     */
    internal func handleShareReaction() {
        let currentVideoIndex = viewModel.currentVideoIndex.value
        print("Share reaction tapped for video at index: \(currentVideoIndex)")

        presentShareOptions(for: currentVideoIndex)
    }
    
    /**
     Shows a temporary feedback message to the user.
     
     - Parameter message: The feedback message to display.
     */
    internal func showTemporaryFeedback(_ message: String) {
        let feedbackLabel = UILabel()
        feedbackLabel.text = message
        feedbackLabel.textColor = .white
        feedbackLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        feedbackLabel.textAlignment = .center
        feedbackLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        feedbackLabel.layer.cornerRadius = 20
        feedbackLabel.clipsToBounds = true
        feedbackLabel.alpha = 0
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            feedbackLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            feedbackLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        // Animate in and out
        UIView.animateKeyframes(withDuration: 2.0, delay: 0, options: []) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) {
                feedbackLabel.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                feedbackLabel.alpha = 0
            }
        } completion: { _ in
            feedbackLabel.removeFromSuperview()
        }
    }
    
    /**
     Presents sharing options for the specified video.
     
     - Parameter videoIndex: The index of the video to share.
     */
    private func presentShareOptions(for videoIndex: Int) {
        let alertController = UIAlertController(
            title: "Share Video",
            message: "Choose how you'd like to share this video",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in
            // Implement copy link functionality
            print("Copy link for video \(videoIndex)")
            self.showTemporaryFeedback("Link copied!")
        })
        
        alertController.addAction(UIAlertAction(title: "Share to Messages", style: .default) { _ in
            // Implement Messages sharing
            print("Share to Messages for video \(videoIndex)")
        })
        
        alertController.addAction(UIAlertAction(title: "Share to Social", style: .default) { _ in
            // Implement social sharing
            print("Share to social for video \(videoIndex)")
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
}
