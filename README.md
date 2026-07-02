# simplibook

simplibook是一款纯本地、轻量化的个人收支记账 Android APP。项目使用 Flutter 开发，账单数据保存在手机本地 SQLite 数据库中，不上传云端，也不包含任何网络请求。

当前正式发行版：`v2.0.0`

GitHub Release：`v2.0.0`

## 功能范围

- 快速记账：收入/支出切换、金额正数校验、两级分类联动、时间选择、备注保存
- 账单列表：今日、本周、本月、自定义时间筛选，支持按收支类型和一级分类过滤
- 账单维护：单条账单查看、编辑、删除，删除前二次确认
- 分类管理：收入/支出分类独立管理，一级分类和二级子类支持新增、修改、删除
- 数据保护：有关联账单的分类禁止删除，避免历史账单分类异常
- 数据统计：累计收入、累计支出、历史净结余、月度趋势折线图、支出分类饼图
- 备份恢复：导出 Excel、导出 JSON、导入 JSON 恢复、清空账单二次确认
- 系统适配：深色/浅色模式自适应，竖屏锁定，适配 Android 和小米澎湃 OS

## 隐私说明

simplibook只在本机存储数据：

- 不注册账号
- 不上传账单
- 不接入云同步
- 不编写网络请求
- 导出的 Excel/JSON 文件由用户自行保存和管理

## 技术栈

- Flutter / Dart
- sqflite / SQLite
- fl_chart
- path_provider / path
- excel
- file_picker
- permission_handler

## 项目结构

```text
lib/
  constants/       默认分类模板
  data/            SQLite 数据库、备份服务、数据变更通知
  models/          分类、账单、统计模型
  screens/         5 个底部 Tab 页面
  utils/           金额、日期、弹窗等通用工具
android/           Android 工程与打包配置
```

## 本地构建

先安装 Flutter 稳定版，并把 `flutter/bin` 加入系统 PATH。

```powershell
flutter doctor
flutter pub get
flutter analyze
flutter build apk --release
```

Release APK 输出位置：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 小米手机安装

1. 将 `app-release.apk` 传到手机。
2. 打开安装包，并允许“安装未知来源应用”。
3. 首次使用导入/导出时，按系统提示授权本地文件访问权限。

## v2.0.0 Release 说明

- 首个正式发行版，对应 `V2.0` 分支
- 应用名称确定为 `simplibook`
- 修复导入 JSON 备份时坏文件可能导致流程中断的问题
- 优化数据变更刷新逻辑，新增、编辑、删除、导入、清空后相关页面自动更新
- 精简 Android 存储权限声明，保留本地导入导出能力
- 优化分类管理小屏幕操作区，降低按钮拥挤风险
- 优化统计饼图图例显示，避免分类较多时布局溢出
- 清理 Git 忽略规则，避免上传 IDE 配置、本地 SDK 路径和内存转储文件
- 补充 Gradle wrapper 与 `pubspec.lock`，提高构建可复现性

## 已知说明

- 当前版本定位为个人本地使用，不包含云同步、多端同步和登录体系。
- JSON 恢复会替换当前全部账单，操作前建议先导出现有 JSON 备份。
- 重置默认分类在已有账单时会被禁止，这是为了保护历史账单数据关联。
