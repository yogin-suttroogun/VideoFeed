//
//  ErrorHandler.swift
//  VideoFeed
//
//  Created by Yogin Kumar Suttroogun on 2025-09-04.
//

import Foundation

/**
 Enum of application-specific errors with user-friendly descriptions.
 
 `ErrorHandler` provides structured error handling throughout the application
 with consistent, user-facing error messages that can be displayed directly in the UI.
 
 ## Design Philosophy
 Each error case includes both a technical identifier and a user-friendly message,
 enabling both debugging and user experience considerations.
 */
enum ErrorHandler: LocalizedError {
    /// Request succeeded but returned an empty dataset
    case empty
    /// The provided URL string could not be parsed into a valid URL
    case invalidURL
    /// JSON decoding failed due to format mismatch or corruption
    case decodingFailed
    /// Generic error for unexpected failures
    case somethingWentWrong
    /// No internet connection is available
    case noInternetConnection
    
    /**
     User-facing error title for display in error dialogs.
     
     Provides a consistent, friendly error title regardless of the specific error type.
     */
    var errorTitle: String {
        switch self {
        case .noInternetConnection:
            return "No Internet Connection"
        default:
            return "Oops! Something went wrong."
        }
    }
    
    /**
     User-facing error description explaining the issue and potential solutions.
     
     Returns localized, user-friendly error messages that can be displayed
     directly in the UI without exposing technical details.
     */
    var errorDescription: String? {
        switch self {
        case .empty:
            return "No videos are available right now."
        case .invalidURL:
            return "The link you tried to open is not valid."
        case .decodingFailed:
            return "We are currently having trouble retrieving the videos"
        case .somethingWentWrong:
            return "Give it another try now or come back later if the problem persists."
        case .noInternetConnection:
            return "Please check your internet connection."
        }
    }
    
    /**
     Set appropriate icon based on error type to demonstrate clearly the issue
     
     Returns user-friendly icon name that can be displayed
     directly in the UI
     */
    var iconName: String? {
        switch self {
        case .noInternetConnection:
            return "wifi.slash"
        case .empty:
            return "tray"
        default:
            return  "exclamationmark.triangle"
        }
    }
}
