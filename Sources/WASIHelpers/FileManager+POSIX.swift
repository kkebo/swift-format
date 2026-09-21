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
#if !os(Windows)

import Foundation
import _FoundationCShims

extension FileManager {
  internal class NSURLDirectoryEnumerator: DirectoryEnumerator {
    var _url: URL
    var _options: FileManager.DirectoryEnumerationOptions
    var _errorHandler: ((URL, Error) -> Bool)?
    var _stream: UnsafeMutablePointer<FTS>? = nil
    var _current: UnsafeMutablePointer<FTSENT>? = nil
    var _rootError: Error? = nil
    var _gotRoot: Bool = false

    // See @escaping comments above.
    init(
      url: URL,
      options: FileManager.DirectoryEnumerationOptions,
      errorHandler: ( /* @escaping */(URL, Error) -> Bool)?
    ) {
      _url = url
      _options = options
      _errorHandler = errorHandler

      let fm = FileManager.default
      do {
        guard fm.fileExists(atPath: _url.path) else { throw _NSErrorWithErrno(ENOENT, reading: true, url: url) }
        _stream = FileManager.default.withFileSystemRepresentation(for: _url.path) { fsRep in
          let ps = UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>.allocate(capacity: 2)
          defer { ps.deallocate() }
          ps.initialize(to: UnsafeMutablePointer(mutating: fsRep))
          ps.advanced(by: 1).initialize(to: nil)
          return fts_open(ps, FTS_PHYSICAL | FTS_XDEV | FTS_NOCHDIR | FTS_NOSTAT, nil)
        }
        if _stream == nil {
          throw _NSErrorWithErrno(errno, reading: true, url: url)
        }
      } catch {
        _rootError = error
      }
    }

    deinit {
      if let stream = _stream {
        fts_close(stream)
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
        if options.contains(.skipsHiddenFiles) && (filename[filename._startOfLastPathComponent] == ".") {
          showFile = false
          skipDescendants = true
        }

        return (showFile, skipDescendants)
      }

      if let stream = _stream {

        if !_gotRoot {
          _gotRoot = true

          // Skip the root.
          _current = fts_read(stream)
        }

        _current = fts_read(stream)
        while let current = _current {
          let filename = FileManager.default.string(
            withFileSystemRepresentation: current.pointee.fts_path!,
            length: Int(current.pointee.fts_pathlen)
          )

          switch Int32(current.pointee.fts_info) {
          case FTS_D:
            let (showFile, skipDescendants) = match(filename: filename, to: _options, isDir: true)
            if skipDescendants {
              fts_set(stream, current, FTS_SKIP)
            }
            if showFile {
              return URL(fileURLWithPath: filename, isDirectory: true)
            }

          case FTS_DEFAULT, FTS_F, FTS_NSOK, FTS_SL, FTS_SLNONE:
            let (showFile, _) = match(filename: filename, to: _options, isDir: false)
            if showFile {
              return URL(fileURLWithPath: filename, isDirectory: false)
            }
          case FTS_DNR, FTS_ERR, FTS_NS:
            let keepGoing: Bool
            if let handler = _errorHandler {
              keepGoing = handler(
                URL(fileURLWithPath: filename),
                _NSErrorWithErrno(current.pointee.fts_errno, reading: true)
              )
            } else {
              keepGoing = true
            }
            if !keepGoing {
              fts_close(stream)
              _stream = nil
              return nil
            }
          default:
            break
          }
          _current = fts_read(stream)
        }
        // TODO: Error handling if fts_read fails.
      } else if let error = _rootError {
        // Was there an error opening the stream?
        if let handler = _errorHandler {
          let _ = handler(_url, error)
        }
      }
      return nil
    }

    override var level: Int {
      return Int(_current?.pointee.fts_level ?? 0)
    }

    override func skipDescendants() {
      if let stream = _stream, let current = _current {
        fts_set(stream, current, FTS_SKIP)
      }
    }

    override var directoryAttributes: [FileAttributeKey: Any]? {
      return nil
    }

    override var fileAttributes: [FileAttributeKey: Any]? {
      return nil
    }
  }
}

extension FileManager.NSPathDirectoryEnumerator {
  internal func _nextObject() -> Any? {
    let o = innerEnumerator.nextObject()
    guard let url = o as? URL else {
      return nil
    }

    let path = url.path.replacingOccurrences(of: baseURL.path + "/", with: "")
    _currentItemPath = path
    return _currentItemPath
  }
}

#endif
