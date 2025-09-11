//
//  VideoModel.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import Foundation

/**
 Data model representing the JSON response structure from the video manifest endpoint.
 
 This model matches the expected JSON format from the server and is used for
 automatic JSON decoding of the network response.
 
 ## JSON Structure
 ```json
 {
   "videos": [
     "https://example.com/video1.mp4",
     "https://example.com/video2.mp4"
   ]
 }
 ```
 */
public struct VideoModel: Codable {
    let videos: [String]?
}

/**
 Structured representation of a video item with additional metadata.
 
 `VideoItem` transforms raw URL strings from the manifest into a more useful
 structure that includes indexing and URL validation.
 
 ## Features
 - Unique identifier for each video instance
 - Safe URL parsing with nil handling for invalid URLs
 - Index tracking for position-based operations
 */
struct VideoItem {
    /// Unique identifier for this video item instance
    let id = UUID()
    /// Parsed URL object, nil if the URL string was invalid
    let url: URL?
    /// Zero-based index of this video in the original array
    let index: Int?
    
    /**
     Initializes a video item from a URL string and index.
     
     - Parameters:
     - urlString: The URL string for the video, may be nil or invalid.
     - index: The position of this video in the source array.
     
     The URL is safely parsed and will be nil if the string is invalid or nil.
     */
    init(urlString: String?, index: Int?) {
        self.url = URL(string: urlString ?? "")
        self.index = index
    }
}
