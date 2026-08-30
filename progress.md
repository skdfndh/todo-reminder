# 待办提醒（todo-reminder）开发进度

> 最后更新：2026-08-26
> 仓库：https://github.com/skdfndh/todo-reminder（公开）

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

### 第六阶段：应用内更新 + UI 细节优化（2026-08-26）
- **应用内更新**：启动时异步请求 GitHub 公开 API 的 `releases/latest`，与本地版本比较，有新版本则弹窗；确认后按设备 ABI（`device_info_plus`）选对应 APK，`dio` 带进度下载，`open_filex` 唤起系统安装器。异常一律静默，不打扰用户。
- 主 `AndroidManifest.xml` 补 `INTERNET`（此前 release 构建无联网权限，是本功能的前提）与 `REQUEST_INSTALL_PACKAGES`。
- UI 细节优化：首页「回到今天」改为直接跳回今天（不再弹日历）；新建待办选择重要性时圈内不再显示勾号；设置新增「已完成排后面」开关，已完成的自动排在未完成下面。
- 新增 `version.dart`（语义版本比较）、`abi.dart`（ABI 匹配资产）纯函数工具及其单测。

### 第七阶段：UI 动效打磨 + 正式签名（2026-08-26）
- **UI 动效打磨**（按 emil-design-eng 框架）：按钮/卡片按压反馈（`PressableScale`，scale 0.97）；打勾勾号淡入动画；统一页面过渡（`fadeSlideRoute`，进 250ms / 出 150ms）；切换日期列表淡入；卡片暖阴影；所有动效尊重系统「减少动画」。
- **更新弹窗优化**：展示新旧版本号、更新内容，并提示先打开网络代理再点击更新。
- **统计中心**：支持按全部时间、本月、近 30 天汇总每日、每周、每月和常用模板的完成情况；常用模板新建任务会保留来源关联，供后续准确统计。
- **正式签名**：生成固定 release keystore（`android/app/upload-keystore.jks`，gitignore），密码存本地 `android/key.properties` + GitHub Secrets；`build.gradle.kts` 与 `release.yml` 改用正式签名，本地与 CI 构建签名一致。
- 修复应用内更新「签名不一致」：此前 CI 每次随机生成 debug 签名导致版本间无法覆盖安装；配置固定 keystore 后统一。
- 发布 **Release v1.3.0**。

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
| 已完成排后面 | 设置开关，已完成的自动排在未完成下面 |
| 应用内更新 | 启动检测 GitHub 新版本，展示新旧版本号与内容，按 ABI 下载安装 |
| UI 动效打磨 | 按压反馈、打勾动画、统一页面过渡、日期切换淡入 |
| 正式签名 | 固定 keystore 签名，应用内更新可无缝升级 |
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
| 应用内更新 | `dio` + `package_info_plus` + `device_info_plus` + `open_filex` |

## 项目结构

```text
lib/
├── main.dart                     # 入口：初始化通知、DB、ProviderScope
├── theme.dart                    # 暖纸手账配色
├── models/task.dart              # Task 模型 + RepeatType/Priority 枚举 + 时间计算
├── utils/
│   ├── schedule.dart             # 下一次提醒时间的纯函数
│   ├── version.dart              # 语义版本比较（纯函数）
│   ├── abi.dart                  # ABI 匹配 APK 资产（纯函数）
│   └── routes.dart               # 统一页面过渡
├── data/
│   ├── database.dart             # SQLite 建库、迁移
│   └── task_repository.dart      # CRUD
├── services/
│   ├── notification_service.dart # 本地通知调度、权限、取消、重排
│   └── update_service.dart       # 检查更新：拉取 release、比较版本、下载
├── providers/task_providers.dart # 状态 + 排序 + 打勾/置顶/跨天 + 更新检查
├── screens/{home,task_edit,settings}_screen.dart
└── widgets/{task_tile,update_dialog,pressable_scale}.dart
test/{schedule_test,task_test,version_test,abi_test}.dart
.github/workflows/release.yml
```

## 数据库 Schema（v2）

`tasks` 表字段：`id, title, note, repeat_type, remind_hour, remind_minute, date, weekdays, day_of_month, enabled, priority, pinned, statistics_enabled, start_date, end_date, done_today, done_date, done_count, created_at, updated_at`

## 构建与发布

| 项 | 值 |
|----|-----|
| 仓库 | https://github.com/skdfndh/todo-reminder（公开） |
| Release | v1.5.0（3 个 APK） |
| CI | 推送 `v*` 标签自动构建 + 发 Release |
| 验证命令 | `flutter analyze` / `flutter test` / `flutter build apk` |

---

## 已知技术坑（勿删相关配置）

- `flutter_local_notifications` v22 需要 core library desugaring（`android/app/build.gradle.kts`）。
- JDK 25 下 Kotlin 增量编译缓存关闭失败 → `kotlin.incremental=false`（`android/gradle.properties`）。
- 本地代理已移至 `~/.gradle/gradle.properties`，仓库内无代理配置，CI 不受影响。
- GitHub API 对缺失 `User-Agent` 的请求直接 403，`update_service.dart` 已显式设置。
- 主 `AndroidManifest.xml` 必须保留 `INTERNET` 权限，否则 release 构建无联网能力，应用内更新会失败。
- release 使用固定 keystore 签名：keystore 文件与 `android/key.properties` 已 gitignore，CI 通过 GitHub Secrets（`KEYSTORE_BASE64` / `KEYSTORE_PASSWORD`）注入；**密钥丢失会导致无法再给新版签名**，务必备份。

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
- [ ] **清理 open_filex 附带权限**：上架商店前移除其合并进来的 `READ_MEDIA_*` 等多余存储权限。
- [ ] **Widget / 集成测试**：目前只有纯逻辑单元测试，缺界面测试。
- [ ] **iOS 构建验证**：Windows 上未验证 iOS 端（需 Mac）。
- [ ] **多语言（i18n）**：目前仅中文。
- [ ] **图标 / 启动图**：替换默认 Flutter 图标。

---

## 当前状态

代码功能完整可用：`flutter analyze` 0 问题、28 个单元测试通过、debug/release APK 均可打包；release 使用固定 keystore 正式签名。剩余主要是功能增强与工程化完善，见上方 TODO。

> 仓库已改为公开，应用内更新可用。v1.3.0 起使用正式签名，后续版本可应用内无缝更新；从 v1.3.0 之前的旧版本升级需先卸载重装一次。
