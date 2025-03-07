//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@_spi(Rules) import SwiftFormat
import _SwiftFormatTestSupport

// FIXME: Diagnostics should be emitted inside the comment, not at the beginning of the declaration.
final class ValidateDocumentationCommentsTests: LintOrFormatRuleTestCase {
  func testParameterDocumentation() {
    assertLint(
      ValidateDocumentationComments.self,
      """
      /// Uses 'Parameters' when it only has one parameter.
      ///
      /// - Parameters:
      ///   - singular: singular description.
      /// - Returns: A string containing the contents of a
      ///   description
      1️⃣func testPluralParamDesc(singular: String) -> Bool {}

      /// Returns the output generated by executing a command with the given string
      /// used as standard input.
      ///
      /// - Parameter command: The command to execute in the shell environment.
      /// - Parameter stdin: The string to use as standard input.
      /// - Returns: A string containing the contents of the invoked process's
      ///   standard output.
      2️⃣func testInvalidParameterDesc(command: String, stdin: String) -> String {}
      """,
      findings: [
        FindingSpec(
          "1️⃣",
          message: "replace the plural 'Parameters:' section with a singular inline 'Parameter' section"
        ),
        FindingSpec(
          "2️⃣",
          message:
            "replace the singular inline 'Parameter' section with a plural 'Parameters:' section that has the parameters nested inside it"
        ),
      ]
    )
  }

  func testParametersName() {
    assertLint(
      ValidateDocumentationComments.self,
      """
      /// Parameters dont match.
      ///
      /// - Parameters:
      ///   - sum: The sum of all numbers.
      ///   - avg: The average of all numbers.
      /// - Returns: The sum of sum and avg.
      1️⃣func sum(avg: Int, sum: Int) -> Int {}

      /// Missing one parameter documentation.
      ///
      /// - Parameters:
      ///   - p1: Parameter 1.
      ///   - p2: Parameter 2.
      /// - Returns: an integer.
      2️⃣func foo(p1: Int, p2: Int, p3: Int) -> Int {}
      """,
      findings: [
        FindingSpec("1️⃣", message: "change the parameters of the documentation of 'sum' to match its parameters"),
        FindingSpec("2️⃣", message: "change the parameters of the documentation of 'foo' to match its parameters"),
      ]
    )
  }

  func testThrowsDocumentation() {
    assertLint(
      ValidateDocumentationComments.self,
      """
      /// One sentence summary.
      ///
      /// - Parameters:
      ///   - p1: Parameter 1.
      ///   - p2: Parameter 2.
      ///   - p3: Parameter 3.
      /// - Throws: an error.
      1️⃣func doesNotThrow(p1: Int, p2: Int, p3: Int) {}

      /// One sentence summary.
      ///
      /// - Parameters:
      ///   - p1: Parameter 1.
      ///   - p2: Parameter 2.
      ///   - p3: Parameter 3.
      func doesThrow(p1: Int, p2: Int, p3: Int) 2️⃣throws {}

      /// One sentence summary.
      ///
      /// - Parameter p1: Parameter 1.
      /// - Throws: doesn't really throw, just rethrows
      func doesRethrow(p1: (() throws -> ())) 3️⃣rethrows {}
      """,
      findings: [
        FindingSpec("1️⃣", message: "remove the 'Throws:' sections of 'doesNotThrow'; it does not throw any errors"),
        FindingSpec("2️⃣", message: "add a 'Throws:' section to document the errors thrown by 'doesThrow'"),
      ]
    )
  }

  func testReturnDocumentation() {
    assertLint(
      ValidateDocumentationComments.self,
      """
      /// One sentence summary.
      ///
      /// - Parameters:
      ///   - p1: Parameter 1.
      ///   - p2: Parameter 2.
      ///   - p3: Parameter 3.
      /// - Returns: an integer.
      1️⃣func noReturn(p1: Int, p2: Int, p3: Int) {}

      /// One sentence summary.
      ///
      /// - Parameters:
      ///   - p1: Parameter 1.
      ///   - p2: Parameter 2.
      ///   - p3: Parameter 3.
      func foo(p1: Int, p2: Int, p3: Int) 2️⃣-> Int {}

      /// One sentence summary.
      ///
      /// - Parameters:
      ///   - p1: Parameter 1.
      ///   - p2: Parameter 2.
      ///   - p3: Parameter 3.
      func neverReturns(p1: Int, p2: Int, p3: Int) -> Never {}

      /// One sentence summary.
      ///
      /// - Parameters:
      ///   - p1: Parameter 1.
      ///   - p2: Parameter 2.
      ///   - p3: Parameter 3.
      /// - Returns: Never returns.
      func documentedNeverReturns(p1: Int, p2: Int, p3: Int) -> Never {}
      """,
      findings: [
        FindingSpec("1️⃣", message: "remove the 'Returns:' section of 'noReturn'; it does not return a value"),
        FindingSpec("2️⃣", message: "add a 'Returns:' section to document the return value of 'foo'"),
      ]
    )
  }

