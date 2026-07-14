# 右栏页面保持与真机音频部署 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除右栏全部 20 秒自动回页行为，并把指定 FLAC 部署到 Mi 10 的 HomeInfoClock 音频目录后完成后台与熄屏播放回归验证。

**Architecture:** 右栏只保留用户手势、当前页指示和第三页入场刷新；删除页面层的计时器及播放状态监听，不触碰应用级音频控制器、前台媒体服务或播放器后端。音频文件通过 ADB 原样推送并交给 MediaStore 索引，随后使用现有第三页播放器和 Android 媒体会话做验收。

**Tech Stack:** Flutter/Dart、`flutter_test`、`audio_service`、`just_audio`、Android MediaStore、Gradle、ADB（Mi 10 序列号 `8999948b`）

## Global Constraints

- 彻底移除右栏三页之间的 20 秒自动回页机制；第 2、3 页在任何播放状态下都保持用户选择。
- 保留进入第 3 页时调用 `AudioPlayerController.refreshLibrary()`。
- 不修改左栏、中间主 PageView 锁定、定时器圆环、旋钮、秒针或精简模式动画。
- 不修改音频队列、四种播放模式、媒体通知、Android 前台服务或音频会话。
- 目标文件必须是 `/storage/emulated/0/Music/HomeInfoClock/摇头风扇.flac`，本地源文件 `D:\Temp\摇头风扇.flac` 不得改写或删除。
- 保留现有未提交音频播放器改动，所有实现通过完整验证后再形成一个可构建的最终实现提交。

---

### Task 1: 右栏页面永久保持

**Files:**
- Modify: `test/widgets/dashboard_audio_page_test.dart:47-112`
- Modify: `test/widgets/dashboard_side_panels_test.dart:273-303`
- Modify: `lib/widgets/dashboard_right_panel.dart:36-101`

**Interfaces:**
- Consumes: `DashboardRightPanel.audioController` 与 `AudioPlayerController.refreshLibrary()`。
- Produces: `_handlePageChanged(int page)` 只更新 `_page`，并在 `page == 2` 时刷新媒体库；不存在回页计时器或播放状态监听。

- [x] **Step 1: 写入会失败的页面保持测试**

将旧的 `playing suppresses page reset until playback pauses` 测试替换为：

```dart
testWidgets('right pages remain selected beyond the old reset timeout', (
  tester,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final library = _DashboardAudioLibrary();
  final engine = _DashboardAudioEngine();
  final controller = AudioPlayerController(library: library, engine: engine);
  addTearDown(controller.dispose);
  addTearDown(engine.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardRightPanel(
          weather: null,
          onRefresh: () async {},
          onOpenBilibili: () async {},
          audioController: controller,
        ),
      ),
    ),
  );
  final pages = find.byKey(const ValueKey('home-right-page-view'));

  await tester.drag(pages, const Offset(-300, 0));
  await _pumpPageUntilSettled(tester, pages);
  expect(find.text('快捷入口'), findsOneWidget);
  await tester.pump(const Duration(seconds: 21));
  expect(find.text('快捷入口'), findsOneWidget);

  await tester.drag(pages, const Offset(-300, 0));
  await _pumpPageUntilSettled(tester, pages);
  expect(find.text('音频播放器'), findsOneWidget);
  await tester.pump(const Duration(seconds: 21));
  expect(find.text('音频播放器'), findsOneWidget);
});
```

- [x] **Step 2: 运行测试并确认因旧回页行为失败**

Run:

```powershell
$env:PUB_CACHE='D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
& 'D:\test\flutter\bin\flutter.bat' test --no-pub test\widgets\dashboard_audio_page_test.dart --plain-name 'right pages remain selected beyond the old reset timeout'
```

Expected: FAIL；等待 21 秒后的第一个 `find.text('快捷入口')` 找不到，因为旧代码已经回到“明日天气”。

- [x] **Step 3: 删除回页计时器与专用监听**

`_DashboardRightPanelState` 的相关状态和生命周期收敛为：

```dart
class _DashboardRightPanelState extends State<DashboardRightPanel> {
  late final PageController _pageController = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _page = page);
    if (page == 2) {
      final audioController = widget.audioController;
      if (audioController != null) {
        unawaited(audioController.refreshLibrary());
      }
    }
  }
}
```

删除 `_resetTimer`、`_lastAudioPlaying`、为音频监听而存在的 `initState`/`didUpdateWidget` 代码、`_handleAudioChanged()`、`_schedulePageReset()`，并从 `dispose()` 删除对应清理。`dart:async` 仍由 `unawaited()` 使用，不能删除。

- [x] **Step 4: 运行聚焦测试并确认转绿**

Run:

