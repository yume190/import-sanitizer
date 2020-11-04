//
//  ProjectSourceFiles.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import Files

struct ProjectSourceFiles {
    let mode: FixMode
    let targetPath : String
    let sourceFiles: [File]
    var count: Int { sourceFiles.count }

    init(targetPath: String, mode: FixMode) throws {
        self.targetPath = targetPath
        self.mode = mode
        self.sourceFiles = try ProjectSourceFiles.fetchSourceFiles(path: targetPath, mode: mode)
        print("""
        待检查的源文件数量为: \(sourceFiles.count)
        ===========================
        """)
    }
    
    func podspecInfo() throws -> PodSpec? {
        guard self.mode == .sdk else {
            return nil
        }
        return try Utility.fetchPodspecInfo(with: self.targetPath)
    }
}

extension ProjectSourceFiles {
    static func fetchSourceFiles(path: String, mode: FixMode) throws -> [File] {
        // 核心逻辑 根据不同的模式获取 source file
        // 在 sdk 模式下, 为 PODSPEC 里 source_file 描述的文件
        // 在 shell 模式下, 为 PODS 目录下的文件
        // 在 app 模式下, 为指定文件夹下的文件
        var files = [File]()
        switch mode {
        case .sdk:
            files = try ProjectSourceFiles.gatherIn(podspecPath: path)
        case .shell:
            files = try ProjectSourceFiles.gatherIn(podfilePath: path)
        case .app:
            files = try ProjectSourceFiles.gatherIn(appPath: path)
        }
        return files
    }
    
    // sdk 模式下的文件
    static func gatherIn(podspecPath: String ) throws -> [File] {
        var targetFiles = [File]()
        // 根据 podspec 的路径获取整个项目工程的相对根目录
        let podspec = try Utility.fetchPodspecInfo(with: podspecPath)
        
        guard let rootPath = try File(path: podspecPath).parent?.path else{
            return targetFiles
        }
        // 遍历 podspec 里的路径并拼接文件名
        for info in podspec.sourceFiles {
            let relativePath = info.split(separator: "/")
                .filter{ $0.contains("*") == false }
                .joined(separator: "/")
            
            let folderPath = "/" + rootPath + "/" + relativePath
            let files = try Folder(path: folderPath).sourceFileInProject()
            targetFiles.append(contentsOf: files)
        }
        return targetFiles
    }
    
    // shell 模式下的文件
    static func gatherIn(podfilePath: String) throws -> [File] {
        var targetFiles = [File]()
        // 根据 podfile 获取 pods 目录
        let podsPath = podfilePath.replacingOccurrences(
            of: "/Podfile",
            with: "/Pods")
        let sdkNames = try Utility.fetchSDKNames(with: podsPath)
        // 通过组件名称构建一个 sdk 路径, 在这个路径下把所有文件名遍历并塞到映射表中
        for sdk in sdkNames {
            let sdkPath = podsPath + "/" + sdk
            let target = try Folder(path: sdkPath).sourceFileInProject()
            targetFiles.append(contentsOf: target)
        }
        return targetFiles
    }
    
    // app 模式下的文件
    static func gatherIn(appPath: String) throws -> [File] {
        // 根据指定目录获取
        let targetFiles = try Folder(path: appPath).sourceFileInProject()
        return targetFiles
    }
        
}

