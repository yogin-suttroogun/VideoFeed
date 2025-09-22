//
//  View+Extension.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-21.
//

import UIKit

extension UIView {
    
    /**
     Animates a quick "tap" interaction by scaling the view down and restoring it.
     
     - Parameters:
     - scale: The scale factor to shrink the view. Default is `0.9`.
     - duration: The duration of the shrink/restore animation. Default is `0.1`.
     
     Use this for buttons or tappable elements to give tactile feedback.
     */
    func animateTap(scale: CGFloat = 0.9, duration: TimeInterval = 0.1) {
        UIView.animate(withDuration: duration, animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }) { _ in
            UIView.animate(withDuration: duration) {
                self.transform = .identity
            }
        }
    }
}
