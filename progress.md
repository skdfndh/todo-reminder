# 待办提醒（todo-reminder）开发进度

> 最后更新：2026-08-26
> 仓库：https://github.com/skdfndh/todo-reminder（私有）

## 项目概述

一款纯本地的待办事项提醒 App，Flutter 编写，支持 Android / iOS。以「按天」为视角记录待办、到点弹窗提醒，无需后端、无需登录，数据全部存在手机本地 SQLite。

---

## 开发流程（时间线）

### 第一阶段：需求与方案确认（2026-08-25）
- 明确核心诉求：记录待办、精确到「几点几分」提醒、一次性 / 每天重复、本地通知、纯本地存储、无需登录。
- 确认技术栈 **Flutter**，采用**本地通知**（`flutter_local_notifications`）+ **SQLite**（`sqflite`）+ **Riverpod**。
- 与现有 `daily-qa` 项目**完全独立**，从零开始。

### 第二阶段：环境搭建（2026-08-25）
- 本机原本只有 JDK 25，先后安装：
  - Flutter SDK → `C:\flutter`（3.47.1 / Dart 3.13.1，加入用户 PATH）
  - Android SDK → `C:\Android\Sdk`（cmdline-tools + platform-tools + platforms;android-36）
- 配置中国镜像（`PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL`）与本地代理（`127.0.0.1:7890`）。

### 第三阶段：核心功能 v1（2026-08-25）
- 数据层：Task 模型 + SQLite（v1 建表）+ CRUD 仓库。
- 通知层：初始化、权限请求、一次性/每天/每周/每月调度、全量重排。
- 状态层 + UI：首页列表、新建/编辑表单、任务卡片。
- 踩坑并解决：`flutter_local_notifications` v22 需要 core library desugaring；JDK 25 下 Kotlin 增量编译失败（禁用增量编译）。
- 验证：`flutter analyze` 0 问题、单元测试通过、打出首个 debug APK。

### 第四阶段：功能扩展 v1.1（2026-08-25 ~ 08-26）
按用户确认的新需求扩展：
- **按天视图**：首页重点展示「今天」，未来待办折叠，逐日翻看，午夜 0 点自动跨天。
- **打勾**：所有待办可打勾；重复任务打勾只标记当天、跨天复位。
- **统计完成天数**：可开关，累计显示「已完成 N 天」（只存总数）。
- **时间窗口**：重复任务可设开始/结束日期。
- **重要性涂色**：低（蓝灰）/ 中（橙黄）/ 高（红）三档，卡片框内涂色。
- **排序 + 置顶**：可切换「按时间 / 重要性优先」，支持手动置顶。
- **UI 重构**：按 frontend-design 技能确定「暖纸手账」风格（米白纸底 + 暖墨字 + 三色优先级）。
- 数据库迁移到 v2（`ALTER TABLE` 保留旧数据）。

### 第五阶段：Git / GitHub / CI（2026-08-26）
- 初始化 git 仓库（分支 `main`），写规范 README。
- 创建私有仓库并推送源码（79 个文件，`build/`、`local.properties` 等生成物正确排除）。
- 打包 release 版 APK（按 ABI 拆分：arm64 18.2MB / armeabi-v7a 15.6MB / x86_64 19.6MB）。
- 发布 **Release v1.0.0**，挂载 3 个 APK。
- 配置 **GitHub Action**（`.github/workflows/release.yml`）：推送 `v*` 标签自动测试 + 打包 + 发 Release。
- 把本地代理配置从仓库 `gradle.properties` 移到本机 `~/.gradle/gradle.properties`，避免破坏 CI。

---

## 已完成功能清单

