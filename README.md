# FocusPulse

专注计时 + 每日时间统计，一款极简的 iOS 专注力工具。

## 功能

- 自由模式专注计时，按分类记录每次专注
- 自动生成当日时间分布饼图
- 日历热力图，回顾专注历史
- 自定义专注分类
- 导出 CSV 数据
- 灵动岛与锁屏实时活动，计时进度抬手可见

## 系统要求

- iOS 17.0+
- Xcode 16.0+

## 构建

```bash
# 1. 生成 Xcode 项目
xcodegen generate

# 2. 用 Xcode 打开并运行
open FocusPulse.xcodeproj
```

## 项目结构

```
Sources/
  App/            # 应用入口、依赖注入
  Core/
    Domain/       # 业务逻辑：计时引擎、统计聚合、实时活动
    Data/         # SwiftData 持久化：模型、仓库
  Presentation/   # SwiftUI 界面：主页、计时器、统计、分类
  Resources/      # Assets、图标
  Widget/         # 灵动岛 & 锁屏小组件
Tests/            # 单元测试
Support/          # Info.plist
```

## 技术栈

- Swift 6.0
- SwiftUI
- SwiftData
- 零第三方依赖

## 许可证

MIT
