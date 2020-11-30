//
//  ProjectSourceFiles.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import Files

struct ProjectSourceFiles {
    let targetPath : String
    let mode: FixMode
    let specailPods: [String]?
    var sourceFiles = [File]()
    var count: Int { sourceFiles.count }

    init(targetPath: String, mode: FixMode, specailPods: [String]?) throws {
        self.targetPath = targetPath
        self.mode = mode
        self.specailPods = specailPods
        self.sourceFiles = try self.fetchSourceFiles(path: targetPath, mode: mode)
        print("""
        待检查的源文件数量为: \(sourceFiles.count)
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
    func fetchSourceFiles(path: String, mode: FixMode) throws -> [File] {
        // 核心逻辑 根据不同的模式获取 source file
        // 在 sdk 模式下, 为 PODSPEC 里 source_file 描述的文件
        // 在 shell 模式下, 为 PODS 目录下的文件
        // 在 app 模式下, 为指定文件夹下的文件
        var files = [File]()
        switch mode {
        case .sdk:
            files = try self.gatherIn(podspecPath: path)
        case .shell:
            files = try self.gatherIn(podfilePath: path)
        case .app:
            files = try self.gatherIn(appPath: path)
        }
        return files
    }
    
    // sdk 模式下的文件
    func gatherIn(podspecPath: String ) throws -> [File] {
        var targetFiles = [File]()
        // 根据 podspec 的路径获取整个项目工程的相对根目录
        let podspec = try Utility.fetchPodspecInfo(with: podspecPath)
        
        guard let rootPath = try File(path: podspecPath).parent?.path else{
            return targetFiles
        }
        // 遍历 podspec 里的路径并拼接文件名
        var relativePaths = [String]()
        for info in podspec.sourceFilesAll() {
            let relativePathComponent = info.split(separator: "/")
            let cutIndex = relativePathComponent.firstIndex {(element) -> Bool in
                element.contains("*") || element.contains(".")
            }
            var result = [String.SubSequence]()
            if let end = cutIndex {
                result = Array(relativePathComponent[0..<Int(end)])
            } else {
                result = relativePathComponent
            }
                
            // 注意: 这里的代码注意是针对 podspec 里 A/B/{C,D,E,F} 写法进行兼容的逻辑
            let original = result.map { (element) -> Array<String> in
                if element.contains(",") && element.contains("{") && element.contains("}") {
                    return element.replacingOccurrences(of: "{", with: "")
                        .replacingOccurrences(of: "}", with: "")
                        .split(separator: ",")
                        .map{String($0)}
                } else {
                    return [String(element)]
                }
            }
            self.dfs(dep: 0, original: original, input: [], output: &relativePaths)
        }
        for relativePath in relativePaths {
            let folderPath = rootPath + relativePath
            let files = try Folder(path: folderPath).sourceFileInProject()
            targetFiles.append(contentsOf: files)
        }
        // 对 target files 去重
        let result = targetFiles.removeDuplicate()
        return result
    }
    
    // shell 模式下的文件
    func gatherIn(podfilePath: String) throws -> [File] {
        var targetFiles = [File]()
        // 根据 podfile 获取 pods 目录
        let podsPath = podfilePath.replacingOccurrences(
            of: "/Podfile",
            with: "/Pods")
        var sdkNames = try Utility.fetchSDKNames(with: podsPath)
        // 根据 ignorePods 对 mapTabl 进行改造
        if let names = self.specailPods, names.count > 0 {
            sdkNames = sdkNames.filter { names.contains($0) }
        }
        // 通过组件名称构建一个 sdk 路径, 在这个路径下把所有文件名遍历并塞到映射表中
        for sdk in sdkNames {
            let sdkPath = podsPath + "/" + sdk
            let target = try Folder(path: sdkPath).sourceFileInProject()
            targetFiles.append(contentsOf: target)
        }
        return targetFiles
    }
    
    // app 模式下的文件
    func gatherIn(appPath: String) throws -> [File] {
        // 根据指定目录获取
        let targetFiles = try Folder(path: appPath).sourceFileInProject()
        return targetFiles
    }
}

extension ProjectSourceFiles{
    // 使用递归的方法将  [["A","B"], ["C","D"]] 形式的数组转换成
    // A/C, A/D, B/C, B/D
    func dfs(dep: Int, original: [[String]], input: [String], output: inout [String]) {
        if dep == original.count {
            output.append(input.reduce("") { return $0 + "/" + $1 } )
            return
        }
        for cc in original[dep] {
            if dep != original.count {
                var nextCur = input
                nextCur.append(cc)
                dfs(dep: dep + 1, original: original, input: nextCur, output: &output)
            }
        }
    }
    // 另一种思路解决上面提到的路径转换问题
    func someMethod(original: [[String]]) -> [String] {
        var relativePaths = [String]()
        // 获取可能构成的路径总数量
        let total = original.reduce(1) { (result, element) -> Int in
            result * element.count
        }
        // 构建数组,将每个 part 的元素内容扩充为 total 个, 不足的部分直接重复自身即可
        let result = original.map { (element) -> Array<String> in
            let elementNum = element.count
            let copyNum = total / elementNum
            if copyNum > 1 {
                var newElement = [String]()
                for _ in 0..<copyNum {
                    newElement.append(contentsOf: element)
                }
                return newElement
            } else {
                return element
            }
        }
        // 遍历新数组构建总路径
        for index in 0..<total {
            var path = ""
            for part in 0..<result.count{
                path.append(result[part][index])
                path.append("/")
            }
            relativePaths.append(path)
        }
       return relativePaths
    }
}

