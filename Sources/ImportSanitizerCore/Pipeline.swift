//
//  Pipeline.swift
//  ImportSanitizerCore
//
//  Created by SketchK on 2020/11/3.
//

import Foundation
import ArgumentParser
import Files

public enum FixMode: String, ExpressibleByArgument {
    case sdk            //修复组件的源码
    case app            //修复组件的 demo 工程
    case shell          //修复壳工程下面 pods 目录里的内容
}

public final class Pipeline {
    let podfilePath: String        // 必须传入的参数
    let mode: FixMode              // 必须传入的参数
    let targetPath: String         // 可选的参数
    let patchFilePath: String?
    let specialPods: [String]?
    
    public init(podfilePath: String,
                mode: FixMode,
                targetPath: String,
                patchFilePath: String?,
                specialPods: String?) throws {
        self.podfilePath = podfilePath
        self.mode = mode
        self.targetPath = targetPath
        self.patchFilePath = patchFilePath
        // 对 ignorePods 的原始值进行处理
        if mode == .shell,
           let value = specialPods?.trimmingCharacters(in: .whitespaces).split(separator: ",") {
            self.specialPods = value.map{ String($0) }
        } else {
            self.specialPods = nil
        }
    }
    
    public func run() throws {
        print("\(SeperateLine.normal.rawValue) generate map table begin \(SeperateLine.normal.rawValue)")
        // 获取 header 的映射表
        var mapTable = try HeaderMapTable.init(podfile: self.podfilePath,
                                               ignorePods: self.specialPods)
        // 增加注入映射表的能力
        if let path = self.patchFilePath {
            try mapTable.updateWith(path)
        }
        // 诊断映射表自身存在的问题
        mapTable.doctor()
        print("\(SeperateLine.normal.rawValue) generate map table end \(SeperateLine.normal.rawValue)")

        print("\(SeperateLine.normal.rawValue) search source file begin \(SeperateLine.normal.rawValue)")
        // 获取 source file 的目录
        let sourceFiles = try ProjectSourceFiles.init(targetPath: targetPath,
                                                      mode: mode,
                                                      specailPods: self.specialPods)
        print("\(SeperateLine.normal.rawValue) generate source file end \(SeperateLine.normal.rawValue)")

        print("\(SeperateLine.normal.rawValue) sanitizer begin \(SeperateLine.normal.rawValue)")
        // 修复头文件引用问题
        let sanitizer = Sanitizer(reference: mapTable,
                                  mode: mode,
                                  target: sourceFiles)
        // 根据 special pods 决定是否开启 write 模式
        var needWrite = true
        if let pods = self.specialPods, pods.count > 0 {
            needWrite = false
        }
        try sanitizer.scan(needWrite: needWrite)
        print("\(SeperateLine.normal.rawValue) sanitizer end \(SeperateLine.normal.rawValue)")        
    }
}





