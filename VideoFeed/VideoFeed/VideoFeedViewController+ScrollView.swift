//
//  VideoFeedViewController+ScrollView.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-09.
//

import UIKit

// MARK: - UIScrollViewDelegate
/**
 Extension providing scroll view delegate functionality.
 
 Manages scroll-based video index tracking and playback control.
 */
extension VideoFeedViewController: UIScrollViewDelegate {
    /**
     Called when the scroll view's content offset changes.
     
     - Parameter scrollView: The scroll view that scrolled.
     
     Calculates the current video index based on scroll position and updates
     the view model accordingly for proper video playback and prefetching.
     */
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = Int(round(scrollView.contentOffset.y / scrollView.frame.height))
        let clampedIndex = max(0, min(pageIndex, viewModel.videos.count - 1))
        
        if clampedIndex != viewModel.currentVideoIndex.value {
            viewModel.updateCurrentVideoIndex(clampedIndex)
        }
    }
    
    /**
     Called when the user begins dragging the scroll view.
     
     - Parameter scrollView: The scroll view being dragged.
     
     Notifies the view model that scrolling has started to optimize playback behavior.
     */
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        viewModel.setScrolling(true)
    }
    
    /**
     Called when the user stops dragging the scroll view.
     
     - Parameters:
     - scrollView: The scroll view that was dragged.
     - decelerate: Whether the scroll view will continue decelerating.
     
     Updates scrolling state if deceleration won't continue.
     */
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            viewModel.setScrolling(false)
        }
    }
    
    /**
     Called when the scroll view's deceleration ends.
     
     - Parameter scrollView: The scroll view that finished decelerating.
     
     Notifies the view model that scrolling has completely stopped.
     */
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        viewModel.setScrolling(false)
    }
}
