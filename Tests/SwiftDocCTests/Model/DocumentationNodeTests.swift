/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
@testable import SymbolKit
@testable import SwiftDocC
import XCTest

class DocumentationNodeTests: XCTestCase {
    func testH4AndUpAnchorSections() throws {
        let articleSource = """
        # Title

        ## Heading2

        ### Heading3
        
        #### Heading4
        
        ##### Heading5

        ###### Heading6
        """
        
        let article = Article(markup: Document(parsing: articleSource, options: []), metadata: nil, redirects: nil, options: [:])
        let node = try DocumentationNode(
            reference: ResolvedTopicReference(bundleIdentifier: "org.swift.docc", path: "/blah", sourceLanguage: .swift),
            article: article
        )
        XCTAssertEqual(node.anchorSections.count, 5)
        for (index, anchorSection) in node.anchorSections.enumerated() {
            let expectedTitle = "Heading\(index + 2)"
            XCTAssertEqual(anchorSection.title, expectedTitle)
            XCTAssertEqual(anchorSection.reference, node.reference.withFragment(expectedTitle))
        }
    }

    func testInitializerSelectsSymbolWithDocumentation() throws {

        func lineListFrom(docs: String?) -> SymbolGraph.LineList? {
            guard let str = docs else {
                return nil
            }
            let range = SymbolGraph.LineList.SourceRange(
                start: .init(line: 0, character: 0),
                end: .init(line: 0, character: 0)
            )
            let line = SymbolGraph.LineList.Line(text: str, range: range)
            return SymbolGraph.LineList([line])
        }

        func createSymbol(interfaceLanguage: String, docs: String? = nil) -> SymbolGraph.Symbol {
            return SymbolGraph.Symbol(
                identifier: .init(precise: "abcd", interfaceLanguage: interfaceLanguage),
                names: .init(title: "abcd-in-\(interfaceLanguage)", navigator: nil, subHeading: nil, prose: nil),
                pathComponents: ["documentation", "mykit", "abcd"],
                docComment: lineListFrom(docs: docs),
                accessLevel: .init(rawValue: "public"),
                kind: .init(parsedIdentifier: .struct, displayName: "ABCD Name"),
                mixins: [:]
            )
        }

        func assertDocumentationNodeSelected(expectedDocs: String?, symbols: [SymbolGraph.Symbol]) {
            let module = SymbolGraph.Module(name: "os", platform: SymbolGraph.Platform())
            let unifiedSymbol = UnifiedSymbolGraph.Symbol(fromSingleSymbol: symbols.first!, module: module, isMainGraph: true)
            for sym in symbols.dropFirst() {
                unifiedSymbol.mergeSymbol(symbol: sym, module: module, isMainGraph: true)
            }
            let bundleIdentifier = "org.swift.docc.mykit"
            let reference = ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: "/documentation/MyKit/abcd", sourceLanguage: .swift )
            let moduleReference = ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: "/documentation/MyKit", sourceLanguage: .swift)
            let documentation = DocumentationNode(
                reference: reference,
                unifiedSymbol: unifiedSymbol,
                moduleData: module,
                moduleReference: moduleReference
            )
            if let lineList = lineListFrom(docs: expectedDocs) {
                XCTAssertEqual(lineList, documentation.symbol?.docComment)
            } else {
                XCTAssertNil(documentation.symbol?.docComment)
            }
        }

        // One Swift Symbol with no documentation
        var swiftSymbol = createSymbol(interfaceLanguage: "swift")
        assertDocumentationNodeSelected(expectedDocs: nil, symbols: [swiftSymbol])

        // One ObjC Symbol with no documentation
        var objCSymbol = createSymbol(interfaceLanguage: "objc")
        assertDocumentationNodeSelected(expectedDocs: nil, symbols: [objCSymbol])

        let swiftDocs = "Some Swift Docs"
        let objCDocs = "Some ObjC Docs"

        // Two symbols: Obj-C symbol with documentation, and Swift without - select ObjC
        objCSymbol = createSymbol(interfaceLanguage: "objc", docs: objCDocs)
        assertDocumentationNodeSelected(expectedDocs: objCDocs, symbols: [swiftSymbol, objCSymbol])

        // Two symbols: Swift symbol with documentation, and Obj-C without - select Swift
        swiftSymbol = createSymbol(interfaceLanguage: "swift", docs: swiftDocs)
        objCSymbol = createSymbol(interfaceLanguage: "objc")
        assertDocumentationNodeSelected(expectedDocs: swiftDocs, symbols: [swiftSymbol, objCSymbol])

        // Two symbols: Swift symbol and Obj-C both have docs - select Swift
        swiftSymbol = createSymbol(interfaceLanguage: "swift", docs: swiftDocs)
        objCSymbol = createSymbol(interfaceLanguage: "objc", docs: objCDocs)
        assertDocumentationNodeSelected(expectedDocs: swiftDocs, symbols: [swiftSymbol, objCSymbol])
    }
}
