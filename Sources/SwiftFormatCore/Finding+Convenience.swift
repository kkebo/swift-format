//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftSyntax

extension Finding.Location {
  /// Creates a new `Finding.Location` by converting the given `SourceLocation` from `SwiftSyntax`.
  public init(_ sourceLocation: SourceLocation) {
    self.init(file: sourceLocation.file, line: sourceLocation.line, column: sourceLocation.column)
  }
}
