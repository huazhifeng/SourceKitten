//
//  ModuleTests.swift
//  SourceKitten
//
//  Created by JP Simard on 2015-01-07.
//  Copyright (c) 2015 SourceKitten. All rights reserved.
//

import Foundation
import SourceKittenFramework
import XCTest

let projectRoot = #file.bridge()
    .deletingLastPathComponent.bridge()
    .deletingLastPathComponent.bridge()
    .deletingLastPathComponent

let sourcekittenXcodebuildArguments = [
    "-workspace", "SourceKitten.xcworkspace",
    "-scheme", "SourceKittenFramework",
    "-derivedDataPath",
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("testSourceKittenFrameworkDocsAreValidJSON").path
]

class ModuleTests: XCTestCase {

    func testModuleNilInPathWithNoXcodeProject() {
        let pathWithNoXcodeProject = (#file as NSString).deletingLastPathComponent
        let model = Module(xcodeBuildArguments: [], name: nil, inPath: pathWithNoXcodeProject)
        XCTAssert(model == nil, "model initialization without any Xcode project should fail")
    }

    func testSourceKittenFrameworkDocsAreValidJSON() {
        let sourceKittenModule = Module(xcodeBuildArguments: sourcekittenXcodebuildArguments, name: nil, inPath: projectRoot)!
        let docsJSON = sourceKittenModule.docs.description
        XCTAssert(docsJSON.range(of: "error type") == nil)
        do {
            let jsonArray = try JSONSerialization.jsonObject(with: docsJSON.data(using: .utf8)!, options: []) as? NSArray
            XCTAssertNotNil(jsonArray, "JSON should be propery parsed")
        } catch {
            XCTFail("JSON should be propery parsed")
        }
    }

    func testCommandantDocs() {
        let commandantPath = projectRoot + "/Carthage/Checkouts/Commandant/"
        let arguments = ["-workspace", "Commandant.xcworkspace", "-scheme", "Commandant"]
        let commandantModule = Module(xcodeBuildArguments: arguments, name: nil, inPath: commandantPath)!
        compareJSONString(withFixtureNamed: "Commandant", jsonString: commandantModule.docs, rootDirectory: commandantPath)
    }
}

#if SWIFT_PACKAGE
let commandantPathForSPM: String? = {
    struct Package: Decodable {
        var name: String
        var path: String
        var dependencies: [Package]
    }

    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = ["swift", "package", "show-dependencies", "--format", "json"]
    task.currentDirectoryPath = projectRoot

    let pipe = Pipe()
    task.standardOutput = pipe

    task.launch()
    task.waitUntilExit()

    let file = pipe.fileHandleForReading
    let data = file.readDataToEndOfFile()
    file.closeFile()
    guard task.terminationStatus == 0 else {
        print("`\(task.arguments?.joined(separator: " ") ?? "")` returns error: \(task.terminationStatus)")
        return nil
    }
    do {
        let package = try JSONDecoder().decode(Package.self, from: data)
        return (package.dependencies.first(where: { $0.name == "Commandant" })?.path).map { $0 + "/" }
    } catch {
        print("failed to decode output of `\(task.arguments?.joined(separator: " ") ?? "")`: \(error)")
        return nil
    }
}()

extension ModuleTests {
    func testCommandantDocsSPM() {
        guard let commandantPath = commandantPathForSPM else {
            XCTFail("Can't find Commandant")
            return
        }
        let commandantModule = Module(spmName: "Commandant")!
        compareJSONString(withFixtureNamed: "CommandantSPM", jsonString: commandantModule.docs, rootDirectory: commandantPath)
    }

    static var allTests: [(String, (ModuleTests) -> () throws -> Void)] {
        return [
            // Disabled on Linux because these tests require Xcode
            // ("testModuleNilInPathWithNoXcodeProject", testModuleNilInPathWithNoXcodeProject),
            // ("testSourceKittenFrameworkDocsAreValidJSON", testSourceKittenFrameworkDocsAreValidJSON),
            // ("testCommandantDocs", testCommandantDocs),
            ("testCommandantDocsSPM", testCommandantDocsSPM)
        ]
    }
}
#endif
