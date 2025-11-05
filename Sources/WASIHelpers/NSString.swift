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

extension String {
  // this is only valid for the usage for CF since it expects the length to be in unicode characters instead of grapheme clusters "✌🏾".utf16.count = 3 and CFStringGetLength(CFSTR("✌🏾")) = 3 not 1 as it would be represented with grapheme clusters
  internal var length: Int {
    return utf16.count
  }
}
