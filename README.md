# VideoFeed App

A high-performance iOS video feed application that displays videos in a TikTok-style vertical scrolling interface. The app intelligently manages video playback, memory usage, and network resources while providing smooth scrolling performance.

## Features

- **Infinite Vertical Scrolling**: TikTok-style video feed with smooth pagination
- **Intelligent Video Prefetching**: Adaptive prefetching based on network conditions
- **Memory-Efficient Video Player Pool**: Reuses video players to minimize memory footprint
- **Network-Aware Performance**: Automatically adjusts video quality and prefetching based on connection type
- **Auto-Looping Videos**: Videos automatically loop when they reach the end
- **Background/Foreground Handling**: Proper video pause/resume on app lifecycle changes
- **Error Handling**: Comprehensive error handling with user-friendly retry mechanisms

## Architecture Overview

### Design Patterns

- **MVVM (Model-View-ViewModel)**: Clean separation of concerns with reactive data binding
- **Object Pool Pattern**: Efficient video player management through `VideoPlayerPool`
- **Observer Pattern**: Using Combine framework for reactive programming
- **Service Layer**: Abstracted network operations through `VideoService`
- **Dependency Injection**: Loose coupling between components for testability

### Core Components

#### VideoFeedViewController
Main view controller managing the video feed interface with table view implementation and lifecycle handling.

#### VideoFeedViewModel
Business logic coordinator managing video playback states, prefetching, and reactive data binding using Combine publishers.

#### VideoPlayerPool
Memory-efficient AVPlayer management with a maximum of 5 concurrent instances, automatic player assignment, and readiness monitoring.

#### VideoPrefetchManager
Network-aware prefetching with three strategies:
- **WiFi**: Aggressive (7 videos ahead)
- **Cellular**: Conservative (3 videos ahead)
- **Poor Connection**: Minimal (1 video ahead)

#### VideoService
Network abstraction layer handling API communication for video manifest retrieval.

## Quick Start

### Prerequisites

- iOS 18.5+
- Xcode 16.4+
- Swift 5.0+

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yogin-suttroogun/Video-Feed.git
cd VideoFeed
```

2. Open the project in Xcode:
```bash
open VideoFeed.xcodeproj
```

3. Build and run the project:
- Select your target device/simulator
- Press `Cmd + R` or click the Run button

## Technical Implementation

### Memory Management Strategy

The app implements several memory optimization techniques:

1. **Player Pool**: Maintains a maximum of 5 AVPlayer instances, reusing them across video cells
2. **Asset Prefetching**: Intelligently prefetches video assets based on scroll position and network conditions
3. **Cell Reuse**: Leverages UITableView's cell reuse mechanism for optimal memory usage
4. **Automatic Cleanup**: Releases unused players and prefetched assets automatically

### Network Intelligence

The app adapts to network conditions automatically:
- Monitors connection type changes in real-time
- Adjusts prefetch strategy dynamically
- Reduces bandwidth usage on cellular connections
- Handles offline scenarios gracefully

### Performance Optimizations

1. **Debounced Scroll Events**: Prevents excessive player state changes during scrolling
2. **Asynchronous Asset Loading**: Non-blocking video asset preparation
3. **Smart Player Assignment**: Reuses existing players when possible
4. **Background Processing**: Network monitoring and prefetching on background queues

## Configuration

### Network Settings

The app fetches video manifest from:
```
https://cdn.dev.airxp.app/AgentVideos-HLS-Progressive/manifest.json
```

To change the endpoint, modify the `manifestURL` constant in `VideoService.swift`.

### Video Manifest Format

Expected JSON structure:
```json
{
  "videos": [
    "https://example.com/video1.mp4",
    "https://example.com/video2.mp4",
    "https://example.com/video3.mp4"
  ]
}
```

### Player Pool Configuration

Adjust the maximum number of concurrent players in `VideoPlayerPool.swift`:
```swift
private let maxPlayers = 5 // Modify as needed
```

### Prefetch Strategy Tuning

Customize prefetch counts in `PrefetchStrategy` enum:
```swift
var prefetchCount: Int {
    switch self {
    case .aggressive: return 7    // WiFi
    case .conservative: return 3  // Cellular
    case .minimal: return 1       // Poor connection
    }
}
```

## Testing Strategy

### Device Testing

The app includes comprehensive test targets:

**Unit Tests** (`VideoFeedTests`): Test business logic and data models

### Network Testing

Test the app under different network conditions:
- WiFi connection
- Cellular connection (3G, 4G, 5G)
- Poor network conditions
- Offline scenarios

### Performance Testing

Monitor key performance metrics:
- Memory usage during scrolling
- CPU usage during video playback
- Network bandwidth consumption
- Battery drain analysis

### Running Tests

```bash
# Unit Tests
xcodebuild test -project VideoFeed.xcodeproj -scheme VideoFeed -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Coverage

