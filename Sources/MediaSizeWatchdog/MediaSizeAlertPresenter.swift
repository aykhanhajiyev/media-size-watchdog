import Foundation

enum MediaSizeAlertPresenter {
    static func show(issue: MediaSizeIssue) {
        #if DEBUG && canImport(UIKit)
        DispatchQueue.main.async {
            guard
                let rootViewController = UIApplication.shared.mediaSizeWatchdogTopViewController(),
                rootViewController.presentedViewController == nil
            else {
                return
            }

            let message = """
            URL: \(issue.url.absoluteString)
            Size: \(MediaSizeFormatter.string(from: issue.size))
            Threshold: \(MediaSizeFormatter.string(from: issue.threshold))
            Source: \(issue.source.rawValue)
            """

            let alert = UIAlertController(
                title: "Oversized \(issue.mediaType.rawValue.capitalized)",
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            rootViewController.present(alert, animated: true)
        }
        #endif
    }
}

#if DEBUG && canImport(UIKit)
import UIKit

private extension UIApplication {
    func mediaSizeWatchdogTopViewController() -> UIViewController? {
        let activeWindow = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }

        var topViewController = activeWindow?.rootViewController

        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }

        if let navigationController = topViewController as? UINavigationController {
            return navigationController.visibleViewController
        }

        if let tabBarController = topViewController as? UITabBarController {
            return tabBarController.selectedViewController
        }

        return topViewController
    }
}
#endif