```powershell
$env:PUB_CACHE='D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
& 'D:\test\flutter\bin\flutter.bat' test --no-pub test\widgets\dashboard_audio_page_test.dart
```

Expected: 所有 `dashboard_audio_page_test.dart` 测试 PASS，且第三页进入时 `library.scanCalls == 1`。

---

### Task 2: 部署真实 FLAC 并清理验证副本

**Files:**
- Read only: `D:\Temp\摇头风扇.flac`
- Device create/replace: `/storage/emulated/0/Music/HomeInfoClock/摇头风扇.flac`
- Device delete: `/storage/emulated/0/Music/HomeInfoClock/Codex_Verify_01.mp3`
- Device delete: `/storage/emulated/0/Music/HomeInfoClock/Codex_Verify_02.mp3`

**Interfaces:**
- Consumes: Android shared storage and MediaStore scanner broadcast.
- Produces: MediaStore 可查询且字节数为 `149754701` 的 `摇头风扇.flac`。

- [x] **Step 1: 确认源文件与设备**

Run:

```powershell
Get-Item -LiteralPath 'D:\Temp\摇头风扇.flac' | Select-Object FullName,Length
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' devices -l
```

Expected: 本地长度 `149754701`；Mi 10 `8999948b` 状态为 `device`。

- [x] **Step 2: 创建目标目录并推送原文件**

Run:

```powershell
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell mkdir -p /sdcard/Music/HomeInfoClock
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b push 'D:\Temp\摇头风扇.flac' '/sdcard/Music/HomeInfoClock/摇头风扇.flac'
```

Expected: `1 file pushed`，命令退出码为 0。

- [x] **Step 3: 触发媒体扫描并核对目标文件**

Run:

```powershell
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file:///sdcard/Music/HomeInfoClock/%E6%91%87%E5%A4%B4%E9%A3%8E%E6%89%87.flac'
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell stat -c %s '/sdcard/Music/HomeInfoClock/摇头风扇.flac'
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell content query --uri content://media/external/audio/media --projection _id:_data:duration:title | Select-String -Pattern '摇头风扇'
```

Expected: 广播完成；手机端长度 `149754701`；MediaStore 输出路径包含 `/storage/emulated/0/Music/HomeInfoClock/摇头风扇.flac`。

- [x] **Step 4: 删除本轮创建的两个临时副本并更新 MediaStore**

Run:

```powershell
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell rm -f /sdcard/Music/HomeInfoClock/Codex_Verify_01.mp3 /sdcard/Music/HomeInfoClock/Codex_Verify_02.mp3
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/HomeInfoClock/Codex_Verify_01.mp3
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Music/HomeInfoClock/Codex_Verify_02.mp3
```

Expected: 目录中只保留用户文件 `摇头风扇.flac`，不再出现两个 `Codex_Verify` 文件。

---

### Task 3: 自动化回归与 APK 构建

**Files:**
- Verify: `lib/widgets/dashboard_right_panel.dart`
- Verify: `test/widgets/dashboard_audio_page_test.dart`
- Verify: `test/widgets/dashboard_side_panels_test.dart`
- Output only: `build/app/outputs/flutter-apk/app-debug.apk`

**Interfaces:**
- Consumes: Task 1 的页面保持实现和当前完整音频播放器改动。
- Produces: 无静态分析问题、全量测试通过且可安装的 debug APK。

- [x] **Step 1: 格式化改动文件**

Run:

```powershell
$env:APPDATA='D:\test\Home_Info_Clock\.worktrees\flutter-rebuild\.dart_tool\appdata'
$env:LOCALAPPDATA='D:\test\Home_Info_Clock\.worktrees\flutter-rebuild\.dart_tool\localappdata'
$env:DART_SUPPRESS_ANALYTICS='true'
& 'D:\test\flutter\bin\cache\dart-sdk\bin\dart.exe' format lib\widgets\dashboard_right_panel.dart test\widgets\dashboard_audio_page_test.dart test\widgets\dashboard_side_panels_test.dart
```

Expected: 三个文件格式化成功。

- [x] **Step 2: 运行完整 Flutter 测试**

Run:

```powershell
$env:PUB_CACHE='D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
& 'D:\test\flutter\bin\flutter.bat' test --no-pub
```

Expected: 全部测试 PASS，包含旋钮/PageView 锁定、倒计时环、秒针逐帧更新、模式淡入淡出和音频播放器测试。

- [x] **Step 3: 运行静态分析与差异检查**

Run:

