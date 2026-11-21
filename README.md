# 晨读美文 · HarmonyOS 本地音频播放器

一个专注「晨读 / 精听」场景的本地音频播放器：**全离线**，支持**从系统文件管理器导入音频**、
**自定义分组**、**批量管理**、**自定义应用背景**、**锁屏/后台播放**、**睡眠定时**与 **A-B 复读**，
适配 HUAWEI Pura X Max（折叠屏展开自动变「左列表 + 右播放器」双栏，合起为单栏 + 悬浮药丸播放条）。

> **版本**：0.1.0（`versionCode` 1000000）
> **构建状态**：编译 / 签名 / 真机启动均通过（DevEco Studio 26.0.0.865 + SDK 7.0 / API 26）
> **应用不内置任何音频**，首次进入为空列表，由用户自行导入。

---

## 一、功能

| 模块 | 说明 |
| --- | --- |
| 音频导入 | 右上角「+ 导入」拉起系统文件选择器，多选 `.mp3 / .m4a / .wav / .aac / .flac / .ogg / .opus`，文件复制进应用沙箱 |
| 自定义分组 | 「设置 → 管理分组」浮层可新增 / 重命名 / 删除分组；删除时组内音频回到默认分组 |
| **批量管理** | 「设置 → 批量管理」进入多选态：点卡片勾选、顶部「全选 / 完成」、底部「移动到分组 / 删除」，删除有二次确认 |
| **自定义背景** | 「设置 → 应用背景」选择相册图片（复制到沙箱）或恢复默认；图片全屏铺底 + 模糊 + 半透明蒙版（0.25） |
| **设置页** | 头部「设置」打开统一设置面板：播放（自动连播 / 倍速 / 睡眠定时）、外观（深色模式 / 背景）、音频库（导入 / 分组 / 批量）、关于（版本、数量） |
| **深色模式** | 跟随系统 / 始终浅色 / 始终深色；全部界面色值走颜色资源，esources/dark 提供深色配色，切换即时生效 |
| 音频列表 | 首字母色块、标题、所属分组、时长；点一下播放，再点暂停；长按可移动分组 / 删除 |
| 搜索 | 按音频名称关键词实时过滤 |
| 分组筛选 | 「全部 N」+ 各分组胶囊，显示每组数量 |
| 迷你播放条 | 悬浮药丸：渐变底 + 光晕、标题/分组/时间、文字区内的进度线、播放键、下一首 |
| 全屏播放器 | 拖动进度、上一首/下一首、−10s/+10s、0.75–1.75 倍速、自动连播、睡眠定时、A-B 复读 |
| **睡眠定时** | 关 / 15′ / 30′ / 45′ / 60′，到点自动暂停，实时显示剩余分钟 |
| **A-B 复读** | 点 `A` 记起点、点 `B` 记终点，播到 B 自动跳回 A；换音频自动清除 |
| **锁屏 / 耳机控制** | AVSession：锁屏、通知中心、蓝牙耳机可 播放/暂停/上一首/下一首/拖动进度 |
| **后台播放** | 长时任务（AUDIO_PLAYBACK），切后台或锁屏继续播 |
| **沉浸式全屏** | 状态栏/导航栏透明、内容延伸到屏幕边缘，并按安全区避让（顶部标题、底部播放条不遮挡） |
| 折叠屏适配 | 宽度 ≥ 600vp 双栏，否则单栏 |
| 续播 | 记住上次音频与位置（Preferences） |
| 动画 | 列表淡入上移、选中色渐变、播放柱跳动、封面/按键缩放、弹层滑入 |

### 数据存放

| 数据 | 位置 |
| --- | --- |
| 音频文件 | 沙箱 `filesDir/audio/t<时间戳>_<序号>.<ext>` |
| 背景图片 | 沙箱 `filesDir/bg/background.<ext>` |
| 音频索引 / 分组 | `preferences('reading_lib')` → `tracks` / `groups`（JSON 字符串） |
| 背景路径 | `preferences('reading_theme')` → `bgPath` |
| 上次播放 | `preferences('reading_store')` → `lastId` / `lastPos` |

