# ImportSanitizer

## 开发背景

在 iOS 的工程文件中，我们经常会看到开发者使用各种姿势引用其他组件，例如 `#import "A.h"`, `#import <A.h>` 和 `#import "A/A.h"`，这些写法较 `#import <A/A.h>` 来说都是非标准写法，同时也会带来许多问题：

1. 非标准写法会造成项目的 `search path` 变得冗长，进而引起编译耗时加剧，在极端情况下，字段过长还会触发无法编译的问题。
2. 在开启 Clang Module 后，非标准写法无法享受新特性的福利加持，对编译速度有一定影响。

为了解决这些问题，ImportSanitizer 诞生了！

**它是一款能够帮助开发者自动修复工程头文件引用方式的 CLI 工具**，简单，高效，全能的它会让你爱不释手！

## 使用说明

### 命令行工具安装

* 在 Github 上下载项目源码
* 编译工程，生成二进制文件并移动至 bin 目录下
* 修改可执行文件权限

```swift
$ swift build --configuration release
$ cp -f .build/release/importsanitizer /usr/local/bin/importsanitizer
$ cd /usr/local/bin
$ sudo chmod -R 777 importsanitizer
```

### 支持的业务场景

1. sdk 模式：用于修复组件内部的头文件引用问题，例如 AFNetworking 的组件源码
2. app 模式：用于修复示例工程的头文件引用问题，例如 AFNetworking 的 demo 工程源码
3. shell 模式：用于修复壳工程的头文件引用问题，例如全部二进制化后的工程项目中 PODS 目录下的源码

### 使用前的准备

1. 使用前请保证安装了 cocoapods 并执行 `pod install`
2. 确保整个目录拥有读写权限，如果不确定请在工程目录下执行 `chmod -R 777 .` 命令获取相应权限
3. 针对 sdk 模式，需要额外的一步操作，即将 `podspec` 文件转换为 json 文件，并确保两个文件在同一路径下！

```shell
$ pod ipc spec LibraryName.podspec >> LibraryName.podspec.json
```

### 核心用法

使用示例如下

```shell
$ importsantizer x/x/podfile -m sdk -t 'x/x/a.podspec.json'
```

第一个参数为 podfile 文件的路径，用于确认整个头文件与索引的映射表
第二个参数为 CLI 工具的工作模式，可以输入的值为 sdk, shell, app
第三个参数为需要修改的文件路径

  * 在 sdk 模式下，为 `podspec.json` 的路径，因为需要通过 podspec 的 `source_file` 字段确定源文件的路径
  * 在 shell 模式下，为 PODS 目录的路径
  * 在 app 模式想，为示例工程目录的路径

### 进阶功能

> 简单来说，这个进阶功能是指通过加载本地文件中的映射关系来改变头文件修复规则！

在实际调研过程中，我们发现了不同的组件还存在不少同名头文件的情况，针对这种情况，转换工具是无法识别开发者意图的，进而就无法修改头文件的引用方式，取而代之的是文字警告，内容如下：

```shell
? NOTE: A.h belong to [A, AA, AAA], developer should fix manually!
? NOTE: B.h belong to [B, BB, BBB], developer should fix manually!
```

无论你是组件开发者，还是组件使用者，当遇到组件迁移的场景，例如 `A.h` 从 `AA` 迁移到 `A` 的时候，ImportSanitizer 就可以帮你节省不少时间与经历，通过本地添加映射规则，我们可以改变转换的规则，让我们举个简单的例子!

在本地文件中，生成一个 json 文件，它的名字为 `MapTablePatch.josn`，里面的内容如下

```json
[
  {
    "name":"A.h",
    "pod":"A"
  },
  {
    "name":"B.h",
    "pod":"B"
  }
]
```

然后在执行脚本的时候增加 `-p` 参数

```
$ importsantizer x/x/podfile -m sdk -t 'x/x/a.podspec.json' -p 'x/x/MapTablePatch.json'
```

通过这个文件，即使 `A.h` 在 A, AA, AAA 三个组件中都存在，在实际的转换过程中，也只会生成 `#import <A/A.h>` 的引用方式

当然这个功能也不仅限于组件迁移的场景，在组件升级和组件解耦的场景下也是有用武之地的！

### help 文档

```
USAGE: import-sanitizer <podfile-path> --mode <mode> --target-path <target-path> [--patch-file-path <patch-file-path>] [--verbose]

ARGUMENTS:
  <podfile-path>          The path of '.podfile' file, which help this
                          application to make a map table between header files
                          and sdk through 'PODS' directory 

OPTIONS:
  -m, --mode <mode>       Used to determine the operation of the application,
                          you can pass 'sdk', 'app', 'shell' to this argument.
                          In sdk mode, this tool will fix files underge
                          podspes's `source_file` path, In app mode, this tool
                          will fix files in your app's path, adn In shell mode,
                          this tool will fix files in 'PODS' path 
  -t, --target-path <target-path>
                          Some infomation about target file, which should be
                          fixed. In sdk mode, this value should be
                          podspec.json's path(podspec and podspecjson should be
                          same path), In app mode, this value shoulde be your
                          demo's path, and In shell mode, this value should be
                          equal to PODS dir path 
  -p, --patch-file-path <patch-file-path>
                          Ues this patch file to update header map table 
  -v, --verbose           Print status updates while sanitizing. 
  -h, --help              Show help information.
```

## 原理

整个脚本工具的原理十分简单，受靛青同学的启发，整个工具的工作原理如下

1. 通过 `PODS` 目录建立头文件与组件的映射表，这一映射是后续头文件转换的参考信息
2. 通过 podspec 或者其他文件信息，确认需要修改的文件全集
3. 参考第 1，2 步收集的信息，通过正则匹配的方式对文件里的头文件引用语句进行转换，统一变为 `#import <A/A.h>` 的方式

## Q & A

1. 为什么我的头文件没有被修复，还报错了
  * 请检查组件所在文件夹内是否具有读写权限，如果没有，请执行 `chmod -R 777 .` 获取权限
  * 是否确保了 podspec 和 podspec.json 文件在同一路径下
  * 请检查参数是否都符合预期，具体细节请重新阅读**核心用法**的内容

2. 为什么找不到 podspec.json 文件？
  * 这个文件需要开发者手动生成，具体命令为 
  ```shell
  $ pod ipc spec LibraryName.podspec >> LibraryName.podspec.json
  ```

3. 为什么 MapTablePatch.json 文件没有生效？
  * 检查命令行是否输入了 -p 及相关路径
  * json 文件的格式是否符合要求，以下为参考示例
  ```json
  [
    {
      "name":"A.h",
      "pod":"A"
    },
    {
      "name":"B.h",
      "pod":"B"
    }
  ]
  ```
