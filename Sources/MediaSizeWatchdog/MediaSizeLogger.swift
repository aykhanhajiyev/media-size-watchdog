import Foundation

public protocol MediaSizeLogger {
    func log(_ message: String)
}

public struct DefaultMediaSizeLogger: MediaSizeLogger {
    public init() {}

    public func log(_ message: String) {
        print(message)
    }
}
