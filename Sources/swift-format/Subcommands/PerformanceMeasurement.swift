//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import _InstructionCounter

struct PerformanceMeasurementsOptions: ParsableArguments {
  @Flag(help: "Measure number of instructions executed by swift-format")
  var measureInstructions = false

  /// If `measureInstructions` is set, execute `body` and print the number of instructions
  /// executed by it. Otherwise, just execute `body`
  func printingInstructionCountIfRequested<T>(_ body: () throws -> T) rethrows -> T {
    if !measureInstructions {
      return try body()
    } else {
      let startInstructions = getInstructionsExecuted()
      defer {
        print("Instructions executed: \(getInstructionsExecuted() - startInstructions)")
      }
      return try body()
    }
  }
}
