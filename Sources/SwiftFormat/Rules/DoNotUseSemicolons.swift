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

import SwiftSyntax

/// Semicolons should not be present in Swift code.
///
/// Lint: If a semicolon appears anywhere, a lint error is raised.
///
/// Format: All semicolons will be replaced with line breaks.
@_spi(Rules)
public final class DoNotUseSemicolons: SyntaxFormatRule {

  /// Creates a new version of the given node which doesn't contain any semicolons. The node's
  /// items are recursively modified to remove semicolons, replacing with line breaks where needed.
  /// Items are checked recursively to support items that contain code blocks, which may have
  /// semicolons to be removed.
  /// - Parameters:
  ///   - node: A node that contains items which may have semicolons or nested code blocks.
  ///   - nodeCreator: A closure that creates a new node given an array of items.
  private func nodeByRemovingSemicolons<
    ItemType: SyntaxProtocol & SemicolonSyntaxProtocol & Equatable, NodeType: SyntaxCollection
  >(from node: NodeType, nodeCreator: ([ItemType]) -> NodeType) -> NodeType
  where NodeType.Element == ItemType {
    var newItems = Array(node)

    // Because newlines belong to the _first_ token on the new line, if we remove a semicolon, we
    // need to keep track of the fact that the next statement needs a new line.
    var previousHadSemicolon = false
    for (idx, item) in node.enumerated() {

      // Store the previous statement's semicolon-ness.
      defer { previousHadSemicolon = item.semicolon != nil }

      // Check for semicolons in statements inside of the item, because code blocks may be nested
      // inside of other code blocks.
      guard let visitedItem = rewrite(Syntax(item)).as(ItemType.self) else {
        return node
      }

      // Check if we need to make any modifications (removing semicolon/adding newlines)
      guard visitedItem != item || item.semicolon != nil || previousHadSemicolon else {
        continue
      }

      var newItem = visitedItem
      defer { newItems[idx] = newItem }

      // Check if the leading trivia for this statement needs a new line.
      if previousHadSemicolon, let firstToken = newItem.firstToken(viewMode: .sourceAccurate),
        !firstToken.leadingTrivia.containsNewlines
      {
        newItem.leadingTrivia = .newlines(1) + firstToken.leadingTrivia
      }

      // If there's a semicolon, diagnose and remove it.
      if let semicolon = item.semicolon {
        // Exception: do not remove the semicolon if it is separating a 'do' statement from a
        // 'while' statement.
        if Syntax(item).as(CodeBlockItemSyntax.self)?
          .children(viewMode: .sourceAccurate).first?.is(DoStmtSyntax.self) == true,
          idx < node.count - 1,
          let childrenIdx = node.index(of: item)
        {
          let children = node.children(viewMode: .sourceAccurate)
          let nextItem = children[children.index(after: childrenIdx)]
          if Syntax(nextItem).as(CodeBlockItemSyntax.self)?
            .children(viewMode: .sourceAccurate).first?.is(WhileStmtSyntax.self) == true
          {
            continue
          }
        }

        // This discards any trailing trivia from the semicolon. That trivia will only be horizontal
        // whitespace, and the pretty printer adds any necessary spaces so it's safe to discard.
        // TODO: When we stop using the legacy trivia transform, we need to fix this to preserve
        // trailing comments.
        newItem = newItem.with(\.semicolon, nil)

        // When emitting the finding, tell the user to move the next statement down if there is
        // another statement following this one. Otherwise, just tell them to remove the semicolon.
        if let nextToken = semicolon.nextToken(viewMode: .sourceAccurate),
          nextToken.tokenKind != .rightBrace && nextToken.tokenKind != .endOfFile
            && !nextToken.leadingTrivia.containsNewlines
        {
          diagnose(.removeSemicolonAndMove, on: semicolon)
        } else {
          diagnose(.removeSemicolon, on: semicolon)
        }
      }
    }
    return nodeCreator(newItems)
  }

  public override func visit(_ node: CodeBlockItemListSyntax) -> CodeBlockItemListSyntax {
    return nodeByRemovingSemicolons(from: node, nodeCreator: CodeBlockItemListSyntax.init)
  }

  public override func visit(_ node: MemberBlockItemListSyntax) -> MemberBlockItemListSyntax {
    return nodeByRemovingSemicolons(from: node, nodeCreator: MemberBlockItemListSyntax.init)
  }
}

extension Finding.Message {
  @_spi(Rules)
  public static let removeSemicolon: Finding.Message = "remove ';'"

  @_spi(Rules)
  public static let removeSemicolonAndMove: Finding.Message =
    "remove ';' and move the next statement to a new line"
}