| 功能 | 说明 |
|------|------|
| 按天视图 | 「今天」重点展示，未来折叠，逐日翻看，午夜 0 点跨天 |
| 精确提醒 | 精确到几点几分，App 关闭/后台也能弹窗（本地通知） |
| 四种重复 | 一次性 / 每天 / 每周（多选星期几）/ 每月（选几号） |
| 时间窗口 | 重复任务可设开始/结束日期，到期自动停 |
| 打勾完成 | 所有待办可打勾；重复任务当天打勾、跨天复位 |
| 统计完成天数 | 可开关，累计显示「已完成 N 天」 |
| 重要性涂色 | 低/中/高三档，卡片框内按重要性涂色 |
| 排序与置顶 | 按时间 / 重要性优先可切换，支持手动置顶 |
| 纯本地存储 | SQLite，无需账号 |

---

## 技术栈

| 用途 | 技术 |
|------|------|
| 框架 | Flutter 3.47.1 + Dart 3.13.1 |
| 本地通知 | `flutter_local_notifications` v22 |
| 时区 | `timezone` + `flutter_timezone` |
| 存储 | `sqflite`（SQLite） |
| 状态管理 | `flutter_riverpod` |

## 项目结构

```text
lib/
├── main.dart                     # 入口：初始化通知、DB、ProviderScope
├── theme.dart                    # 暖纸手账配色
├── models/task.dart              # Task 模型 + RepeatType/Priority 枚举 + 时间计算
├── utils/schedule.dart           # 下一次提醒时间的纯函数
├── data/
│   ├── database.dart             # SQLite 建库、迁移
│   └── task_repository.dart      # CRUD
├── services/notification_service.dart
├── providers/task_providers.dart # 状态 + 排序 + 打勾/置顶/跨天
├── screens/{home,task_edit,settings}_screen.dart
└── widgets/task_tile.dart
test/{schedule_test,task_test}.dart
.github/workflows/release.yml
```

## 数据库 Schema（v2）

`tasks` 表字段：`id, title, note, repeat_type, remind_hour, remind_minute, date, weekdays, day_of_month, enabled, priority, pinned, statistics_enabled, start_date, end_date, done_today, done_date, done_count, created_at, updated_at`

## 构建与发布

| 项 | 值 |
|----|-----|
| 仓库 | https://github.com/skdfndh/todo-reminder（私有） |
| Release | v1.0.0（3 个 APK） |
| CI | 推送 `v*` 标签自动构建 + 发 Release |
| 验证命令 | `flutter analyze` / `flutter test` / `flutter build apk` |

---

## 已知技术坑（勿删相关配置）

- `flutter_local_notifications` v22 需要 core library desugaring（`android/app/build.gradle.kts`）。
- JDK 25 下 Kotlin 增量编译缓存关闭失败 → `kotlin.incremental=false`（`android/gradle.properties`）。
- 本地代理已移至 `~/.gradle/gradle.properties`，仓库内无代理配置，CI 不受影响。

---

## 待完善内容（TODO）

### 功能类（高优先级）
- [ ] **提前 N 分钟提醒**：新建时可选「提前 X 分钟」。
- [ ] **完成进度显示**：配合「统计完成天数」，支持目标天数 + 进度条 / 百分比。
- [ ] **通知点按跳转**：点击通知进入对应待办详情。
- [ ] **贪睡 / 稍后提醒**：到点后可选「稍后 X 分钟再提醒」。

### 功能类（中优先级）
- [ ] **深色模式**：在暖纸手账基础上补一套深色配色。
- [ ] **数据备份 / 导出**：SQLite 导出/导入，换机迁移。
- [ ] **分类 / 标签**：给待办打标签并按标签筛选。
- [ ] **搜索**：按标题/备注搜索。

### 工程类
- [ ] **正式签名**：当前 release 用 debug 签名，只能自装；上架需 keystore + GitHub Secrets。
- [ ] **Widget / 集成测试**：目前只有纯逻辑单元测试，缺界面测试。
- [ ] **iOS 构建验证**：Windows 上未验证 iOS 端（需 Mac）。
- [ ] **多语言（i18n）**：目前仅中文。
- [ ] **图标 / 启动图**：替换默认 Flutter 图标。

---

## 当前状态

代码功能完整可用：`flutter analyze` 0 问题、17 个单元测试通过、debug/release APK 均可打包。剩余主要是功能增强与工程化完善，见上方 TODO。
