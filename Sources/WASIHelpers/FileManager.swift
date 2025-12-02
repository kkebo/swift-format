//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

extension FileManager {
  /* enumeratorAtPath: returns an NSDirectoryEnumerator rooted at the provided path. If the enumerator cannot be created, this returns NULL. Because NSDirectoryEnumerator is a subclass of NSEnumerator, the returned object can be used in the for...in construct.
   */
  public func enumeratorWASI(atPath path: String) -> DirectoryEnumerator? {
    NSPathDirectoryEnumerator(path: path)
  }

  /* enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: returns an NSDirectoryEnumerator rooted at the provided directory URL. The NSDirectoryEnumerator returns NSURLs from the -nextObject method. The optional 'includingPropertiesForKeys' parameter indicates which resource properties should be pre-fetched and cached with each enumerated URL. The optional 'errorHandler' block argument is invoked when an error occurs. Parameters to the block are the URL on which an error occurred and the error. When the error handler returns YES, enumeration continues if possible. Enumeration stops immediately when the error handler returns NO.

    If you wish to only receive the URLs and no other attributes, then pass '0' for 'options' and an empty NSArray ('[NSArray array]') for 'keys'. If you wish to have the property caches of the vended URLs pre-populated with a default set of attributes, then pass '0' for 'options' and 'nil' for 'keys'.
   */
  // Note: Because the error handler is an optional block, the compiler treats it as @escaping by default. If that behavior changes, the @escaping will need to be added back.
  public func enumeratorWASI(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options mask: FileManager.DirectoryEnumerationOptions = [],
    errorHandler handler: ( /* @escaping */(URL, Error) -> Bool)? = nil
  ) -> DirectoryEnumerator? {
    NSURLDirectoryEnumerator(url: url, options: mask, errorHandler: handler)
  }
}

extension FileManager {
  internal class NSPathDirectoryEnumerator: DirectoryEnumerator {
    let baseURL: URL
    let innerEnumerator: DirectoryEnumerator
    internal var _currentItemPath: String?

    override var fileAttributes: [FileAttributeKey: Any]? {
      guard let currentItemPath = _currentItemPath else {
        return nil
      }
      return try? FileManager.default.attributesOfItem(atPath: baseURL.appendingPathComponent(currentItemPath).path)
    }

    override var directoryAttributes: [FileAttributeKey: Any]? {
      return try? FileManager.default.attributesOfItem(atPath: baseURL.path)
    }

    override var level: Int {
      return innerEnumerator.level
    }

    override func skipDescendants() {
      innerEnumerator.skipDescendants()
    }

    init?(path: String) {
      guard path != "" else { return nil }
      let url = URL(fileURLWithPath: path)
      self.baseURL = url
      guard
        let ie = FileManager.default.enumeratorWASI(
          at: url,
          includingPropertiesForKeys: nil,
          options: [],
          errorHandler: nil
        )
      else {
        return nil
      }
      self.innerEnumerator = ie
    }

    override func nextObject() -> Any? {
      return _nextObject()
    }
  }
}
