//
//  FetchAlbum.swift
//  
//
//  Created by Christian Elies on 04.12.19.
//

import Photos

/// Property wrapper for fetching a single album
///
// TODO: osx 10.13
@available(macOS 10.15, *)
@propertyWrapper
public struct FetchAlbum {
    private let options = PHFetchOptions().fetchLimit(1)

    public var wrappedValue: Album? {
        AlbumFetcher.fetchAlbum(with: .album, subtype: .any, options: options)
    }

    /// Initializes the property wrapper using the given predicate
    /// as the fetch options
    ///
    /// - Parameter filter: a set of `AlbumFilter` to use for the fetch
    ///
    public init(filter: Set<Album.Filter> = []) {
        if !filter.isEmpty {
            let predicates = filter.map { $0.predicate }
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
}
