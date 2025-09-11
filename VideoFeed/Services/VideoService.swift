//
//  VideoService.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import Foundation
/**
 Protocol defining the interface for video data services.
 
 This protocol abstracts video data loading operations, enabling dependency injection
 and easier testing through mock implementations.
 */
protocol VideoServiceProtocol: AnyObject {
    /**
     Loads the video manifest from the network.
     
     - Parameter completion: Completion handler called with the result.
        Success case contains an array of `VideoItem` objects.
        Failure case contains an `ErrorHandler` describing the error.
     */
    func loadManifest(completion: @escaping (Result<[VideoItem], ErrorHandler>) -> Void)
}

/**
 Service responsible for loading video manifests from a remote endpoint.
 
 `VideoService` handles the network communication required to fetch video metadata
 from a JSON manifest file. It transforms the raw network response into structured
 `VideoItem` objects ready for use by the application.
 
 ## Network Architecture
 - Uses dependency injection for the network client
 - Supports custom endpoints through URL configuration
 - Provides structured error handling with user-friendly messages
 
 ## JSON Format Expected
 ```json
 {
   "videos": [
     "https://example.com/video1.mp4",
     "https://example.com/video2.mp4"
   ]
 }
 ```
 
 ## Usage
 ```swift
 let service = VideoService()
 service.loadManifest { result in
     switch result {
     case .success(let videos):
         // Handle video items
     case .failure(let error):
         // Handle error
     }
 }
 ```
 */
class VideoService: VideoServiceProtocol {
        
    /// Network client for performing HTTP requests
    private let networkClient: NetworkClientProtocol?
    /// The URL endpoint for the video manifest JSON file
    private let manifestURL = "https://cdn.dev.airxp.app/AgentVideos-HLS-Progressive/manifest.json"
    
    // MARK: - Initialization
        
    /**
     Initializes the video service with a network client.
     
     - Parameter networkClient: The network client to use for HTTP requests.
     Defaults to `BaseNetworkClient()` if not provided.
     
     ## Dependency Injection
     This design allows for easy testing by injecting mock network clients:
     ```swift
     let mockClient = MockNetworkClient()
     let service = VideoService(networkClient: mockClient)
     ```
     */
    init(networkClient: NetworkClientProtocol? = BaseNetworkClient()) {
        self.networkClient = networkClient
    }
    
    /**
     Loads the video manifest from the configured endpoint.
     
     - Parameter completion: Completion handler called with the operation result.
     
     ## Process Flow
     1. Validates the manifest URL
     2. Creates an API endpoint configuration
     3. Performs the network request
     4. Decodes the JSON response into `VideoModel`
     5. Transforms URL strings into `VideoItem` objects with indices
     6. Returns the structured video items
     
     ## Error Handling
     - Invalid URL: Returns `.invalidURL` error
     - Network failures: Handled by the network client
     - Empty response: Returns empty array (success case)
     - Decoding failures: Returns `.decodingFailed` error
     
     ## Threading
     The completion handler may be called on a background thread.
     Ensure UI updates are dispatched to the main queue.
     */
    func loadManifest(completion: @escaping (Result<[VideoItem], ErrorHandler>) -> Void) {
        guard
            let url = URL(string: manifestURL)
        else {
            completion(.failure(.invalidURL))
            return
        }
        
        let endpoint = APIEndPoint(url: url)
        
        networkClient?.request(endpoint, responseType: VideoModel.self) { result in
            switch result {
            case .success(let data):
                let videoItems = data.videos?.enumerated().map { index, urlString in
                    VideoItem(urlString: urlString, index: index)
                } ?? []
                completion(.success(videoItems))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
