# LUSH记账

纯本地个人收支记账 Flutter APP。账单数据只保存在手机本地 SQLite 数据库中，不包含网络请求。

## 已实现功能

- 快速记账：收入/支出、金额校验、两级分类联动、时间、备注、入库保存
- 账单列表：今日/本周/本月/自定义时间筛选，按收支类型和一级分类筛选，区间汇总，编辑和删除
- 分类管理：收入/支出分类分开管理，一级和二级分类增删改，有账单关联时禁止删除
- 数据统计：累计收入、累计支出、净结余，月度趋势折线图，支出分类饼图
- 设置：导出 Excel、导出 JSON、导入 JSON 恢复、清空账单二次确认
- Android：竖屏锁定，深色/浅色模式自适应，存储权限声明

## 本地编译 APK

当前电脑需要先安装 Flutter 稳定版，并把 `flutter/bin` 加入系统 PATH。

1. 检查环境：

```powershell
flutter doctor
```

2. 如果 Android Gradle wrapper 文件缺失，在本目录执行一次：

```powershell
flutter create --platforms android .
```

执行后保留现有 `lib/`、`pubspec.yaml`、`android/app/src/main/AndroidManifest.xml` 等业务文件。

3. 获取依赖：

```powershell
flutter pub get
```

4. 静态检查：

```powershell
flutter analyze
```

5. 编译 release APK：

```powershell
flutter build apk --release
```

成功后 APK 位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 小米手机安装

1. 将 `app-release.apk` 传到小米手机。
2. 在系统提示中允许“安装未知来源应用”。
3. 安装后首次使用导出/导入功能时，按提示授权本地文件访问权限。

## 重要说明

- 导入 JSON 备份会替换当前全部账单，APP 会弹出二次确认。
- 重置默认分类在已有账单时会被禁止，避免历史账单找不到分类。
- 一键清空账单也会弹出二次确认，清空后不可恢复，建议先导出 JSON 备份。
