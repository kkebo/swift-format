//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

internal func _NSErrorWithErrno(
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
    #if os(Windows)
    case ENOSPC: cocoaError = .fileWriteOutOfSpace
    #else
    case EDQUOT, ENOSPC: cocoaError = .fileWriteOutOfSpace
    #endif
    case EROFS: cocoaError = .fileWriteVolumeReadOnly
    case EEXIST: cocoaError = .fileWriteFileExists
    default: cocoaError = .fileWriteUnknown
    }
  }

  var userInfo = extraUserInfo ?? [String: Any]()
  if let path = path {
    // userInfo[NSFilePathErrorKey] = path._nsObject
    userInfo[NSFilePathErrorKey] = path
  } else if let url = url {
    userInfo[NSURLErrorKey] = url
  }

  userInfo[NSUnderlyingErrorKey] = NSError(domain: NSPOSIXErrorDomain, code: Int(posixErrno))

  return NSError(domain: NSCocoaErrorDomain, code: cocoaError.rawValue, userInfo: userInfo)
}
