//
//  HeaderMapTable.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import Files

struct HeaderMapTable {
    let path: String
    let ignorePods: [String]?
    var mapTable = [String: [String]]()
    var count: Int { mapTable.count }

    init(podfile path: String, ignorePods: [String]?) throws {
        self.path = path
        self.ignorePods = ignorePods
        // 核心逻辑: 通过 PODS 目录获取所有 SDK 的名称
        
        // 构建映射
        var mapTable = [String: [String]]()
        // 处理 Pods 的逻辑, 因为 Pods 目录永远与 Podfile 保持同级
        let podsPath = path.replacingOccurrences(
            of: "/Podfile",
            with: "/Pods")
        var sdkNames = try Utility.fetchSDKNames(with: podsPath)
        // 根据 ignorePods 对 mapTabl 进行改造
        if let names = self.ignorePods, names.count > 0 {
            sdkNames.removeAll { names.contains($0) }
        }
        // 通过组件名称构建一个 sdk 路径, 在这个路径下把所有文件名遍历并塞到映射表中
        for sdk in sdkNames {
            let sdkPath = podsPath + "/" + sdk
            let headerFiles = try Folder(path: sdkPath).files.recursive.filter{
                $0.extension == "h" }
            
            for file in headerFiles {
                guard mapTable[file.name] != nil else {
                    mapTable[file.name] = [sdk]
                    continue
                }
                guard mapTable[file.name]?.contains(sdk) == false else {
                    continue
                }
                mapTable[file.name]?.append(sdk)
            }
        }
        self.mapTable = mapTable
        print("""
        当前工程引入的 SDK 数量: \(sdkNames.count)
        映射表的键值对数量有: \(mapTable.count)
        """)
    }
}

extension HeaderMapTable {
    func duplicatedHeadersInfo() -> [String: [String]] {
        return mapTable.filter { $0.value.count > 1 }
    }
    
    func doctor() {
        let duplicatedHeadersInfo = self.duplicatedHeadersInfo()
        guard  !duplicatedHeadersInfo.isEmpty else {
            return
        }
        
        let relatedPods = duplicatedHeadersInfo.reduce(
            Set<String>()) { (relatedPods, info) in
            let (_, pods) = info
            return relatedPods.union(pods)
        }
        
        let duplicatedHeadersMessage = duplicatedHeadersInfo.map {
            (header, pods) -> String in
            "头文件 \(header) 重复，对应仓库有 \(pods.joined(separator: ","))"
        }
        
        print("""
        注意! 该项目依赖的组件存在重名头文件的情况 !!!
        以下为整体情况:
        重名头文件有 \(duplicatedHeadersInfo.count) 个
        涉及的仓库个数为 \(relatedPods.count) 个
        以下为详细情况:
        涉及的仓库有:
        \(relatedPods.joined(separator: ","))
        重名头文件的信息如下:
        """)
        for message in duplicatedHeadersMessage {
            print("\(OutputPrefix.note.rawValue) \(message)")
        }
    }
}

extension HeaderMapTable {
    mutating func updateWith(_ patchFilePath: String) throws {
        let customMapTableInfo = try Utility.fetchCustomMapTable(with: patchFilePath)
        print("根据 patch file 修改了以下头文件的映射关系:")
        for info in customMapTableInfo {
            guard let podsNames = self.mapTable[info.name] else {
                continue
            }
            self.mapTable[info.name] = [info.pod]
            print("\(OutputPrefix.note.rawValue) 将 \(info.name) 的映射关系从 \(podsNames) 变成了 \(info.pod)")

        }
    }
}
