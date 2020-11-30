//
//  ImportSyntax.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import Files

enum ImportSyntaxType {
    case quotationWithSlash         // "A/A.h"
    case noSlash                    // "A.h" or  <A.h>
    case guillemetsWithSlash        // <A/A.h>
    case unknown                    // 未定义类型头文件
}

struct ImportSyntax: CustomStringConvertible {
    var description: String { raw }

    // #import "A/A.h" 为例
    let raw: String                         // #import "A/A.h"
    let prefix: String?                     // #import
    let info: String?                       // A/A.h
    let headerName: String?                 // A
    let podName: String?                    // A.h
    var type = ImportSyntaxType.unknown     // quotationWithSlash
    
    init?(_ raw: String) throws {
        self.raw = raw
        self.type = try ImportSyntax.getImportSyntaxType(self.raw)

        guard let aPrefix = raw.split(separator: " ").first else {
            return nil
        }
        self.prefix = String(aPrefix)
        
        guard let aInfo = raw.split(separator: " ").last?.dropLast().dropFirst() else {
            return nil
        }
        self.info = String(aInfo)
        
        switch type {
        case .quotationWithSlash, .guillemetsWithSlash:
            guard let aPodName = self.info?.split(separator: "/").first,
                  let aheaderName = self.info?.split(separator: "/").last else {
                self.podName = nil
                self.headerName = nil
                return
            }
            self.podName = String(aPodName)
            self.headerName = String(aheaderName)
        case .noSlash:
            self.podName = nil
            self.headerName = self.info
        case .unknown:
            self.podName = nil
            self.headerName = nil
        }
        
    }
}

extension ImportSyntax {
    static func getImportSyntaxType(_ raw: String) throws -> ImportSyntaxType {
        // 匹配 "A/A.h"
        let quotationWithSlashPattern = "#import.*(\")(.*?)/(.*?)(\")"
        // 匹配 "A.h" or  <A.h>
        let noSlashPattern = "#import.*[<\"]([^/]*?)[\">]"
        // 匹配 <A/A.h>
        let guillemetsWithSlashPattern = "#import.*(<)(.*?)/(.*?)(>)"
        
        if try raw.isMatch(pattern: quotationWithSlashPattern) {
            return .quotationWithSlash
        } else if try raw.isMatch(pattern: noSlashPattern)  {
            return .noSlash
        } else if try raw.isMatch(pattern: guillemetsWithSlashPattern) {
            return .guillemetsWithSlash
        } else {
            return .unknown
        }
    }
}
