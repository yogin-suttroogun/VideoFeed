//
//  VideoFeedViewController+TableView.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-09.
//

import UIKit

// MARK: - UITableViewDataSource

/**
 Extension providing table view data source functionality.
 
 Manages the creation and configuration of video cells for the table view.
 */
extension VideoFeedViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.videos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let video = viewModel.videos[indexPath.row]
        
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: VideoTableViewCell.identifier,
            for: indexPath
        ) as? VideoTableViewCell else {
            return UITableViewCell()
        }
        
        if let player = viewModel.getPlayer(for: indexPath.row) {
            cell.configure(with: player, video: video)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

/**
 Extension providing table view delegate functionality.
 
 Manages cell height, display lifecycle, and player assignment.
 */
extension VideoFeedViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.bounds.height
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        viewModel.releasePlayer(for: indexPath.row)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let video = viewModel.videos[indexPath.row]
        
        if let videoCell = cell as? VideoTableViewCell,
           let player = viewModel.getPlayer(for: indexPath.row) {
            videoCell.configure(with: player, video: video)
        }
    }
}
