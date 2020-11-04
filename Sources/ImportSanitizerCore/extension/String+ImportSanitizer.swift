//
//  String+ImportSanitizer.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation

extension String {    
    func isMatch(pattern: String) throws -> Bool {
        let range = NSRange(location: 0, length: self.count)
        let regexPattern = pattern
        let regex = try NSRegularExpression(pattern: regexPattern,
                                            options: .caseInsensitive)
        let result = regex.matches(in: self,
                                   options: .reportProgress,
                                   range: range)
        // 判断是否存在匹配情况
        return result.count > 0
    }
}