> `picker` 返回的 uri 只有临时权限，冷启动后失效，因此导入时立即复制到沙箱，后续都读沙箱副本。

---

## 二、UI 结构

```
Stack（全屏，含自定义背景层）
├── 背景 Image（模糊 24）+ rgba(244,246,250,0.25) 蒙版
├── 列表区
│   ├── 头部：晨读美文 / 设置 · +导入（选择态替换为「已选 N 项 / 全选 / 完成」）
│   ├── 搜索框
│   ├── 分组胶囊（横向滚动）
│   └── 音频列表（大屏时右侧同时显示播放器）
├── 迷你播放条（悬浮药丸）/ 批量操作栏（选择态）
├── 全屏播放器（底部滑入，单栏时）
├── 设置面板（底部滑入，92% 高度）
│   ├── 播放：自动连播 / 倍速 / 睡眠定时
│   ├── 外观：深色模式（跟随系统 / 浅色 / 深色）、应用背景（选择图片 / 恢复默认）
│   ├── 音频库：导入音频 / 管理分组 / 批量管理
│   └── 关于：应用、版本、数量
└── 分组管理浮层（淡入 + 上移）
```

图标全部使用系统 `SymbolGlyph`（`sys.symbol.play_fill` / `pause` / `forward_end_fill` / `backward_end_fill` / `checkmark`）。

---

## 三、工具链与构建

```
D:\Huawei\DevEcoStudio\              DevEco Studio 26.0.0.865
D:\Huawei\Sdk\hos\26.0.0\            SDK（ets / js / native / previewer / toolchains）
default-workspace\toolchain\hvigor-home\   hvigor 缓存
```

双击 **`build.bat`**，或命令行：

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

产物：

- `entry\build\default\outputs\default\entry-default-signed.hap`（已签名，可安装）
- `entry\build\default\outputs\default\entry-default-unsigned.hap`（未签名）
- 对外分发用的未签名包：`dist\MorningReading-0.1.0-unsigned.hap`

安装与启动：

```powershell
hdc install -r entry\build\default\outputs\default\entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.example.morningreading
```

> 签名：`build-profile.json5` 的 `signingConfigs` 为自动生成的调试证书，
> `products[0]` 必须写 `"signingConfig": "default"`，否则只产出 unsigned HAP。

---

## 四、配置要点（踩过的坑）

```json5
"products": [{
  "name": "default",
  "compileSdkVersion": "26.0.0",
  "compatibleSdkVersion": "26.0.0",
  "targetSdkVersion": "26.0.0",
  "runtimeOS": "OpenHarmony",
  "signingConfig": "default"
}]
```

- API 26 起版本号必须是**字符串** `"26.0.0"`（10–25 才是数字）；
- `entry/build-profile.json5` 的 `apiType` 必须是 `stageMode`；
- `hvigor/hvigor-config.json5` 需要 `dependencies` 与 `modelVersion: "6.0.0"`；`oh-package.json5` 同样；
- `module.json5` 的 `deviceTypes` 用 `"default"`；
- 后台播放需要 `ohos.permission.KEEP_BACKGROUND_RUNNING`（已声明，安装即授予）；
- 文件/图片选择器无需申请读文件权限；
- 版本号在 `AppScope/app.json5`：`versionName` 已设为 `0.1.0`，`versionCode` 仍保留 1000000（避免降级无法覆盖安装）。

---

## 五、关键实现

### 1. 导入音频（picker → 沙箱 → fd 播放）

```ts
const viewPicker = new picker.DocumentViewPicker(ctx);
const uris: string[] = await viewPicker.select({
  maxSelectNumber: 20,
  fileSuffixFilters: ['音频|.mp3,.m4a,.wav,.aac,.flac,.ogg,.opus']
});
const src = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
fs.copyFileSync(src.fd, dest);       // dest = filesDir + '/audio/xxx.mp3'
fs.closeSync(src);
```

