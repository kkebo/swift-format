@_spi(Internal) import SwiftFormat
import XCTest

final class FileIteratorTests: XCTestCase {
  private var tmpdir: URL!

  override func setUpWithError() throws {
    tmpdir = try FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: FileManager.default.temporaryDirectory,
      create: true
    )

    // Create a simple file tree used by the tests below.
    try touch("project/real1.swift")
    try touch("project/real2.swift")
    try touch("project/.hidden.swift")
    try touch("project/.build/generated.swift")
    #if !os(WASI)  // FIXME: Remove this #if
    try symlink("project/link.swift", to: "project/.hidden.swift")
    #endif
  }

  override func tearDownWithError() throws {
    #if os(WASI)  // WASI doesn't support recursive FileManager.removeItem
    try FileManager.default.removeItem(at: tmpURL("project/real1.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/real2.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/.hidden.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/.build/generated.swift"))
    // FIXME: try FileManager.default.removeItem(at: tmpURL("project/link.swift"))
    try FileManager.default.removeItem(at: tmpURL("project/.build/"))
    try FileManager.default.removeItem(at: tmpURL("project/"))
    try FileManager.default.removeItem(at: tmpdir)
    #else
    try FileManager.default.removeItem(at: tmpdir)
    #endif
  }

  func testNoFollowSymlinks() {
    let seen = allFilesSeen(iteratingOver: [tmpdir], followSymlinks: false)
    XCTAssertEqual(seen.count, 2)
    XCTAssertTrue(seen.contains { $0.hasSuffix("project/real1.swift") })
    XCTAssertTrue(seen.contains { $0.hasSuffix("project/real2.swift") })
  }

  func testFollowSymlinks() {
    let seen = allFilesSeen(iteratingOver: [tmpdir], followSymlinks: true)
    #if os(WASI)
    XCTAssertEqual(seen.count, 2)
    #else
    XCTAssertEqual(seen.count, 3)
    #endif
    XCTAssertTrue(seen.contains { $0.hasSuffix("project/real1.swift") })
    XCTAssertTrue(seen.contains { $0.hasSuffix("project/real2.swift") })
    #if !os(WASI)  // FIXME: Remove this #if
    // Hidden but found through the visible symlink project/link.swift
    XCTAssertTrue(seen.contains { $0.hasSuffix("project/.hidden.swift") })
    #endif
  }

  func testTraversesHiddenFilesIfExplicitlySpecified() {
    let seen = allFilesSeen(
      iteratingOver: [tmpURL("project/.build"), tmpURL("project/.hidden.swift")],
      followSymlinks: false
    )
    XCTAssertEqual(seen.count, 2)
    XCTAssertTrue(seen.contains { $0.hasSuffix("project/.build/generated.swift") })
    XCTAssertTrue(seen.contains { $0.hasSuffix("project/.hidden.swift") })
  }

  func testDoesNotFollowSymlinksIfFollowSymlinksIsFalseEvenIfExplicitlySpecified() {
    #if !os(WASI)  // FIXME: Remove this #if
    // Symlinks are not traversed even if `followSymlinks` is false even if they are explicitly
    // passed to the iterator. This is meant to avoid situations where a symlink could be hidden by
    // shell expansion; for example, if the user writes `swift-format --no-follow-symlinks *`, if
    // the current directory contains a symlink, they would probably *not* expect it to be followed.
    let seen = allFilesSeen(iteratingOver: [tmpURL("project/link.swift")], followSymlinks: false)
    XCTAssertTrue(seen.isEmpty)
    #endif
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
    #if os(WASI)  // WASI doesn't support FileManager.createFile because it doesn't support atomic
    try Data().write(to: fileURL)
    #else
    struct FailedToCreateFileError: Error {
      let url: URL
    }
    if !FileManager.default.createFile(atPath: fileURL.path, contents: Data()) {
      throw FailedToCreateFileError(url: fileURL)
    }
    #endif
  }

  /// Create a symlink between files or directories in the test's temporary space.
  private func symlink(_ source: String, to target: String) throws {
    try FileManager.default.createSymbolicLink(
      at: tmpURL(source),
      withDestinationURL: tmpURL(target)
    )
  }

  /// Computes the list of all files seen by using `FileIterator` to iterate over the given URLs.
  private func allFilesSeen(iteratingOver urls: [URL], followSymlinks: Bool) -> [String] {
    let iterator = FileIterator(urls: urls, followSymlinks: followSymlinks)
    var seen: [String] = []
    for next in iterator {
      seen.append(next.path)
    }
    return seen
  }
}
