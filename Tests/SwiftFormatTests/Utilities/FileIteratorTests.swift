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

@_spi(Internal) @_spi(Testing) import SwiftFormat
import XCTest

extension URL {
  /// Assuming this is a file URL, resolves all symlinks in the path.
  ///
  /// - Note: We need this because `URL.resolvingSymlinksInPath()` not only resolves symlinks but also standardizes the
  ///   path by stripping away `private` prefixes. Since sourcekitd is not performing this standardization, using
  ///   `resolvingSymlinksInPath` can lead to slightly mismatched URLs between the sourcekit-lsp response and the test
  ///   assertion.
  fileprivate var realpath: URL {
    #if canImport(Darwin)
    return self.path.withCString { path in
      guard let realpath = Darwin.realpath(path, nil) else {
        return self
      }
      let result = URL(fileURLWithPath: String(cString: realpath))
      free(realpath)
      return result
    }
    #else
    // Non-Darwin platforms don't have the `/private` stripping issue, so we can just use `self.resolvingSymlinksInPath`
    // here.
    return self.resolvingSymlinksInPath()
    #endif
  }
}

final class FileIteratorTests: XCTestCase {
  private var tmpdir: URL!

  override func setUpWithError() throws {
    tmpdir = try FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: FileManager.default.temporaryDirectory,
      create: true
    ).realpath

    // Create a simple file tree used by the tests below.
    try touch("project/real1.swift")
    try touch("project/real2.swift")
    try touch("project/.hidden.swift")
    try touch("project/.build/generated.swift")
    #if !os(WASI)  // FIXME: Remove this #if
    try symlink("project/link.swift", to: "project/.hidden.swift")
    #endif
    try symlink("project/rellink.swift", relativeTo: ".hidden.swift")

    #if !(os(Windows) && compiler(<5.10))
    // Test both a self-cycle and a cycle between multiple symlinks.
    try symlink("project/cycliclink.swift", relativeTo: "cycliclink.swift")
    #if !os(WASI)
    try symlink("project/linktolink.swift", relativeTo: "link.swift")
    #else
    try symlink("project/linktolink.swift", relativeTo: "rellink.swift")
    #endif

