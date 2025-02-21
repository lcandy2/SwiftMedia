//
//  Photo.swift
//  MediaCore
//
//  Created by Christian Elies on 21.11.19.
//  Copyright © 2019 Christian Elies. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import Photos

/// Convenience wrapper for `PHAsset`s
/// with the type `image` which represents
/// a photo
///
public struct Photo: MediaProtocol {
    static var imageManager: ImageManager = PHImageManager.default()

    private var phAsset: PHAsset? { phAssetWrapper.value }

    public typealias MediaSubtype = Photo.Subtype
    public typealias MediaFileType = Photo.FileType

    /// Box type for storing a reference to the
    /// underlying `PHAsset`
    ///
    /// Only used internally
    ///
    public let phAssetWrapper: PHAssetWrapper

    /// `PHAssetMediaType` represented by a `Photo`
    ///
    public static let type: MediaType = .image

    /// Locally available metadata of the `Photo`
    public var metadata: Metadata? {
        guard let phAsset = phAsset else { return nil }
        return Metadata(
            type: phAsset.mediaType,
            subtypes: phAsset.mediaSubtypes,
            sourceType: phAsset.sourceType,
            creationDate: phAsset.creationDate,
            modificationDate: phAsset.modificationDate,
            location: phAsset.location,
            isFavorite: phAsset.isFavorite,
            isHidden: phAsset.isHidden,
            pixelWidth: phAsset.pixelWidth,
            pixelHeight: phAsset.pixelHeight)
    }

    /// Initializes a photo using the given `PHAsset` instance
    ///
    /// - Parameter phAsset: a `PHAsset` instance with the type `image`
    ///
    public init(phAsset: PHAsset) {
        phAssetWrapper = PHAssetWrapper(value: phAsset)
    }
}

extension Photo: Equatable {
    public static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.identifier == rhs.identifier && lhs.phAsset == rhs.phAsset
    }
}

extension Photo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(phAsset)
    }
}

public extension Photo {
    /// Subtypes of the receiver
    /// Similar to tags, like `hdr`, `panorama` or `screenshot`
    ///
    var subtypes: [Photo.Subtype] {
        guard let phAsset = phAsset else { return [] }

        var types: [Photo.Subtype] = []

        if #available(iOS 10.2, macOS 10.15, tvOS 10.1, *) {
            switch phAsset.mediaSubtypes {
            case [.photoDepthEffect, .photoScreenshot, .photoHDR, .photoPanorama]:
                types.append(contentsOf: [.depthEffect, .screenshot, .hdr, .panorama])

            case [.photoDepthEffect, .photoScreenshot, .photoHDR]:
                types.append(contentsOf: [.depthEffect, .screenshot, .hdr])

            case [.photoDepthEffect, .photoScreenshot]:
                types.append(contentsOf: [.depthEffect, .screenshot])
            case [.photoDepthEffect, .photoHDR]:
                types.append(contentsOf: [.depthEffect, .hdr])
            case [.photoDepthEffect, .photoPanorama]:
                types.append(contentsOf: [.depthEffect, .panorama])
            case [.photoScreenshot, .photoHDR]:
                types.append(contentsOf: [.screenshot, .hdr])
            case [.photoScreenshot, .photoPanorama]:
                types.append(contentsOf: [.screenshot, .panorama])
            case [.photoHDR, .photoPanorama]:
                types.append(contentsOf: [.hdr, .panorama])

            case [.photoDepthEffect]:
                types.append(.depthEffect)
            case [.photoScreenshot]:
                types.append(.screenshot)
            case [.photoHDR]:
                types.append(.hdr)
            case [.photoPanorama]:
                types.append(.panorama)
            default: ()
            }
        } else {
            switch phAsset.mediaSubtypes {
            case [.photoScreenshot, .photoHDR, .photoPanorama]:
                types.append(contentsOf: [.screenshot, .hdr, .panorama])

            case [.photoScreenshot, .photoHDR]:
                types.append(contentsOf: [.screenshot, .hdr])
            case [.photoScreenshot, .photoPanorama]:
                types.append(contentsOf: [.screenshot, .panorama])
            case [.photoHDR, .photoPanorama]:
                types.append(contentsOf: [.hdr, .panorama])

            case [.photoScreenshot]:
                types.append(.screenshot)
            case [.photoHDR]:
                types.append(.hdr)
            case [.photoPanorama]:
                types.append(.panorama)
            default: ()
            }
        }

        return types
    }
}

#if canImport(UIKit)
public extension Photo {
    typealias ResultPhotoPropertiesCompletion = (Result<Properties, Swift.Error>) -> Void

    /// Get `EXIF`, `GPS` and `TIFF` information of the `Photo`
    /// Keep in mind that this method might download a full size copy
    /// of the `Photo` from the cloud to get the information
    ///
    /// - Parameter completion: `Result` containing a `Properties` object on `success` or an error on `failure`
    ///
    func properties(_ completion: @escaping ResultPhotoPropertiesCompletion) {
        guard let phAsset = phAsset else {
            completion(.failure(Media.Error.noUnderlyingPHAssetFound))
            return
        }

        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true

        phAsset.requestContentEditingInput(with: options) { contentEditingInput, _ in
            guard let fullSizeImageURL = contentEditingInput?.fullSizeImageURL else {
                completion(.failure(Error.missingFullSizeImageURL))
                return
            }

            guard let fullImage = CIImage(contentsOf: fullSizeImageURL) else {
                completion(.failure(Error.couldNotCreateCIImage))
                return
            }

            let properties = Properties(dictionary: fullImage.properties)
            completion(.success(properties))
        }
    }
}
#endif

