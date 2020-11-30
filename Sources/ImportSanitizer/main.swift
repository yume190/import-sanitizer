//
//  main.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import ArgumentParser
import ImportSanitizerCore
import Files

struct ImportSanitizer: ParsableCommand {
    @Argument(help: "The path of \'.podfile\' file, which help this application to make a map table between header files and sdk through 'PODS' directory")
    var podfilePath: String
    
    @Option(name: .shortAndLong, help: "Used to determine the operation of the application, you can pass 'sdk', 'app', 'shell' to this argument. In sdk mode, this tool will fix files underge podspes's `source_file` path, In app mode, this tool will fix files in your app's path, adn In shell mode, this tool will fix files in 'PODS' path")
    var mode: FixMode
    
    @Option(name: .shortAndLong, help: "Some infomation about target file, which should be fixed. In sdk mode, this value should be podspec.json's path(podspec and podspecjson should be same path), In app mode, this value shoulde be your demo's path, and In shell mode, this value should be equal to PODS dir path")
    var targetPath: String

    @Option(name: .shortAndLong, help: "Use this patch file to update header map table")
    var patchFilePath: String?
    
    @Option(name: .shortAndLong, help: "Don't use this option unless you work for HPX toolchains. this option works in shell mode only, When application build map table in PODS dir, some subDir will be ignore by this value. and then application search target files that only match this value in PODS dir")
    var specialPods: String?
    
    @Flag(name: .shortAndLong, help: "Print status updates while sanitizing.")
    var verbose = false
    
    mutating func run() throws {
        print("\(SeperateLine.normal.rawValue) check input argument begin \(SeperateLine.normal.rawValue)")
        print("""
        原始参数如下:
        podfile Path is         \(podfilePath),
        mode is                 \(mode),
        podspecjson Path is     \(targetPath).
        patchfile Path is       \(patchFilePath ?? "nil")
        ignore Pods is          \(specialPods ?? "nil")
        """)
        guard try isPodfilePathValidate() && isTargetPathValidate() &&
                isSpecialPodsValidate() && isPatchFilePathValidate() else {
            return
        }
        print("\(SeperateLine.normal.rawValue) check input argument end \(SeperateLine.normal.rawValue)")

        
        do {
            let pipeline = try Pipeline(podfilePath: podfilePath,
                                        mode: mode,
                                        targetPath: targetPath,
                                        patchFilePath: patchFilePath,
                                        specialPods: specialPods)
            try pipeline.run()
            print("\(SeperateLine.success.rawValue) execute success begin \(SeperateLine.success.rawValue)")
            print("Import Syntax Sanitizer Success!")
            print("\(SeperateLine.success.rawValue) execute success end \(SeperateLine.success.rawValue)")
        } catch {
            print("\(SeperateLine.fail.rawValue) execute failed begin \(SeperateLine.fail.rawValue)")
            print("Whoops! An error occurred: \(error)!")
            print("\(SeperateLine.fail.rawValue) execute failed end \(SeperateLine.fail.rawValue)")
        }
    }
}

extension ImportSanitizer {
    func isPodfilePathValidate() throws -> Bool {
        let validate = (try File(path: self.podfilePath).name == "Podfile")
        if !validate {
            print("podfilePath 参数有误, 文件名不为 Podfile, 当前参数为 \(podfilePath)")
            return false
        }
        return true
    }
    
    func isTargetPathValidate() throws -> Bool {
        var validate = false
        switch self.mode {
        case .sdk:
            validate = (try File(path: self.targetPath).extension == "json")
            if !validate {
                print("targetPath 参数有误, 在 sdk 模式下该参数的后缀名为 json, 当前参数为 \(targetPath)")
                return false
            }
        case .shell:
            validate = (try Folder(path: self.targetPath).name == "Pods")
            if !validate {
                print("targetPath 参数有误, 在 shell 模式下该参数的文件夹名称 Pods, 当前参数为 \(targetPath)")
                return false
            }
        case .app:
            validate = true
        }
        return true
    }
    
    
    func isPatchFilePathValidate() throws -> Bool {
        guard let path = self.patchFilePath else {
            return true
        }
        var validate = false
        validate = (try File(path: path).extension == "json")
        if !validate {
            print("patchfilePath 参数有误, 参数的后缀名为 json, 当前参数为 \(path)")
            return false
        }
        return true
    }
    
    func isSpecialPodsValidate() throws -> Bool {
        guard let value = self.specialPods else {
            return true
        }
        var validate = false
        let pods = value.trimmingCharacters(in:.whitespaces).split(separator:",").map{String($0)}
        validate = (pods.count > 0 && self.mode == .shell)
        if !validate {
            print("specialPods 参数有误, 必须在 shell 模式下且用 ',' 区分组件名, 当前参数为 \(value)")
            return false
        }
        return true
    }
}

ImportSanitizer.main()
