# 删除右栏快捷入口页设计

## 背景

当前右栏依次包含“明日天气”“快捷入口”“音频播放器”三页。快捷入口页只提供 Bilibili 跳转。用户确认删除该整页，并彻底移除 Bilibili 入口，使音频播放器成为新的右栏第二页。

## 目标

- 右栏只保留“明日天气”和“音频播放器”两页。
- 从明日天气页向左滑动一次即可进入音频播放器。
- 进入新的第二页时刷新 HomeInfoClock 音频目录。
- 页码指示器只显示两个圆点。
- 删除 Bilibili 快捷入口从 Flutter UI 到 Android 平台通道的全部实现和测试桩。

## 非目标

- 不修改音频目录、播放队列或四种播放模式。
- 不修改后台、熄屏、媒体通知或前台音频服务。
- 不恢复任何右栏自动回页机制。
- 不修改左栏、中央 PageView、定时器、旋钮或精简模式动画。
- 不改写记录旧实现过程的历史设计和计划文档；本规格取代其中与当前右栏结构冲突的产品约束。

## 结构变更

### 右栏

`DashboardRightPanel` 的标题、页面和指示器统一缩减为两个元素：

1. 明日天气
2. 音频播放器

`_handlePageChanged` 在 `page == 1` 时调用 `AudioPlayerController.refreshLibrary()`。页面停留行为保持不变，不新增计时器或自动导航。

`DashboardRightPanel` 不再接收 `onOpenBilibili`，`HomeClockScreen` 也不再向右栏传递该回调。

### Bilibili 功能清理

删除以下不再有消费者的实现：

- `QuickActionsPanel` 组件文件。
- `HomeController.openBilibili()`。
- `PlatformGateway.openBilibili()` 和 `PlatformService.openBilibili()`。
- Android MethodChannel 的 `openBilibili` 分支及原生启动方法。
- 仅为该功能存在的测试计数器、测试用例和 `QUERY_ALL_PACKAGES` 权限。

清理相关无用导入，但不触碰音频文件夹打开逻辑使用的 Android Intent。

## 状态与数据流

- 初始页索引仍为 `0`，标题显示“明日天气”。
- 用户左滑一次后索引变为 `1`，标题显示“音频播放器”。
- 索引变为 `1` 时异步刷新媒体库；刷新失败仍由现有 `AudioPlayerController` 和音频页错误状态处理。
- 等待任意时长都不会改变当前页。

## 测试策略

先修改测试并确认其在旧三页实现上按预期失败：

- 一次左滑后必须显示音频播放器并触发一次媒体库扫描。
- 指示器必须只有索引 `0`、`1` 两个圆点，不存在索引 `2`。
- 页面中不存在“快捷入口”和 `bilibili-open-button`。
- 音频页停留超过旧的 20 秒阈值后仍保持选中。
- 平台接口、控制器和 Android 契约测试不再要求 Bilibili 通道。

随后完成最小实现并运行相关聚焦测试、完整 Flutter 测试、静态分析和 APK 构建。

## 验收标准

- 真机右栏只显示两页，一次左滑进入音频播放器。
- Bilibili 入口及底层专用代码完全不存在。
- 音频播放器仍可扫描、播放并在后台或熄屏状态持续工作。
- 右栏不会自动回到明日天气页。
- 自动化测试、静态分析和 Android debug APK 构建全部通过。