public extension Photo {
    /// Data representation of the receiver
    ///
    /// - Parameter completion: a closure which gets a `Result` (`Data` on `success` or `Error` on `failure`)
    ///
    func data(_ completion: @escaping ResultDataCompletion) {
        guard let phAsset = phAsset else {
            completion(.failure(Media.Error.noUnderlyingPHAssetFound))
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true

        if #available(iOS 13, macOS 10.15, tvOS 13, *) {
            Self.imageManager.requestImageDataAndOrientation(for: phAsset, options: options, resultHandler: { data, _, _, info in
                PHImageManager.handleResult(result: (data, info), completion)
            })
        } else {
            // Fallback on earlier versions
            phAsset.requestContentEditingInput(with: nil) { contentEditingInput, _ in
                guard let fullSizeImageURL = contentEditingInput?.fullSizeImageURL else {
                    completion(.failure(Error.missingFullSizeImageURL))
                    return
                }

                do {
                    let data = try Data(contentsOf: fullSizeImageURL)
                    completion(.success(data))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
}

#if canImport(UIKit)
public extension Photo {
    typealias UIImageCompletion = (Result<Media.DisplayRepresentation<UIImage>, Swift.Error>) -> Void

    /// `UIImage` representation of the receiver
    ///
    /// - Parameters:
    ///   - targetSize: defines the desired size (width and height)
    ///   - contentMode: specifies the desired content mode
    ///   - completion: a closure which gets a `Result` (`UIImage` on `success` or `Error` on `failure`)
    ///
    func uiImage(targetSize: CGSize,
                 contentMode: PHImageContentMode,
                 _ completion: @escaping UIImageCompletion) {
        guard let phAsset = phAsset else {
            completion(.failure(Media.Error.noUnderlyingPHAssetFound))
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true

        Self.imageManager.requestImage(for: phAsset,
                                       targetSize: targetSize,
                                       contentMode: contentMode,
                                       options: options)
        { image, info in
            PHImageManager.handlePotentialDegradedResult((image, info), completion)
        }
    }
}
#endif

public extension Photo {
    /// Saves the photo media at the given `URL` if
    /// - the access to the photo library is allowed
    /// - the path extension of the URL is a valid `Photo.FileType` path extension
    ///
    /// - Parameters:
    ///   - url: the URL to the media object
    ///   - completion: a closure which gets a `Result` (`Photo` on `success` or `Error` on `failure`)
    ///
    @available(iOS 11, macOS 10.15, tvOS 11, *)
    static func save(_ mediaURL: Media.URL<Self>, _ completion: @escaping ResultPhotoCompletion) {
        PHAssetChanger.createRequest({ assetChangeRequest.creationRequestForAssetFromImage(atFileURL: mediaURL.value) },
                                     completion)
    }

    /// Saves the given `UIImage` / `NSImage` if the access to the photo library is allowed
    ///
    /// - Parameters:
    ///   - image: the `UIImage` which should be saved
    ///   - completion: a closure which gets a `Result` (`Photo` on `success` or `Error` on `failure`)
    ///
    static func save(_ image: UniversalImage, completion: @escaping ResultPhotoCompletion) {
        PHAssetChanger.createRequest({ assetChangeRequest.creationRequestForAsset(from: image) },
                                     completion)
    }

    /// Updates the `favorite` state of the receiver
    ///
    /// - Parameters:
    ///   - favorite: a boolean indicating the new `favorite` state
    ///   - completion: a closure which gets a `Result` (`Void` on `success` or `Error` on `failure`)
    ///
    func favorite(_ favorite: Bool, _ completion: @escaping ResultVoidCompletion) {
        guard let phAsset = phAsset else {
            completion(.failure(Media.Error.noUnderlyingPHAssetFound))
            return
        }

        PHAssetChanger.favorite(phAsset: phAsset, favorite: favorite) { result in
            do {
                self.phAssetWrapper.value = try result.get()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Fetches the `Photo` with the given identifier if it exists
    ///
    /// /// Alternative:
    /// @FetchAsset(filter: [.localIdentifier("1234")])
    /// private var photo: Photo?
    ///
    /// - Parameter identifier: the identifier of the media
    ///
    static func with(identifier: Media.Identifier<Self>) throws -> Photo? {
        let options = PHFetchOptions()
        let mediaTypeFilter: Media.Filter<Photo.Subtype> = .localIdentifier(identifier.localIdentifier)
        let predicate = NSPredicate(format: "mediaType = %d", MediaType.image.rawValue)
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, mediaTypeFilter.predicate])

        let photo = try PHAssetFetcher.fetchAsset(options: options) { $0.localIdentifier == identifier.localIdentifier && $0.mediaType == .image } as Photo?
        return photo
    }
}

// by lcandy2

public extension Photo {
    func toLivePhoto() -> LivePhoto? {
        guard let phAsset = phAsset, phAsset.mediaSubtypes.contains(.photoLive) else {
            return nil
        }
        return LivePhoto(phAsset: phAsset)
    }
}

