# 晨读美文 · HarmonyOS 本地音频播放器

一个纯离线的 HarmonyOS（ArkTS / ArkUI）音频播放器：把手机里的英语朗读、播客或有声书导入应用，
按自己的分组管理，像「晨读」一样每天按顺序听。

- 无账号、无网络请求，音频只保存在本机应用沙箱
- 顶部列表 + 底部悬浮播放条，展开为完整播放器
- 适配折叠屏：展开时自动变为「左列表 + 右播放器」双栏

> 版本 0.1.0 · 基于 HarmonyOS/OpenHarmony SDK API 26（Stage 模型）

## 下载

- **未签名 HAP（0.1.0）**：[MorningReading-0.1.0-unsigned.hap](https://github.com/caiyeshi1/MorningReading/releases/download/v0.1.0/MorningReading-0.1.0-unsigned.hap)
- 全部版本：[Releases 页面](https://github.com/caiyeshi1/MorningReading/releases)

> 未签名包（`entry-default-unsigned.hap`）不能直接安装，需要先用你自己的证书签名：
> DevEco Studio 的「自动生成签名」或 `hap-sign-tool` 均可。

---

## 功能

| 功能 | 说明 |
| --- | --- |
| 导入音频 | 从系统文件选择器多选导入 mp3 / m4a / wav / aac / flac / ogg |
| 分组管理 | 自定义分组，新增 / 重命名 / 删除；长按音频可移动分组 |
| 批量管理 | 多选后批量移动或删除（删除前二次确认） |
| 搜索与筛选 | 按名称搜索，按分组筛选 |
| 播放控制 | 上一首 / 下一首、±10 秒、0.75×–1.75× 倍速、自动连播 |
| 睡眠定时 | 15 / 30 / 45 / 60 分钟后自动暂停，显示剩余时间 |
| A-B 复读 | 设定 A、B 两点循环播放，适合跟读练习 |
| 锁屏 / 耳机控制 | 锁屏与蓝牙耳机可播放、暂停、切歌、拖动进度 |
| 后台播放 | 切到后台或锁屏后继续播放，并支持自动连播下一首 |
| 自定义背景 | 选择相册图片作为应用背景，可恢复默认 |
| 深色模式 | 跟随系统 / 始终浅色 / 始终深色 |
| 记忆续播 | 下次打开时回到上次的音频与位置 |

---

## 使用说明

1. **导入音频**：首页右上角「+ 导入」→ 选择本地音频文件（可多选）。
   文件会被复制到应用内，原文件删除后仍可播放。
2. **播放**：点列表任意一项开始播放；底部播放条可暂停、切下一首；
   点播放条展开完整播放器，进行拖动进度、倍速、定时、复读等操作。
3. **管理分组**：「设置 → 管理分组」新建分组；长按音频可选择「移到某分组」。
4. **批量处理**：「设置 → 批量管理」，或列表右上「批量」进入多选，勾选后可移动或删除。
5. **个性化**：「设置 → 外观」可切换深色模式、选择自定义背景。

---

## 运行环境

- HarmonyOS NEXT 设备（API 26 及以上），例如 HUAWEI Pura X 系列
- 开发：DevEco Studio 26.x + API 26 SDK

> 应用未声明任何网络权限，所有数据均在本地。

---

## 构建

用 DevEco Studio 打开本工程，在 **File → Project Structure → Signing Configs**
配置自动签名后直接 Run 即可。

命令行构建（需本机已配置 DevEco Studio 与 SDK 环境变量）：

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

产物位于 `entry/build/default/outputs/default/`。

> 仓库中的 `build-profile.json5` **不包含签名配置**，克隆后请按上面步骤自行生成签名证书。

---

## 目录结构

```
MorningReading/
├── AppScope/                 应用级配置与图标
├── entry/
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/ 应用入口、沉浸式窗口
│       │   ├── common/       音频库、播放服务、背景、主题
│       │   ├── view/         迷你播放条、播放器、设置、分组
│       │   └── pages/        首页列表
│       └── resources/        颜色（浅色/深色）、图标
├── build-profile.json5
└── build.ps1 / build.bat
```

---

## 数据存放

| 数据 | 位置 |
| --- | --- |
| 音频文件 | 应用沙箱 `filesDir/audio/` |
| 背景图片 | 应用沙箱 `filesDir/bg/` |
| 音频索引 / 分组 | Preferences `reading_lib` |
| 播放位置 | Preferences `reading_store` |
| 主题设置 | Preferences `reading_theme` |

卸载应用会一并清除以上内容。
