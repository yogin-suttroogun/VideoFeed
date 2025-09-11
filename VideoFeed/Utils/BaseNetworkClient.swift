//
//  BaseNetworkClient.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-07.
//

import Foundation
import Combine

/**
 Enum of supported HTTP methods.
 
 Defines the HTTP methods available for network requests, with string raw values
 that can be directly assigned to URLRequest.httpMethod.
 */
enum HTTPMethod: String {
    /// HTTP GET method for retrieving data
    case GET = "GET"
    /// HTTP POST method for creating resources
    case POST = "POST"
    /// HTTP PUT method for updating resources
    case PUT = "PUT"
    /// HTTP DELETE method for removing resources
    case DELETE = "DELETE"
}

/**
 Configuration object for API endpoint requests.
 
 `APIEndPoint` encapsulates all the information needed to make an HTTP request,
 including URL, method, headers, and body data.
 */
struct APIEndPoint {
    /// The target URL for the request
    let url: URL?
    /// The HTTP method to use, defaults to GET
    let method: HTTPMethod?
    /// Optional HTTP headers to include in the request
    let headers: [String: String]?
    /// Optional request body data
    let body: Data?
    
    /**
     Initializes an API endpoint configuration.
     
     - Parameters:
     - url: The target URL for the request.
     - method: The HTTP method to use, defaults to GET.
     - headers: Optional HTTP headers to include.
     - body: Optional request body data.
     */
    init(url: URL, method: HTTPMethod = .GET, headers: [String : String]? = nil, body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

/**
 Protocol defining the interface for network client implementations.
 
 This protocol enables dependency injection and testing by abstracting
 the network layer implementation details.
 */
protocol NetworkClientProtocol {
    /**
     Performs a network request and decodes the response.
     
     - Parameters:
     - endpoint: The endpoint configuration for the request.
     - responseType: The type to decode the response into.
     - completion: Completion handler with the decoded result or error.
     */
    func request<T: Codable>(_ endpoint: APIEndPoint,
                             responseType: T.Type,
                             completion: @escaping (Result<T, ErrorHandler>) -> Void)
}

/**
 Concrete implementation of the network client protocol using URLSession.
 
 `BaseNetworkClient` provides a standard HTTP client implementation with
 automatic JSON decoding and structured error handling.
 
 ## Features
 - Generic JSON decoding for any Codable response type
 - Automatic header application from endpoint configuration
 - Structured error handling with user-friendly messages
 - Configurable URLSession and JSONDecoder for testing
 
 ## Usage
 ```swift
 let client = BaseNetworkClient()
 let endpoint = APIEndPoint(url: url)
 
 client.request(endpoint, responseType: VideoModel.self) { result in
     // Handle result
 }
 ```
 */
final class BaseNetworkClient: NetworkClientProtocol {
    // MARK: - Dependencies
        
    /// The URLSession instance used for network requests
    private let session: URLSession
    /// The JSONDecoder instance used for response parsing
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
        
    /**
     Initializes the network client with configurable dependencies.
     
     - Parameters:
     - session: The URLSession to use for requests, defaults to `.shared`.
     - decoder: The JSONDecoder to use for response parsing, defaults to a new instance.
     
     This design enables dependency injection for testing with mock sessions or
     custom decoder configurations.
     */
    init(session: URLSession = .shared, decoder: JSONDecoder = .init()) {
        self.session = session
        self.decoder = decoder
    }
    
    // MARK: - NetworkClientProtocol Implementation
    
    /**
     Performs a generic network request with automatic JSON decoding.
     
     - Parameters:
     - endpoint: The endpoint configuration containing URL, method, headers, and body.
     - responseType: The Codable type to decode the response into.
     - completion: Completion handler called with the result.
     
     ## Process Flow
     1. Validates the endpoint URL
     2. Configures URLRequest with method, body, and headers
     3. Performs the network request using URLSession
     4. Validates response data availability
     5. Attempts JSON decoding into the specified type
     6. Returns structured success or error result
     
     ## Error Mapping
     - Invalid URL → `.invalidURL`
     - General error → `.somethingWentWrong`
     - No data available → `.empty`
     - JSON decoding failures → `.decodingFailed`
     
     ## Threading
     The completion handler may be called on a background thread.
     UI updates should be dispatched to the main queue.
     */
    func request<T: Codable>(_ endpoint: APIEndPoint, responseType: T.Type, completion: @escaping (Result<T, ErrorHandler>) -> Void) {
        guard
            let url = endpoint.url
        else {
            completion(.failure(.invalidURL))
            return
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method?.rawValue
        urlRequest.httpBody = endpoint.body
        
        endpoint.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        session.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard
                let strongSelf = self
            else { return }
            
            if error != nil {
                completion(.failure(.somethingWentWrong))
                return
            }
            
            guard
                let data = data
            else {
                completion(.failure(.empty))
                return
            }
            
            do {
                let decodedResponse = try strongSelf.decoder.decode(responseType, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(.decodingFailed))
            }
        }.resume()
    }
}
