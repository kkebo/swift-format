//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import _FoundationCShims

#if os(WASI)
extension FileManager {
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
  /// Thread-unsafe directory enumerator.
  class NSURLDirectoryEnumerator: DirectoryEnumerator {
    private(set) var dpStack = [(URL, OpaquePointer)]()
    var url: URL
    var options: FileManager.DirectoryEnumerationOptions
    var errorHandler: ((URL, any Error) -> Bool)?
    var rootError: (any Error)? = nil

    init(
      url: URL,
      options: FileManager.DirectoryEnumerationOptions,
      errorHandler: ( /* @escaping */(URL, Error) -> Bool)?
    ) {
      self.url = url
      self.options = options
      self.errorHandler = errorHandler
      super.init()

      self.appendDirectoryPointer(of: url)
    }

    deinit {
      while let (_, dp) = dpStack.popLast() {
        closedir(dp)
      }
    }

    private func appendDirectoryPointer(of url: URL) {
      let fm = FileManager.default
      do {
        guard fm.fileExists(atPath: url.path) else { throw _NSErrorWithErrno(ENOENT, reading: true, url: url) }
        guard let dp = fm.withFileSystemRepresentation(for: url.path, opendir) else {
          throw _NSErrorWithErrno(errno, reading: true, url: url)
        }
        dpStack.append((url, dp))
      } catch {
        rootError = error
      }
    }

    override func nextObject() -> Any? {
      func match(filename: String, to options: DirectoryEnumerationOptions, isDir: Bool) -> (Bool, Bool) {
        var showFile = true
        var skipDescendants = false

        if isDir {
          if options.contains(.skipsSubdirectoryDescendants) {
            skipDescendants = true
          }
          // Ignore .skipsPackageDescendants
        }
        if options.contains(.skipsHiddenFiles) && filename.hasPrefix(".") {
          showFile = false
          skipDescendants = true
        }

        return (showFile, skipDescendants)
      }

      while let (url, dp) = dpStack.last {
        while let ep = readdir(dp) {
          guard ep.pointee.d_ino != 0 else { continue }
          let filename = String(cString: _platform_shims_dirent_d_name(ep))
          guard filename != "." && filename != ".." else { continue }
          let child = url.appendingPathComponent(filename)
          var isDirectory = false
          if ep.pointee.d_type == _platform_shims_DT_DIR() {
            isDirectory = true
          } else if ep.pointee.d_type == _platform_shims_DT_UNKNOWN() {
            var status = stat()
            if stat(child.path, &status) == 0, (status.st_mode & S_IFMT) == S_IFDIR {
              isDirectory = true
            }
          }
          if isDirectory {
            let (showFile, skipDescendants) = match(filename: filename, to: options, isDir: true)
            if !skipDescendants {
              appendDirectoryPointer(of: child)
            }
            if showFile {
              return child
            }
          } else {
            let (showFile, _) = match(filename: filename, to: options, isDir: false)
            if showFile {
              return child
            }
          }
        }
        closedir(dp)
        dpStack.removeLast()
      }
      if let error = rootError, let handler = errorHandler {
        let _ = handler(url, error)
      }
      return nil
    }
  }
}

func _NSErrorWithErrno(
  _ posixErrno: Int32,
  reading: Bool,
  path: String? = nil,
  url: URL? = nil,
  extraUserInfo: [String: Any]? = nil
) -> NSError {
  var cocoaError: CocoaError.Code
  if reading {
    switch posixErrno {
    case EFBIG: cocoaError = .fileReadTooLarge
    case ENOENT: cocoaError = .fileReadNoSuchFile
    case EPERM, EACCES: cocoaError = .fileReadNoPermission
    case ENAMETOOLONG: cocoaError = .fileReadUnknown
    default: cocoaError = .fileReadUnknown
    }
  } else {
    switch posixErrno {
    case ENOENT: cocoaError = .fileNoSuchFile
    case EPERM, EACCES: cocoaError = .fileWriteNoPermission
    case ENAMETOOLONG: cocoaError = .fileWriteInvalidFileName
    case EDQUOT, ENOSPC: cocoaError = .fileWriteOutOfSpace
    case EROFS: cocoaError = .fileWriteVolumeReadOnly
    case EEXIST: cocoaError = .fileWriteFileExists
    default: cocoaError = .fileWriteUnknown
    }
  }

  var userInfo = extraUserInfo ?? [String: Any]()
  if let path = path {
    userInfo[NSFilePathErrorKey] = path
  } else if let url = url {
    userInfo[NSURLErrorKey] = url
  }

  userInfo[NSUnderlyingErrorKey] = NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno))

  return NSError(domain: NSCocoaErrorDomain, code: cocoaError.rawValue, userInfo: userInfo)
}
#endif
