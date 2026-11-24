# 待办提醒（todo-reminder）

一款 Flutter 编写的跨端待办事项提醒 App，支持 Android、iOS 和 Windows。以「按天」为视角记录待办，到点弹窗提醒，并可通过 Supabase 账号在手机与电脑之间同步数据。

## 下载安装

在 [Releases](https://github.com/skdfndh/todo-reminder/releases/latest) 下载：

- Windows x64：解压 `todo-reminder-windows-x64.zip`，运行其中的 `todo_reminder.exe`。若系统提示缺少运行库，请安装 [Microsoft Visual C++ 运行库（x64）](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)。
- Android：选择 `app-arm64-v8a-release.apk`（多数现代手机）、`app-armeabi-v7a-release.apk`（32 位设备）或 `app-x86_64-release.apk`（部分模拟器）。

首次打开即可离线使用。获准的云端账号可在「设置 → 登录云端账号」登录。

> 安装时如提示「未知来源」请允许；首次打开请允许「通知」和「精确闹钟」权限，否则到点无法准时提醒。
> 安装过旧版本后再次打开，App 会自动检测 GitHub 上的新版本并引导更新，确认后直接下载安装，无需手动重新下载。
> 正式签名版（v1.3.0 起）后续版本可在 App 内直接更新；若手机装的是 v1.3.0 之前的旧版本，请先卸载再安装，否则升级会提示「签名不一致」。

## 功能

- **按天视图**：首页重点展示「今天」的待办，未来待办折叠为「未来待办」缩略，可逐日翻看、点日期跳转；每天午夜 0 点自动跨天。
- **精确提醒**：提醒精确到「几点几分」，App 关闭/后台也能弹窗（本地通知）。
- **四种重复**：一次性 / 每天 / 每周（可勾选多个星期几）/ 每月（可选几号）。
- **时间窗口**：重复任务可设「开始日期 / 结束日期」，窗口内提醒、到期自动停。
- **打勾完成**：每个待办都能打勾；重复任务打勾只标记当天，跨天自动复位。
- **统计完成天数**：可开关，开启后累计显示「已完成 N 天」。
- **统计中心**：按全部时间、本月或近 30 天查看每日、每周、每月和常用模板的设立、完成与完成率。
- **重要性涂色**：低（蓝灰）/ 中（橙黄）/ 高（红）三档，卡片框内按重要性涂色。
- **排序与置顶**：可在「按时间 / 重要性优先」间切换，支持手动置顶；可让已完成自动排在未完成下面。
- **应用内更新**：打开旧版自动检测 GitHub 上的新版本，弹窗展示新旧版本号与更新内容，确认后按设备架构下载安装。
- **本地优先**：SQLite 存储，断网仍可查看和编辑；登录后自动同步到个人云端空间。
- **粘贴文字导入**：从一段通知提取事项、提交要求和截止时间，在新建页核对后保存。

## 技术栈

| 用途 | 依赖 |
|------|------|
| 框架 | Flutter 3.x + Dart 3 |
| 本地通知 | `flutter_local_notifications` |
| 时区处理 | `timezone` + `flutter_timezone` |
| 本地存储 | `sqflite`（SQLite） |
| Windows SQLite | `sqflite_common_ffi` |
| 状态管理 | `flutter_riverpod` |
| 账号与云同步 | `supabase_flutter` |
| 应用内更新 | `dio` + `package_info_plus` + `device_info_plus` + `open_filex` |

## 快速开始

```bash
flutter pub get
flutter run                 # 连接真机或模拟器后运行
flutter test                # 单元测试
flutter build apk --debug   # 打包调试版 APK
flutter build apk --release # 打包 release（需先配置签名）
```

## 云端同步配置

1. 在 Supabase 新建项目，在 SQL Editor 中执行 [`supabase/schema.sql`](supabase/schema.sql)。
2. 复制 `supabase.example.json` 为 `supabase.json`，填入项目 Connect 页面中的 Project URL 和 Publishable key。`supabase.json` 已忽略，不会提交密钥。
3. 使用配置启动或构建：

```bash
flutter run -d windows --dart-define-from-file=supabase.json
flutter run -d android --dart-define-from-file=supabase.json
flutter build windows --dart-define-from-file=supabase.json
```

在 Supabase 管理后台创建并验证允许同步的账号。用于个人同步时，关闭公开注册，并为 `public.user_snapshots` 添加限制性策略，把读写范围限定为该账号的 UID。

两端在设置中登录同一账号后，会在启动和返回应用时同步。本机修改后会尝试上传，两端同时修改时以最后一次成功上传的完整数据为准。云端下载将替换本机待办前，应用会先备份本机已有记录。自动备份文件名以 `todo-reminder-before-sync-` 开头，可从应用的文档目录找到，并通过「设置 → 导入备份」恢复。

APK 产物位于 `build/app/outputs/flutter-apk/`。

> 首次运行会请求「通知」和「精确闹钟」权限，两个都允许才能保证到点准时提醒。

## 项目结构

```text
lib/
├── main.dart                     # 入口：初始化通知、DB、ProviderScope
├── theme.dart                    # 暖纸手账配色
├── models/task.dart              # Task 模型 + RepeatType/Priority 枚举 + 时间计算
├── utils/
│   ├── schedule.dart             # 下一次提醒时间的纯函数
│   ├── version.dart              # 语义版本比较（应用内更新用）
│   ├── abi.dart                  # ABI 匹配 APK 资产（应用内更新用）
│   └── routes.dart               # 统一页面过渡
├── data/
│   ├── database.dart             # SQLite 建库、迁移
│   └── task_repository.dart      # CRUD
├── services/
│   ├── notification_service.dart # 本地通知调度、权限、取消、重排
│   └── update_service.dart       # 检查更新：拉取 release、比较版本、下载
├── providers/task_providers.dart # Riverpod 状态 + 排序 + 打勾/置顶/跨天 + 更新
├── screens/
│   ├── home_screen.dart          # 按天视图首页
│   ├── task_edit_screen.dart     # 新建/编辑表单
│   └── settings_screen.dart      # 排序设置
└── widgets/
    ├── task_tile.dart            # 待办卡片
    ├── update_dialog.dart        # 更新弹窗与下载进度
    └── pressable_scale.dart      # 按压反馈
```

## 说明

- **通知权限**：Android 13+ 请求通知权限，Android 14+ 请求「精确闹钟」权限；被拒时降级为非精确调度（可能延迟几分钟）。
- **正式签名**：发布版用固定 release keystore 签名（本地 `android/key.properties` + GitHub Secrets），保证应用内更新可无缝升级。
- **desugaring**：`flutter_local_notifications` v22 需要 core library desugaring，已在 `android/app/build.gradle.kts` 配置，请勿删除。

## 许可

[MIT](LICENSE) © 2026 kddsk
