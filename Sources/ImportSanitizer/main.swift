//
//  main.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import ArgumentParser
import ImportSanitizerCore

struct ImportSanitizer: ParsableCommand {
    @Argument(help: "The path of \'.podfile\' file, which help this application to make a map table between header files and sdk through 'PODS' directory")
    var podfilePath: String
    
    @Option(name: .shortAndLong, help: "Used to determine the operation of the application, you can pass 'sdk', 'app', 'shell' to this argument. In sdk mode, this tool will fix files underge podspes's `source_file` path, In app mode, this tool will fix files in your app's path, adn In shell mode, this tool will fix files in 'PODS' path")
    var mode: FixMode
    
    @Option(name: .shortAndLong, help: "Some infomation about target file, which should be fixed. In sdk mode, this value should be podspec.json's path(podspec and podspecjson should be same path), In app mode, this value shoulde be your demo's path, and In shell mode, this value should be equal to PODS dir path")
    var targetPath: String

    @Option(name: .shortAndLong, help: "Use this patch file to update header map table")
    var patchFilePath: String?
    
    @Flag(name: .shortAndLong, help: "Print status updates while sanitizing.")
    var verbose = false
    
    mutating func run() throws {
        print("""
        原始参数如下:
        podfile Path is         \(podfilePath),
        mode is                 \(mode),
        podspecjson Path is     \(targetPath).
        patchfile Path is       \(patchFilePath ?? "nil")
        ===========================
        """)
        do {
            let pipeline = try Pipeline(podfilePath: podfilePath,
                                        mode: mode,
                                        targetPath: targetPath,
                                        patchFilePath: patchFilePath)
            try pipeline.run()
        } catch {
            print("Whoops! An error occurred: \(error)")
        }
    }
}

ImportSanitizer.main()
