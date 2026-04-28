# MediaSizeWatchdog

`MediaSizeWatchdog` is a debug-only Swift package for detecting oversized image and video responses during iOS development.

## Usage

```swift
#if DEBUG
import MediaSizeWatchdog

MediaSizeWatchdog.shared.start(
    config: .init(
        imageThreshold: 700 * 1024,
        videoThreshold: 8 * 1024 * 1024,
        showsAlert: true
    ),
    adapters: [
        URLSessionMediaAdapter(reporter: MediaSizeWatchdog.shared),
        CustomNetworkAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
#endif
```

## Optional Library Adapters

These adapters are shipped as separate products so the core package does not force app code to use a specific networking or image loading library.

### Alamofire

Add the `MediaSizeWatchdogAlamofire` product and attach the adapter to the `Session` as an `EventMonitor`:

```swift
#if DEBUG
import Alamofire
import MediaSizeWatchdog
import MediaSizeWatchdogAlamofire

let alamofireAdapter = AlamofireMediaAdapter(reporter: MediaSizeWatchdog.shared)

MediaSizeWatchdog.shared.start(
    adapters: [alamofireAdapter]
)

let session = Session(eventMonitors: [alamofireAdapter])
#endif
```

### SDWebImage

Add the `MediaSizeWatchdogSDWebImage` product:

```swift
#if DEBUG
import MediaSizeWatchdog
import MediaSizeWatchdogSDWebImage

MediaSizeWatchdog.shared.start(
    adapters: [
        SDWebImageMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
#endif
```

### Kingfisher

Add the `MediaSizeWatchdogKingfisher` product:

```swift
#if DEBUG
import MediaSizeWatchdog
import MediaSizeWatchdogKingfisher

MediaSizeWatchdog.shared.start(
    adapters: [
        KingfisherMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
#endif
```

For custom `URLSession` instances, instrument the configuration before creating the session:

```swift
#if DEBUG
let configuration = URLSessionMediaAdapter.instrument(URLSessionConfiguration.default)
let session = URLSession(configuration: configuration)
#endif
```

For custom routers or networking layers, keep a `CustomNetworkAdapter` instance and call `record(url:size:mimeType:)` when a response completes.

## Release Builds

The public API remains available in release builds so integration code can compile, but `start`, `stop`, adapter interception, alerts, and reporting behavior are compiled as no-ops unless `DEBUG` is set.
