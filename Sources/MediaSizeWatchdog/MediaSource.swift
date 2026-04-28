import Foundation

public enum MediaSource: String, Sendable {
    case urlSession
    case alamofire
    case sdWebImage
    case kingfisher
    case nuke
    case custom
}
