//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if os(Windows)
let validPathSeps: [Character] = ["\\", "/"]
#else
let validPathSeps: [Character] = ["/"]
#endif

extension String {
  internal var _startOfLastPathComponent: String.Index {
    precondition(!validPathSeps.contains(where: { hasSuffix(String($0)) }) && length > 1)

    let startPos = startIndex
    var curPos = endIndex

    // Find the beginning of the component
    while curPos > startPos {
      let prevPos = index(before: curPos)
      if validPathSeps.contains(self[prevPos]) {
        break
      }
      curPos = prevPos
    }
    return curPos
  }
}
