final class StringTests: PrettyPrintTestCase {
  func testStrings() {
    let input =
      """
      let a = "abc"
      myFun("Some string \\(a + b)")
      let b = "A really long string that should not wrap"
      let c = "A really long string with \\(a + b) some expressions \\(c + d)"
      """

    let expected =
      """
      let a = "abc"
      myFun("Some string \\(a + b)")
      let b =
        "A really long string that should not wrap"
      let c =
        "A really long string with \\(a + b) some expressions \\(c + d)"

      """

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 35)
  }

  func testMultilineStringOpenQuotesDoNotWrapIfStringIsVeryLong() {
    let input =
      #"""
      let someString = """
        this string's total
        length will be longer
        than the column limit
        even though none of
        its individual lines
        are.
        """
      """#

    assertPrettyPrintEqual(input: input, expected: input + "\n", linelength: 30)
  }

  func testMultilineStringWithAssignmentOperatorInsteadOfPatternBinding() {
    let input =
      #"""
      someString = """
        this string's total
        length will be longer
        than the column limit
        even though none of
        its individual lines
        are.
        """
      """#

    assertPrettyPrintEqual(input: input, expected: input + "\n", linelength: 30)
  }

  func testMultilineStringUnlabeledArgumentIsReindentedCorrectly() {
    let input =
      #"""
      functionCall(longArgument, anotherLongArgument, """
            some multi-
              line string
            """)
      """#

    let expected =
      #"""
      functionCall(
        longArgument,
        anotherLongArgument,
        """
        some multi-
          line string
        """)

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 25)
  }

  func testMultilineStringLabeledArgumentIsReindentedCorrectly() {
    let input =
      #"""
      functionCall(longArgument: x, anotherLongArgument: y, longLabel: """
            some multi-
              line string
            """)
      """#

    let expected =
      #"""
      functionCall(
        longArgument: x,
        anotherLongArgument: y,
        longLabel: """
          some multi-
            line string
          """)

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 25)
  }

  func testMultilineStringInterpolations() {
    let input =
      #"""
      let x = """
        \(1) 2 3
        4 \(5) 6
        7 8 \(9)
        """
      """#

    assertPrettyPrintEqual(input: input, expected: input + "\n", linelength: 25)
  }

  func testMultilineRawString() {
    let input =
      ##"""
      let x = #"""
        """who would
        ever do this"""
        """#
      """##

    assertPrettyPrintEqual(input: input, expected: input + "\n", linelength: 25)
  }

  func testMultilineRawStringOpenQuotesWrap() {
    let input =
      #"""
      let aLongVariableName = """
        some
        multi-
        line
        string
        """
      """#

    let expected =
      #"""
      let aLongVariableName =
        """
        some
        multi-
        line
        string
        """

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 25)
  }

  func testMultilineStringAutocorrectMisalignedLines() {
    let input =
      #"""
      let x = """
          the
        second
          line is
          wrong
          """
      """#

    let expected =
      #"""
      let x = """
        the
        second
        line is
        wrong
        """

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 25)
  }

  func testMultilineStringKeepsBlankLines() {
    // This test not only ensures that the blank lines are retained in the first place, but that
    // the newlines are mandatory and not collapsed to the maximum number allowed by the formatter
    // configuration.
    let input =
      #"""
      let x = """


          there should be




          gaps all around here


          """
      """#

    let expected =
      #"""
      let x = """


        there should be




        gaps all around here


        """

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 25)
  }

  func testMultilineStringPreservesTrailingBackslashes() {
    let input =
      #"""
      let x = """
          there should be \
          backslashes at \
          the end of \
          every line \
          except this one
          """
      """#

    let expected =
      #"""
      let x = """
        there should be \
        backslashes at \
        the end of \
        every line \
        except this one
        """

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 20)
  }

  func testMultilineStringInParenthesizedExpression() {
    let input =
      #"""
      let x = ("""
          this is a
          multiline string
          """)
      """#

    let expected =
      #"""
      let x =
        ("""
        this is a
        multiline string
        """)

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 20)
  }

  func testMultilineStringAfterStatementKeyword() {
    let input =
      #"""
      return """
          this is a
          multiline string
          """
      return """
          this is a
          multiline string
          """ + "hello"
      """#

    let expected =
      #"""
      return """
        this is a
        multiline string
        """
      return """
        this is a
        multiline string
        """ + "hello"

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 20)
  }

  func testMultilineStringsInExpression() {
    // This output could probably be improved, but it's also a fairly unlikely occurrence. The
    // important part of this test is that the first string in the expression is indented relative
    // to the `let`.
    let input =
      #"""
      let x = """
          this is a
          multiline string
          """ + """
          this is more
          multiline string
          """
      """#

    let expected =
      #"""
      let x =
        """
        this is a
        multiline string
        """
          + """
          this is more
          multiline string
          """

      """#

    assertPrettyPrintEqual(input: input, expected: expected, linelength: 20)
  }
}
