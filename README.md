# 待办提醒（todo-reminder）

一款纯本地的待办事项提醒 App，Flutter 编写，支持 Android / iOS。以「按天」为视角记录待办，到点弹窗提醒，无需后端、无需登录，数据全部存在手机本地。

## 下载安装

最新版本 APK 见 [Releases](https://github.com/skdfndh/todo-reminder/releases)，按手机 CPU 架构选择：

- [arm64-v8a（大多数现代手机）](https://github.com/skdfndh/todo-reminder/releases/download/v1.0.0/app-arm64-v8a-release.apk)
- [armeabi-v7a（老款 32 位设备）](https://github.com/skdfndh/todo-reminder/releases/download/v1.0.0/app-armeabi-v7a-release.apk)
- [x86_64（模拟器）](https://github.com/skdfndh/todo-reminder/releases/download/v1.0.0/app-x86_64-release.apk)

> 安装时如提示「未知来源」请允许；首次打开请允许「通知」和「精确闹钟」权限，否则到点无法准时提醒。
> 安装过旧版本后再次打开，App 会自动检测 GitHub 上的新版本并引导更新，确认后直接下载安装，无需手动重新下载。

## 功能

- **按天视图**：首页重点展示「今天」的待办，未来待办折叠为「未来待办」缩略，可逐日翻看、点日期跳转；每天午夜 0 点自动跨天。
- **精确提醒**：提醒精确到「几点几分」，App 关闭/后台也能弹窗（本地通知）。
- **四种重复**：一次性 / 每天 / 每周（可勾选多个星期几）/ 每月（可选几号）。
- **时间窗口**：重复任务可设「开始日期 / 结束日期」，窗口内提醒、到期自动停。
- **打勾完成**：每个待办都能打勾；重复任务打勾只标记当天，跨天自动复位。
- **统计完成天数**：可开关，开启后累计显示「已完成 N 天」。
- **重要性涂色**：低（蓝灰）/ 中（橙黄）/ 高（红）三档，卡片框内按重要性涂色。
- **排序与置顶**：可在「按时间 / 重要性优先」间切换，支持手动置顶；可让已完成自动排在未完成下面。
- **应用内更新**：打开旧版自动检测 GitHub 上的新版本，确认后按设备架构下载安装。
- **纯本地**：SQLite 存储，无需账号，换机不自动同步。

## 技术栈

| 用途 | 依赖 |
|------|------|
| 框架 | Flutter 3.x + Dart 3 |
| 本地通知 | `flutter_local_notifications` |
| 时区处理 | `timezone` + `flutter_timezone` |
| 本地存储 | `sqflite`（SQLite） |
| 状态管理 | `flutter_riverpod` |
| 应用内更新 | `dio` + `package_info_plus` + `device_info_plus` + `open_filex` |

## 快速开始

```bash
flutter pub get
flutter run                 # 连接真机或模拟器后运行
flutter test                # 单元测试
flutter build apk --debug   # 打包调试版 APK
flutter build apk --release # 打包 release（需先配置签名）
```

APK 产物位于 `build/app/outputs/flutter-apk/`。

> 首次运行会请求「通知」和「精确闹钟」权限，两个都允许才能保证到点准时提醒。

## 项目结构

```text
lib/
├── main.dart                     # 入口：初始化通知、DB、ProviderScope
├── theme.dart                    # 暖纸手账配色
├── models/
│   └── task.dart                 # Task 模型 + RepeatType/Priority 枚举 + 时间计算
├── utils/
│   └── schedule.dart             # 下一次提醒时间的纯函数
├── data/
│   ├── database.dart             # SQLite 建库、迁移
│   └── task_repository.dart      # CRUD
├── services/
│   └── notification_service.dart # 本地通知调度、权限、取消、重排
├── providers/
│   └── task_providers.dart       # Riverpod 状态 + 排序 + 打勾/置顶/跨天
├── screens/
│   ├── home_screen.dart          # 按天视图首页
│   ├── task_edit_screen.dart     # 新建/编辑表单
│   └── settings_screen.dart      # 排序设置
└── widgets/
    └── task_tile.dart            # 待办卡片
```

## 说明

- **通知权限**：Android 13+ 请求通知权限，Android 14+ 请求「精确闹钟」权限；被拒时降级为非精确调度（可能延迟几分钟）。
- **desugaring**：`flutter_local_notifications` v22 需要 core library desugaring，已在 `android/app/build.gradle.kts` 配置，请勿删除。
- **代理**：`android/gradle.properties` 里配置了本地代理（`127.0.0.1:7890`）供 Gradle 下载依赖，无代理环境可删除这几行。

## 许可

MIT License