播放：`player.url = 'fd://' + fs.openSync(path, fs.OpenMode.READ_ONLY).fd`

### 2. 音频库 / 分组 / 批量（`common/Library.ets`）

- 单例 `LibraryStore` 持有 `groups` / `tracks`，写回 `preferences` 后 `AppStorage('libVersion')++`；
- UI 用 `@StorageLink('libVersion')` 触发重建；
- 批量接口 `moveTracks(ids, groupId)` / `removeTracks(ids)` 一次持久化；
- 启动时用 `fs.accessSync` 清理沙箱中已不存在的条目。

### 3. 自定义背景（`common/BackgroundStore.ets`）

`PhotoViewPicker` 选图 → 复制到 `filesDir/bg` → 记 `bgPath` → `AppStorage('bgVersion')++`；
页面顶层渲染 `Image(...).blur(24)` + 蒙版，透明度在 `pages/Index.ets` 中调整。

### 4. 沉浸式全屏与安全区

```ts
win.setWindowLayoutFullScreen(true);
win.setWindowSystemBarProperties({
  statusBarColor: '#00000000',
  navigationBarColor: '#00000000',
  statusBarContentColor: '#1B2A41',
  navigationBarContentColor: '#1B2A41'
});
```

页面用 `getWindowAvoidArea(TYPE_SYSTEM / TYPE_NAVIGATION_INDICATOR)` 取上下避让高度，
列表顶部、迷你条/操作栏底部、浮层底部各加对应 padding，避免被状态栏或手势条压住。
（系统手势指示条本身属于系统 UI，应用无法隐藏。）

### 5. 后台播放 + 锁屏控制

```ts
const s = await avSession.createAVSession(ctx, 'morning-reading', 'audio');
s.on('play' / 'pause' / 'playNext' / 'playPrevious' / 'seek', ...);
await s.setLaunchAbility(wantAgent);
await s.activate();
await backgroundTaskManager.startBackgroundRunning(
  ctx, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, wantAgent);
```

元数据/播放状态用 `setAVMetadata` / `setAVPlaybackState` 同步（进度 1 秒节流）；
暂停、播完、切歌都会 `stopBackgroundRunning`。

> **自动连播与后台的配合**：一首播完（`completed`）时若 `autoNext` 为真，**不要先停长时任务**——
> 任务一停进程就会被系统挂起，后续 `reset() → prepare() → play()` 会中断，表现为「后台播完不自动下一首」。
> 正确做法是保持任务与 AVSession 的播放态，直接载入下一首；只有关闭自动连播时才上报暂停并停止任务。

### 6. 睡眠定时 / A-B 复读

```ts
this.sleepTimer = setTimeout(() => this.pause(), minutes * 60 * 1000);

// timeUpdate
if (this.bMs > this.aMs && this.aMs > 0 && time >= this.bMs) { this.seekTo(this.aMs); }
```

### 7. 深色模式（`common/ThemeStore.ets`）

- 界面所有颜色改为资源引用：`$r('app.color.bg_page')`、`text_primary`、`accent` 等；
- `resources/base/element/color.json` 为浅色，`resources/dark/element/color.json` 同名覆盖；
- 三档：`system`（跟随系统）/ `light` / `dark`，通过 `getApplicationContext().setColorMode(...)` 切换，
  资源与组件即时重绘；状态栏/导航栏图标颜色同步切换（深色用白图标）；
- 选择存 `preferences('reading_theme')` 的 `themeMode`，UI 用 `@StorageLink('themeMode')` 订阅。

---

## 六、目录结构