```powershell
$env:APPDATA='D:\test\Home_Info_Clock\.worktrees\flutter-rebuild\.dart_tool\appdata'
$env:LOCALAPPDATA='D:\test\Home_Info_Clock\.worktrees\flutter-rebuild\.dart_tool\localappdata'
$env:DART_SUPPRESS_ANALYTICS='true'
& 'D:\test\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze
git -c safe.directory=D:/test/Home_Info_Clock/.worktrees/flutter-rebuild diff --check
```

Expected: `No issues found!`；`git diff --check` 无错误。

- [x] **Step 4: 使用已验证的离线官方依赖缓存构建 APK**

Run:

```powershell
& 'C:\Users\10146\.gradle\wrapper\dists\gradle-9.1.0-all\7wzd0jkjit61aq2p43wpjgij9\gradle-9.1.0\bin\gradle.bat' --offline --init-script 'D:\test\Home_Info_Clock\.worktrees\flutter-rebuild\.dart_tool\official-repositories.init.gradle' -p android assembleDebug
```

Expected: `BUILD SUCCESSFUL`，APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。

---

### Task 4: Mi 10 回归、后台验证与最终提交

**Files:**
- Install: `build/app/outputs/flutter-apk/app-debug.apk`
- Commit: 当前音频播放器实现、右栏页面保持实现、测试与本计划文档

**Interfaces:**
- Consumes: Task 2 的真实 FLAC 和 Task 3 的 APK。
- Produces: Mi 10 真机验收证据与一个完整、可构建的实现提交。

- [x] **Step 1: 覆盖安装 APK 并启动**

Run:

```powershell
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b install -r -t 'D:\test\Home_Info_Clock\.worktrees\flutter-rebuild\build\app\outputs\flutter-apk\app-debug.apk'
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell am force-stop com.homepanel.clock
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell am start -n com.homepanel.clock/.MainActivity
```

Expected: 安装输出 `Success`，应用成功启动且无崩溃。

- [x] **Step 2: 人工确认右栏保持与真实 FLAC**

由用户在设备上完成：翻到右栏第 2 页等待超过 20 秒，确认不回页；翻到第 3 页等待超过 20 秒，确认不回页；刷新列表并播放 `摇头风扇.flac`。不得再用 ADB 注入滑动手势。

Expected: 两个页面都保持；列表显示并可播放 `摇头风扇.flac`。

- [x] **Step 3: 验证播放模式、后台、熄屏与媒体会话**

由用户在第三页依次确认单曲循环、顺序播放、列表循环和随机播放；播放中按 HOME，再熄屏。随后只读检查：

```powershell
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell dumpsys media_session | Select-String -Pattern 'com.homepanel.clock|state=PlaybackState' -Context 0,3
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell dumpsys activity services com.homepanel.clock | Select-String -Pattern 'AudioService|foreground' -Context 0,3
& 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe' -s 8999948b shell dumpsys notification --noredact | Select-String -Pattern 'com.homepanel.clock|HomeInfoClock' -Context 0,4
```

Expected: 媒体会话属于 `com.homepanel.clock` 且保持播放状态；`AudioService` 为前台服务；媒体通知存在并可控制播放。

- [x] **Step 4: 审查范围并创建最终实现提交**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock/.worktrees/flutter-rebuild status --short
git -c safe.directory=D:/test/Home_Info_Clock/.worktrees/flutter-rebuild diff --check
git -c safe.directory=D:/test/Home_Info_Clock/.worktrees/flutter-rebuild add -- android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/homepanel/clock/MainActivity.kt lib/app.dart lib/main.dart lib/models/audio_track.dart lib/screens/home_clock_screen.dart lib/services/audio_library_service.dart lib/services/audio_playback_engine.dart lib/services/home_audio_handler.dart lib/services/just_audio_backend.dart lib/state/audio_player_controller.dart lib/widgets/audio_player_page.dart lib/widgets/dashboard_right_panel.dart pubspec.lock pubspec.yaml test/models/audio_playback_mode_test.dart test/services/android_audio_platform_contract_test.dart test/services/audio_app_wiring_test.dart test/services/audio_library_service_test.dart test/services/home_audio_handler_test.dart test/state/audio_player_controller_test.dart test/widgets/audio_player_page_test.dart test/widgets/dashboard_audio_page_test.dart test/widgets/dashboard_side_panels_test.dart test/widgets/home_clock_screen_test.dart docs/superpowers/plans/2026-07-14-right-panel-page-persistence.md
git -c safe.directory=D:/test/Home_Info_Clock/.worktrees/flutter-rebuild diff --cached --check
git -c safe.directory=D:/test/Home_Info_Clock/.worktrees/flutter-rebuild commit -m "feat: add persistent background audio player"
```

Expected: 暂存区不包含 `.dart_tool`、`build`、`.superpowers` 或用户无关文件；提交成功且工作树只剩明确忽略的构建缓存。
