//
//  Video+SwiftUI.swift
//  
//
//  Created by Christian Elies on 02.12.19.
//

#if canImport(SwiftUI) && (!os(macOS) || targetEnvironment(macCatalyst))
import MediaCore
import PhotosUI
import SwiftUI

@available (iOS 13, macOS 10.15, tvOS 13, *)
public extension Video {
    /// Creates a ready-to-use `SwiftUI` view representation of the receiver
    ///
    var view: some View {
        VideoView(video: self)
    }
}

#if !os(tvOS)
@available (iOS 13, macOS 10.15, *)
public extension Video {
    /// Alias for a completion block getting a `Result` containing a `<Media.URL<Video>`
    /// on success or an `Error` on failure
    ///
    typealias ResultMediaURLVideoCompletion = (Result<Media.URL<Video>, Swift.Error>) -> Void

    /// Creates a ready-to-use `SwiftUI` view for capturing `Video`s
    /// If an error occurs during initialization a `SwiftUI.Text` with the `localizedDescription` is shown.
    ///
    /// - Parameter completion: A closure wich gets `Media.URL<Video>` on `success` or `Error` on `failure`.
    ///
    /// - Returns: some View
    static func camera(_ completion: @escaping ResultMediaURLVideoCompletion) -> some View {
        camera(errorView: { error in Text(error.localizedDescription) }, completion)
    }

    /// Creates a ready-to-use `SwiftUI` view for capturing `Video`s
    /// If an error occurs during initialization the provided `errorView` closure is used to construct the view to be displayed.
    ///
    /// - Parameter errorView: A closure that constructs an error view for the given error.
    /// - Parameter completion: A closure wich gets `Media.URL<Video>` on `success` or `Error` on `failure`.
    ///
    /// - Returns: some View
    @ViewBuilder static func camera<ErrorView: View>(@ViewBuilder errorView: (Swift.Error) -> ErrorView, _ completion: @escaping ResultMediaURLVideoCompletion) -> some View {
        let result = Result {
            try ViewCreator.camera(for: [.movie]) { result in
                switch result {
                case .success(let cameraResult):
                    switch cameraResult {
                    case .tookVideo(let url):
                        do {
                            let mediaURL = try Media.URL<Video>(url: url)
                            completion(.success(mediaURL))
                        } catch {
                            completion(.failure(error))
                        }
                    default:
                        completion(.failure(Video.Error.unsupportedCameraResult))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
        switch result {
        case let .success(view):
            view
        case let .failure(error):
            errorView(error)
        }
    }

    /// Creates a ready-to-use `SwiftUI` view for browsing `Video`s in the photo library
    /// If an error occurs during initialization a `SwiftUI.Text` with the `localizedDescription` is shown.
    ///
    /// - Parameter selectionLimit: Specifies the number of items which can be selected. Works only on iOS 14 and macOS 11 where the `PHPicker` is used under the hood. Defaults to `1`.
    /// - Parameter completion: A closure wich gets `Video` on `success` or `Error` on `failure`.
    ///
    /// - Returns: some View
    static func browser(selectionLimit: Int = 1, _ completion: @escaping ResultVideosCompletion) -> some View {
        browser(errorView: { error in Text(error.localizedDescription) }, completion)
    }

    /// Creates a ready-to-use `SwiftUI` view for browsing `Video`s in the photo library
    /// If an error occurs during initialization the provided `errorView` closure is used to construct the view to be displayed.
    ///
    /// - Parameter selectionLimit: Specifies the number of items which can be selected. Works only on iOS 14 and macOS 11 where the `PHPicker` is used under the hood. Defaults to `1`.
    /// - Parameter errorView: A closure that constructs an error view for the given error.
    /// - Parameter completion: A closure wich gets `Video` on `success` or `Error` on `failure`.
    ///
    /// - Returns: some View
    @ViewBuilder static func browser<ErrorView: View>(selectionLimit: Int = 1, @ViewBuilder errorView: (Swift.Error) -> ErrorView, _ completion: @escaping ResultVideosCompletion) -> some View {
        if #available(iOS 14, macOS 11, *) {
            PHPicker(configuration: {
                var configuration = PHPickerConfiguration()
                configuration.filter = .videos
                configuration.selectionLimit = selectionLimit
                return configuration
            }()) { result in
                switch result {
                case let .success(result):
                    let result = Result {
                        try result.compactMap { object -> Video? in
                            guard let assetIdentifier = object.assetIdentifier else {
                                return nil
                            }
                            return try Video.with(identifier: .init(stringLiteral: assetIdentifier))
                        }
                    }
                    completion(result)
                case let .failure(error): ()
                    completion(.failure(error))
                }
            }
        } else {
            let result = Result {
                try ViewCreator.browser(mediaTypes: [.movie]) { (result: Result<Video, Swift.Error>) in
                    switch result {
                    case let .success(video):
                        completion(.success([video]))
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            }
            switch result {
            case let .success(view):
                view
            case let .failure(error):
                errorView(error)
            }
        }
    }
}
#endif

#endif
