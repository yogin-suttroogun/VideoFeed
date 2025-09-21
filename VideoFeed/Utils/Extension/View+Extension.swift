//
//  View+Extension.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-21.
//

import UIKit

extension UIView {
    
    /// Animate a "tap" effect (shrink then bounce back)
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