    // Test symlinks that use nonstandardized paths.
    try symlink("project/2stepcyclebegin.swift", relativeTo: "../project/2stepcycleend.swift")
    try symlink("project/2stepcycleend.swift", relativeTo: "./2stepcyclebegin.swift")
    #endif
  }

  override func tearDownWithError() throws {
    #if os(WASI)  // WASI doesn't support recursive FileManager.removeItem
    try FileManager.default.removeItem(at: tmpURL("project/real1.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/real2.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/.hidden.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/.build/generated.swift"))
    // FIXME: try FileManager.default.removeItem(at: tmpURL("project/link.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/rellink.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/cycliclink.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/linktolink.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/2stepcyclebegin.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/2stepcycleend.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/.build/"))
    try FileManager.default.removeItem(at: tmpURL("project/"))
    try FileManager.default.removeItem(at: tmpdir)
    #else
    try FileManager.default.removeItem(at: tmpdir)
    #endif
  }

  func testNoFollowSymlinks() throws {
    #if os(Windows) && compiler(<5.10)
    try XCTSkipIf(true, "Foundation does not follow symlinks on Windows")
    #endif
    let seen = allFilesSeen(iteratingOver: [tmpdir], followSymlinks: false)
    XCTAssertEqual(seen.count, 2)
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/real1.swift") })
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/real2.swift") })
  }

  func testFollowSymlinks() throws {
    #if os(Windows) && compiler(<5.10)
    try XCTSkipIf(true, "Foundation does not follow symlinks on Windows")
    #endif
    let seen = allFilesSeen(iteratingOver: [tmpdir], followSymlinks: true)
    XCTAssertEqual(seen.count, 3)
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/real1.swift") })
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/real2.swift") })
    // Hidden but found through the visible symlink project/link.swift
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/.hidden.swift") })
  }

  func testFollowSymlinksToSymlinks() throws {
    #if os(Windows) && compiler(<5.10)
    try XCTSkipIf(true, "Foundation does not follow symlinks on Windows")
    #endif
    let seen = allFilesSeen(
      iteratingOver: [tmpURL("project/linktolink.swift")],
      followSymlinks: true
    )
    // Hidden but found through the visible symlink chain.
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/.hidden.swift") })
  }

  func testSymlinkCyclesAreIgnored() throws {
    #if os(Windows) && compiler(<5.10)
    try XCTSkipIf(true, "Foundation does not follow symlinks on Windows")
    #endif
    let seen = allFilesSeen(
      iteratingOver: [
        tmpURL("project/cycliclink.swift"),
        tmpURL("project/2stepcyclebegin.swift"),
        tmpURL("project/link.swift"),
        tmpURL("project/rellink.swift"),
      ],
      followSymlinks: true
    )
    // Hidden but found through the visible symlink chain.
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/.hidden.swift") })
    // And the cycles were ignored.
    XCTAssertEqual(seen.count, 1)
  }

  func testTraversesHiddenFilesIfExplicitlySpecified() throws {
    #if os(Windows) && compiler(<5.10)
    try XCTSkipIf(true, "Foundation does not follow symlinks on Windows")
    #endif
    let seen = allFilesSeen(
      iteratingOver: [tmpURL("project/.build"), tmpURL("project/.hidden.swift")],
      followSymlinks: false
    )
    XCTAssertEqual(seen.count, 2)
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/.build/generated.swift") })
    XCTAssertTrue(seen.contains { $0.path.hasSuffix("project/.hidden.swift") })
  }

  func testDoesNotFollowSymlinksIfFollowSymlinksIsFalseEvenIfExplicitlySpecified() {
    // Symlinks are not traversed even if `followSymlinks` is false even if they are explicitly
    // passed to the iterator. This is meant to avoid situations where a symlink could be hidden by
    // shell expansion; for example, if the user writes `swift-format --no-follow-symlinks *`, if
    // the current directory contains a symlink, they would probably *not* expect it to be followed.
    let seen = allFilesSeen(
      iteratingOver: [tmpURL("project/link.swift"), tmpURL("project/rellink.swift")],
      followSymlinks: false
    )
    XCTAssertTrue(seen.isEmpty)
  }

  func testDoesNotTrimFirstCharacterOfPathIfRunningInRoot() throws {
    // Find the root of tmpdir. On Unix systems, this is always `/`. On Windows it is the drive.
    var root = tmpdir!
    while !root.isRoot {
      root.deleteLastPathComponent()
    }
    #if os(Windows) && compiler(<6.1)
    var rootPath = root.path
    if rootPath.hasPrefix("/") {
      // Canonicalize /C: to C:
      rootPath = String(rootPath.dropFirst())
    }
    #else
    let rootPath = root.path
    #endif
    // Make sure that we don't drop the beginning of the path if we are running in root.
    // https://github.com/swiftlang/swift-format/issues/862
    let seen = allFilesSeen(iteratingOver: [tmpdir], followSymlinks: false, workingDirectory: root).map(\.relativePath)
    XCTAssertTrue(seen.allSatisfy { $0.hasPrefix(rootPath) }, "\(seen) does not contain root directory '\(rootPath)'")
  }

  func testShowsRelativePaths() throws {
    // Make sure that we still show the relative path if using them.
    // https://github.com/swiftlang/swift-format/issues/862
    let seen = allFilesSeen(iteratingOver: [tmpdir], followSymlinks: false, workingDirectory: tmpdir)
    XCTAssertEqual(Set(seen.map(\.relativePath)), ["project/real1.swift", "project/real2.swift"])
  }
}

extension FileIteratorTests {
  /// Returns a URL to a file or directory in the test's temporary space.
  private func tmpURL(_ path: String) -> URL {
    return tmpdir.appendingPathComponent(path, isDirectory: false)
  }

  /// Create an empty file at the given path in the test's temporary space.
  private func touch(_ path: String) throws {
    let fileURL = tmpURL(path)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    struct FailedToCreateFileError: Error {
      let url: URL
    }
    if !FileManager.default.createFile(atPath: fileURL.path, contents: Data()) {
      throw FailedToCreateFileError(url: fileURL)
    }
  }

  /// Create a absolute symlink between files or directories in the test's temporary space.
  private func symlink(_ source: String, to target: String) throws {
    try FileManager.default.createSymbolicLink(
      at: tmpURL(source),
      withDestinationURL: tmpURL(target)
    )
  }

  /// Create a relative symlink between files or directories in the test's temporary space.
  private func symlink(_ source: String, relativeTo target: String) throws {
    try FileManager.default.createSymbolicLink(
      atPath: tmpURL(source).path,
      withDestinationPath: target
    )
  }

  /// Computes the list of all files seen by using `FileIterator` to iterate over the given URLs.
  private func allFilesSeen(
    iteratingOver urls: [URL],
    followSymlinks: Bool,
    workingDirectory: URL = URL(fileURLWithPath: ".")
  ) -> [URL] {
    let iterator = FileIterator(urls: urls, followSymlinks: followSymlinks, workingDirectory: workingDirectory)
    var seen: [URL] = []
    for next in iterator {
      seen.append(next)
    }
    return seen
  }
}
