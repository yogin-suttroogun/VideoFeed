//
//  MockVideoService.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-10.
//

import Foundation
@testable import VideoFeed

class MockVideoService: VideoServiceProtocol {
    var mockResult: Result<[VideoItem], ErrorHandler> = .success([])
    var loadManifestCalled = false
    
    func loadManifest(completion: @escaping (Result<[VideoItem], ErrorHandler>) -> Void) {
        loadManifestCalled = true
        
        DispatchQueue.main.async {
            completion(self.mockResult)
        }
    }
}