  func testValidDocumentation() {
    assertLint(
      ValidateDocumentationComments.self,
      """
      /// Returns the output generated by executing a command.
      ///
      /// - Parameter command: The command to execute in the shell environment.
      /// - Returns: A string containing the contents of the invoked process's
      ///   standard output.
      func singularParam(command: String) -> String {
      // ...
      }

      /// Returns the output generated by executing a command with the given string
      /// used as standard input.
      ///
      /// - Parameters:
      ///   - command: The command to execute in the shell environment.
      ///   - stdin: The string to use as standard input.
      /// - Throws: An error, possibly.
      /// - Returns: A string containing the contents of the invoked process's
      ///   standard output.
      func pluralParam(command: String, stdin: String) throws -> String {
      // ...
      }

      /// One sentence summary.
      ///
      /// - Parameter p1: Parameter 1.
      func rethrower(p1: (() throws -> ())) rethrows {
      // ...
      }

      /// Parameter(s) and Returns tags may be omitted only if the single-sentence
      /// brief summary fully describes the meaning of those items and including the
      /// tags would only repeat what has already been said
      func omittedFunc(p1: Int)
      """,
      findings: []
    )
  }

  func testSeparateLabelAndIdentifier() {
    assertLint(
      ValidateDocumentationComments.self,
      """
      /// Returns the output generated by executing a command.
      ///
      /// - Parameter command: The command to execute in the shell environment.
      /// - Returns: A string containing the contents of the invoked process's
      ///   standard output.
      1️⃣func incorrectParam(label commando: String) -> String {
      // ...
      }

      /// Returns the output generated by executing a command.
      ///
      /// - Parameter command: The command to execute in the shell environment.
      /// - Returns: A string containing the contents of the invoked process's
      ///   standard output.
      func singularParam(label command: String) -> String {
      // ...
      }

      /// Returns the output generated by executing a command with the given string
      /// used as standard input.
      ///
      /// - Parameters:
      ///   - command: The command to execute in the shell environment.
      ///   - stdin: The string to use as standard input.
      /// - Returns: A string containing the contents of the invoked process's
      ///   standard output.
      func pluralParam(label command: String, label2 stdin: String) -> String {
      // ...
      }
      """,
      findings: [
        FindingSpec(
          "1️⃣",
          message: "change the parameters of the documentation of 'incorrectParam' to match its parameters"
        )
      ]
    )
  }

  func testInitializer() {
    assertLint(
      ValidateDocumentationComments.self,
      """
      struct SomeType {
        /// Brief summary.
        ///
        /// - Parameter command: The command to execute in the shell environment.
        /// - Returns: Shouldn't be here.
        1️⃣2️⃣init(label commando: String) {
        // ...
        }

        /// Brief summary.
        ///
        /// - Parameter command: The command to execute in the shell environment.
        init(label command: String) {
        // ...
        }

        /// Brief summary.
        ///
        /// - Parameters:
        ///   - command: The command to execute in the shell environment.
        ///   - stdin: The string to use as standard input.
        init(label command: String, label2 stdin: String) {
        // ...
        }

        /// Brief summary.
        ///
        /// - Parameters:
        ///   - command: The command to execute in the shell environment.
        ///   - stdin: The string to use as standard input.
        /// - Throws: An error.
        init(label command: String, label2 stdin: String) throws {
        // ...
        }
      }
      """,
      findings: [
        FindingSpec("1️⃣", message: "remove the 'Returns:' section of 'init'; it does not return a value"),
        FindingSpec("2️⃣", message: "change the parameters of the documentation of 'init' to match its parameters"),
      ]
    )
  }
}
