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

import SwiftFormat

final class BinaryOperatorExprTests: PrettyPrintTestCase {
  func testNonRangeFormationOperatorsAreSurroundedByBreaks() {
    let input =
      """
      x=1+8-9  ^*^  5*4/10
      """

    let expected80 =
      """
      x = 1 + 8 - 9 ^*^ 5 * 4 / 10

      """

    assertPrettyPrintEqual(input: input, expected: expected80, linelength: 80)

    let expected10 =
      """
      x =
        1 + 8
        - 9
        ^*^ 5
        * 4 / 10

      """

    assertPrettyPrintEqual(input: input, expected: expected10, linelength: 10)
  }

  func testRangeFormationOperatorCompaction_noSpacesAroundRangeFormation() {
    let input =
      """
      x = 1...100
      x = 1..<100
      x = (1++)...(-100)
      x = 1 ... 100
      x = 1 ..< 100
      x = (1++) ... (-100)
      """

    let expected =
      """
      x = 1...100
      x = 1..<100
      x = (1++)...(-100)
      x = 1...100
      x = 1..<100
      x = (1++)...(-100)

      """

    var configuration = Configuration.forTesting
    configuration.spacesAroundRangeFormationOperators = false
    assertPrettyPrintEqual(
      input: input,
      expected: expected,
      linelength: 80,
      configuration: configuration
    )
  }

  func testRangeFormationOperatorCompaction_spacesAroundRangeFormation() {
    let input =
      """
      x = 1...100
      x = 1..<100
      x = (1++)...(-100)
      x = 1 ... 100
      x = 1 ..< 100
      x = (1++) ... (-100)
      """

    let expected =
      """
      x = 1 ... 100
      x = 1 ..< 100
      x = (1++) ... (-100)
      x = 1 ... 100
      x = 1 ..< 100
      x = (1++) ... (-100)

      """

    var configuration = Configuration.forTesting
    configuration.spacesAroundRangeFormationOperators = true
    assertPrettyPrintEqual(
      input: input,
      expected: expected,
      linelength: 80,
      configuration: configuration
    )
  }

  func testRangeFormationOperatorsAreNotCompactedWhenFollowingAPostfixOperator() {
    let input =
      """
      x = 1++ ... 100
      x = 1-- ..< 100
      x = 1++   ...   100
      x = 1--   ..<   100
      """

    let expected80 =
      """
      x = 1++ ... 100
      x = 1-- ..< 100
      x = 1++ ... 100
      x = 1-- ..< 100

      """

    assertPrettyPrintEqual(input: input, expected: expected80, linelength: 80)

    let expected10 =
      """
      x =
        1++
        ... 100
      x =
        1--
        ..< 100
      x =
        1++
        ... 100
      x =
        1--
        ..< 100

      """

    assertPrettyPrintEqual(input: input, expected: expected10, linelength: 10)
  }

  func testRangeFormationOperatorsAreNotCompactedWhenPrecedingAPrefixOperator() {
    let input =
      """
      x = 1 ... -100
      x = 1 ..< -100
      x = 1   ...   √100
      x = 1   ..<   √100
      """

    let expected80 =
      """
      x = 1 ... -100
      x = 1 ..< -100
      x = 1 ... √100
      x = 1 ..< √100

      """

    assertPrettyPrintEqual(input: input, expected: expected80, linelength: 80)

    let expected10 =
      """
      x =
        1
        ... -100
      x =
        1
        ..< -100
      x =
        1
        ... √100
      x =
        1
        ..< √100

      """

    assertPrettyPrintEqual(input: input, expected: expected10, linelength: 10)
  }

  func testRangeFormationOperatorsAreNotCompactedWhenUnaryOperatorsAreOnEachSide() {
    let input =
      """
      x = 1++ ... -100
      x = 1-- ..< -100
      x = 1++   ...   √100
      x = 1--   ..<   √100
      """

    let expected80 =
      """
      x = 1++ ... -100
      x = 1-- ..< -100
      x = 1++ ... √100
      x = 1-- ..< √100

      """

    assertPrettyPrintEqual(input: input, expected: expected80, linelength: 80)

    let expected10 =
      """
      x =
        1++
        ... -100
      x =
        1--
        ..< -100
      x =
        1++
        ... √100
      x =
        1--
        ..< √100

      """

    assertPrettyPrintEqual(input: input, expected: expected10, linelength: 10)
  }

  func testRangeFormationOperatorsAreNotCompactedWhenPrecedingPrefixDot() {
    let input =
      """
      x = .first   ...   .last
      x = .first   ..<   .last
      x = .first   ...   .last
      x = .first   ..<   .last
      """

    let expected80 =
      """
      x = .first ... .last
      x = .first ..< .last
      x = .first ... .last
      x = .first ..< .last

      """

    assertPrettyPrintEqual(input: input, expected: expected80, linelength: 80)

    let expected10 =
      """
      x =
        .first
        ... .last
      x =
        .first
        ..< .last
      x =
        .first
        ... .last
      x =
        .first
        ..< .last

      """

    assertPrettyPrintEqual(input: input, expected: expected10, linelength: 10)
  }
}
