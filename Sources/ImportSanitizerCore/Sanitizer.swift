//
//  Sanitizer.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import Files

struct Sanitizer {
    let reference: HeaderMapTable
    let mode : FixMode
    let target : ProjectSourceFiles
    
    init(reference: HeaderMapTable, mode: FixMode, target: ProjectSourceFiles) {
        self.reference = reference
        self.mode = mode
        self.target = target
    }
    
    func go() throws {
        print("即将开始头文件引用问题的修复")
        for file in self.target.sourceFiles {
            var content = try String(contentsOfFile: file.path)
            let syntaxArray = try self.searchImportSyntax(in: content)
            for syntax in syntaxArray where
                try self.check(importSyntax: syntax, in: file) {
                content = try self.fix(importSyntax: syntax, in: content)
            }
            try file.write(content)
        }
        print("""
        修复结束
        =================================
        """)
    }
    
    func searchImportSyntax(in content: String) throws -> [ImportSyntax] {
        var sentence = [ImportSyntax]()
        // 以 #import 开头, 包含 < > 或者 " " 的写法
        let pattern = "#import.*[<\"](.*?)[\">]"
        let regex = try NSRegularExpression(pattern: pattern,
                                            options: .caseInsensitive)
        let matches = regex.matches(in: content,
                                    options: .reportProgress,
                                    range: NSRange(location: 0, length: content.count))
        // 根据匹配结果获取符合要求的字符串内容
        for match in matches {
            guard let range = Range(match.range, in: content),
                  let syntax = try ImportSyntax(String(content[range])) else {
                continue
            }
            sentence.append(syntax)
        }
        return sentence
    }
}

extension Sanitizer {
    func check(importSyntax: ImportSyntax, in file: File) throws-> Bool {
        var needFix = false
        
        switch importSyntax.type {
        case .unknown:
            needFix = false
        case .guillemetsWithSlash:
            needFix = false
        case .quotationWithSlash:
            needFix = true
        case .noSlash:
            // 1 获取 MapTable 中对应 header 的 pod 名称
            guard let headerName = importSyntax.headerName,
                  let podNames = self.reference.mapTable[String(headerName)]  else {
                // 没有找到相应的头文件信息说明
                // 1. 可能是引用了某些特殊的系统文件 2. 可能是当前组件的源码文件
                return false
            }
            guard podNames.count == 1 else {
                // 说明有同名的头文件, 此时不做修复, 应当提醒开发者手动修改
                print("? NOTE: \(headerName) belong to \(podNames), developer should fix manually!")
                return false
            }
            //2 获取 file 的 pod 名称
            var currentFilePodName = ""
            switch self.mode {
            case .sdk:
                guard let podspec = try self.target.podspecInfo() else {
                    return false
                }
                currentFilePodName = podspec.moduleName ?? podspec.name
            case .shell:
                let filePathComponent = file.path.split(separator: "/")
                guard let podsIndex = filePathComponent.firstIndex(of: "Pods") else {
                    return false
                }
                currentFilePodName = String(filePathComponent[podsIndex + 1])
            case .app:
                currentFilePodName = "Don't need To Check"
            }

            //3 判断 pod 名称是否存在包含关系, 只有不存在包含关系才进行修改
            guard podNames.contains(currentFilePodName) == false else {
                return false
            }
            needFix = true
        }
        
        return needFix
    }

    // 前置检查已经在 check 方法中进行,所以这里可以直接强制拆包进行处理
    func fix(importSyntax: ImportSyntax,
             in content: String) throws -> String {
        var result = content
        let range = NSRange(location: 0, length:result.count)
        switch importSyntax.type {
        case .quotationWithSlash:
            // 将 "XX/XX.h" 的写法变为 <XX/XX.h> 的写法
            let pattern = importSyntax.raw
                .replacingOccurrences(of: "+", with: "\\+")
                .replacingOccurrences(of: "/", with: "\\/")
            let regex = try NSRegularExpression(pattern: pattern,
                                                options: .caseInsensitive)
            let final = importSyntax.prefix!
                    + " <" + importSyntax.info! + ">"
            print("! Error Type is QuotationWithSlash: fix \(importSyntax.raw) to \(final)")
            result = regex.stringByReplacingMatches(in: result,
                                                    options: .reportProgress,
                                                    range: range,
                                                    withTemplate: final)
        case .noSlash:
            // 将 "XX.h" or <XX.h> 的写法变为 <XX/XX.h > 的写法
            let pattern = importSyntax.raw
                .replacingOccurrences(of: "+", with: "\\+")
            let regex = try NSRegularExpression(pattern: pattern,
                                                options: .caseInsensitive)
            let headerName = importSyntax.headerName!
            let podNames = self.reference.mapTable[String(headerName)]!
            let final = importSyntax.prefix!
                        + " <" + podNames.first! + "/" + headerName + ">"
            print("! Error Type is NoSlash: fix \(importSyntax.raw) to \(final)")
            result = regex.stringByReplacingMatches(in: result,
                                                    options: .reportProgress,
                                                    range: range,
                                                    withTemplate: final)
        case .guillemetsWithSlash, .unknown:
            return result
        }
        return result
    }
}
