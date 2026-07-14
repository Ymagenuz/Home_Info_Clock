# Flutter 重构收尾清理与主分支整合设计

## 背景

Flutter 重构已完成并通过当前阶段验收。历史设计、计划、交接文档以及旧 Java/Web 参考实现已经完成使命，继续保留会干扰后续维护和自动化执行。用户要求暂停删除右栏第二页，先保存清理前边界，再彻底清理文档与无生产用途的代码，验证后提交并汇入 `master`，最后移除 `.worktrees/flutter-rebuild`。

## 清理前边界

- 当前功能代码已提交，音频播放器提交为 `f014a9c`。
- 本设计文档形成清理前的第一笔新提交。
- 未跟踪的 `docs/superpowers/plans/2026-07-14-remove-right-shortcut-page.md` 不进入清理前提交。
- 已暂停的“删除右栏第二页”不执行；快捷入口和 Bilibili 功能保持现状。

## Markdown 清理

最终项目树不保留任何 Markdown 文件。删除范围包括：

- 根目录 `README.md`。
- `docs/` 下的当前方向、构建说明、历史设计与计划。
- `legacy/` 中的 Android 说明。
- 已跟踪的 `.superpowers/**/*.md`。
- 当前工作树中被忽略的 `.superpowers/sdd/*.md` 临时简报、报告、审查包和交接记录。
- 本设计文档与后续临时实施计划本身。

Git 历史仍保留这些文档的旧版本，但合并后的工作树不再包含它们。

## 遗留实现清理

删除不参与当前 Flutter Android 产品构建的完整遗留树：

- `legacy/native-android/`
- `web/`
- 根目录 `clock.html`

这些内容仅用于重构参考或旧 Web 原型，不是 Flutter Android 的构建输入。

## 无用 Dart 代码与依赖

以 `lib/main.dart` 为生产入口的导入图审计确认，以下文件不可达且无生产消费者：

- `lib/services/qweather_weather_source.dart`
- `lib/widgets/metric_cell.dart`

同时删除：

- `test/services/qweather_weather_source_test.dart`
- `AppConfig` 中全部 QWeather 构造参数、环境变量、字段与辅助 getter
- 仅验证“生产未接入 QWeather”的冗余源码断言测试
- `cryptography` 直接依赖及相关锁文件条目
- 没有任何源码引用的 `wakelock_plus` 直接依赖及相关锁文件条目

保留 UAPI、Open-Meteo、AI 建议、AI/中国手动位置、音频、天气回退、定时器和所有当前可达 UI 代码。

## 验证

清理后必须完成：

1. 重新解析 Flutter 依赖并确认锁文件与 `pubspec.yaml` 一致。
2. 生产入口导入图不存在新的不可达 Dart 文件。
3. 完整 Flutter 测试通过。
4. `dart analyze` 无问题。
5. `git diff --check` 无错误。
6. Android debug APK 构建成功。

删除的 QWeather 专用测试不再计入测试总数；其余功能测试必须继续通过。

## 提交、合并与工作树退出

1. 在 `codex/flutter-rebuild` 创建第二笔清理提交，包含全部删除、配置精简、测试调整和锁文件更新。
2. 确认 `D:\test\Home_Info_Clock` 的 `master` 工作树保持干净。
3. 在主工作树中使用快进合并将 `master` 移动到 `codex/flutter-rebuild` 的清理提交，不推送远端。
4. 在 `master` 上重新运行完整测试、静态分析和 APK 构建。
5. 验证 `.worktrees/flutter-rebuild` 的解析路径确实位于 `D:\test\Home_Info_Clock\.worktrees\` 后，移除该工作树并清理工作树注册。
6. 删除已经合并的 `codex/flutter-rebuild` 分支。

最终日常开发目录为 `D:\test\Home_Info_Clock`，分支为 `master`。

## 验收标准

- 最终工作树不存在 Markdown、旧 Java/Web 原型、QWeather 实现、`MetricCell`、`cryptography` 或 `wakelock_plus`。
- 右栏第二页与 Bilibili 保持不变。
- Flutter 测试、分析和 Android APK 构建通过。
- `master` 包含完整 Flutter 重构与清理提交。
- `.worktrees/flutter-rebuild` 和 `codex/flutter-rebuild` 不再存在。