- **Unit Tests**: Business logic, data models, and service layer
- **Performance Testing**: Memory usage, CPU utilization, network efficiency
- **Network Testing**: WiFi, cellular, and offline scenarios

## Project Structure

```
VideoFeed/
├── Base/                          # App lifecycle and coordination
│   ├── AppDelegate.swift
│   ├── Application.swift          # Dependency injection coordinator
│   ├── SceneDelegate.swift
│   └── Base.lproj/
├── VideoFeed/                     # Main video feed feature
│   ├── VideoFeedViewController.swift
│   ├── VideoFeedViewController+TableView.swift
│   ├── VideoFeedViewController+ScrollView.swift
│   ├── VideoFeedViewModel.swift
│   ├── VideoModel.swift
│   └── VideoTableViewCell.swift
├── Services/                      # Business logic services
│   ├── VideoService.swift
│   ├── VideoPlayerPool.swift
│   └── VideoPrefetchManager.swift
├── Utils/                         # Utility classes
│   ├── BaseNetworkClient.swift
│   ├── ErrorHandler.swift
│   ├── ErrorView.swift
│   └── LoadingView.swift
└── Assets.xcassets/              # Visual assets
```

## Performance Metrics

### Memory Usage
- Idle: 50-100MB
- Active scrolling: 150-200MB
- Bounded growth with automatic cleanup

### CPU Usage
- Idle: 1-3%
- Scrolling: 15-25%
- Video decoding: 20-40% (device dependent)

### Network Efficiency
- Manifest load: ~1KB
- Video prefetch: 100KB-2MB per video
- Adaptive bandwidth based on connection type

## Dependencies

Built entirely with native iOS frameworks:
- **UIKit**: Interface components
- **AVFoundation**: Video playback and asset management
- **Combine**: Reactive programming and data binding
- **Network**: Network path monitoring
- **Foundation**: Core utilities and data structures

No third-party dependencies required.

## Error Handling

Comprehensive error management system:

1. **Network Errors**: Graceful connectivity issue handling with retry mechanisms
2. **Video Loading Errors**: Automatic retry with user feedback
3. **Decoding Errors**: Robust JSON parsing with fallback strategies  
4. **Memory Warnings**: Proactive resource cleanup

## Troubleshooting

### Common Issues

1. **Videos not loading**:
   - Check network connectivity
   - Verify manifest URL accessibility
   - Review console logs for network errors

2. **Poor scrolling performance**:
   - Monitor memory usage in Instruments
   - Check for memory warnings in console
   - Reduce prefetch count for lower-end devices

3. **Audio session conflicts**:
   - Ensure proper audio session setup
   - Check for conflicts with other audio apps
   - Verify background audio permissions

### Debug Settings

Enable detailed logging by modifying debug flags in respective service classes.

## Contributing

Guidelines for contributors:

1. Follow Swift API Design Guidelines
2. Maintain comprehensive documentation
3. Include unit tests for new features
4. Ensure memory efficiency
5. Test across device types and network conditions

## Architecture Benefits

- **Scalability**: Modular design supports easy feature additions
- **Testability**: Protocol-based dependency injection enables comprehensive testing
- **Performance**: Memory-efficient patterns prevent common video app issues
- **Maintainability**: Clean separation of concerns and reactive data flow
- **User Experience**: Smooth scrolling with intelligent resource management

## License

© Yogin Suttroogun

## Version History

**v1.0**: Initial release
- Core video feed functionality
- Player pool and prefetch management
- Network-aware optimizations