```
MorningReading/
├── AppScope/
│   ├── app.json5                      # versionName 0.1.0
│   └── resources/base/media/app_icon.png
├── build-profile.json5                # signingConfigs + product.signingConfig
├── build.ps1 / build.bat
├── dist/MorningReading-0.1.0-unsigned.hap
├── hvigorfile.ts / oh-package.json5
├── hvigor/hvigor-config.json5
└── entry/
    ├── build-profile.json5
    └── src/main/
        ├── module.json5               # KEEP_BACKGROUND_RUNNING
        ├── ets/
        │   ├── entryability/EntryAbility.ets   # 沉浸式全屏 + 系统栏透明
        │   ├── common/Library.ets              # 音频库 / 分组 / 批量 / 导入 / 持久化
        │   ├── common/BackgroundStore.ets      # 自定义背景
        │   ├── common/ThemeStore.ets           # 深色模式（system / light / dark）
        │   ├── common/AudioService.ets         # 播放 / 会话 / 长时任务 / 续播 / 定时 / 复读
        │   ├── view/MiniPlayer.ets             # 悬浮药丸迷你条
        │   ├── view/PlayerPanel.ets            # 全屏播放器
        │   ├── view/GroupManager.ets           # 分组管理浮层
        │   ├── view/SettingsPanel.ets          # 设置面板（播放 / 外观 / 音频库 / 关于）
        │   ├── view/PlayingBars.ets            # 播放中跳动柱
        │   └── pages/Index.ets                 # 列表 / 搜索 / 筛选 / 批量 / 背景 / 布局
        └── resources/
            ├── base/element/color.json         # 浅色配色（bg_page / bg_card / accent …）
            ├── dark/element/color.json         # 深色配色（同名覆盖）
            ├── base/media/  base/profile/
            └── rawfile/                        # 空（不内置音频）
```

---

## 七、常见问题

**1. 导入后看不到音频**：确认后缀在支持列表内（单次最多 20 个，可多次导入），失败会 toast 提示。

**2. 点音频没声音**：过滤 HiLog 中的 `ReadingAudio` / `Library`；确认文件仍在沙箱（换机/清数据后索引会自动剔除失效条目）。

**3. 背景图不显示**：仅支持 png / jpg / jpeg / webp / bmp；恢复默认后 `bgPath` 置空。

**4. 后台被系统杀掉**：检查 `KEEP_BACKGROUND_RUNNING` 是否被删；并在系统设置里允许该应用后台活动。

**5. 后台播完不自动下一首**：见「关键实现 · 后台播放」的说明——`completed` 时若自动连播为开，不能先 `stopBackgroundRunning`，
否则进程被挂起导致下一首无法 prepare/play。若仍复现，看 HiLog 中 `ReadingAudio` 的 `play failed` 日志。

**6. 底部/顶部出现白条**：确认 `EntryAbility` 中 `setWindowLayoutFullScreen(true)` 与透明系统栏生效；系统手势条本身无法隐藏。

**7. 编译报 `Cannot find the corresponding SDK version`**：`DEVECO_SDK_HOME` 指向 `D:\Huawei\Sdk\hos`。

**8. 编译报 `spawn java ENOENT`**：把 `D:\Huawei\DevEcoStudio\jbr\bin` 加入 PATH（`build.ps1` 已处理）。

**9. 安装报签名/系统不匹配**：product 缺少 `"signingConfig": "default"` 时只会出 unsigned HAP；设备为 HarmonyOS 时可将 `runtimeOS` 改为 `"HarmonyOS"` 后重新签名。

---

## 八、如何新增功能

### 加播放器控件

1. `AudioService` 加方法（写 `AppStorage`）；
2. `PlayerPanel` / `MiniPlayer` 加 `@StorageLink` + 控件；
3. `build.bat` 验证。

### 换图标

把对应位置的 `$r('sys.symbol.xxx')` 换掉即可，如 `play_fill`、`pause`、`forward_end_fill`、`backward_end_fill`、`goforward_10`、`checkmark`。

### 加音频来源（如媒体库）

在 `LibraryStore.importUris` 旁新增方法，复制到 `filesDir/audio` 后 push 到 `this.tracks`，再 `persist()` + `bump()`。
