import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';
import { AudioService } from '../common/AudioService';
import { BackgroundStore } from '../common/BackgroundStore';
import { LibraryStore } from '../common/Library';

const DOMAIN: number = 0x0100;
const TAG: string = 'Settings';
const ACCENT: string = '#1F6FB2';
const INK: string = '#1B2A41';
const SUB: string = '#8A93A6';
const SPEEDS: string[] = ['0.75×', '1.0×', '1.25×', '1.75×'];
const SLEEPS: number[] = [0, 15, 30, 45, 60];

@Component
export struct SettingsPanel {
  @StorageLink('speedIdx') speedIdx: number = 1;
  @StorageLink('autoNext') autoNext: boolean = true;
  @StorageLink('sleepMin') sleepMin: number = 0;
  @StorageLink('sleepEnd') sleepEnd: number = 0;
  @StorageLink('libVersion') libVersion: number = 0;
  @StorageLink('bgVersion') bgVersion: number = 0;
  @State nowMs: number = Date.now();
  @Prop bottomInset: number = 0;
  private ticker: number = -1;
  onClose: () => void = () => {
  };
  onGroups: () => void = () => {
  };
  onBatch: () => void = () => {
  };
  onImport: () => void = () => {
  };

  aboutToAppear(): void {
    this.ticker = setInterval(() => {
      this.nowMs = Date.now();
    }, 1000);
  }

  aboutToDisappear(): void {
    clearInterval(this.ticker);
    this.ticker = -1;
  }

  private trackCount(): number {
    const v: number = this.libVersion;
    if (v < 0) {
      return 0;
    }
    return LibraryStore.get().tracks.length;
  }

  private groupCount(): number {
    const v: number = this.libVersion;
    if (v < 0) {
      return 0;
    }
    return LibraryStore.get().groups.length;
  }

  private bgText(): string {
    const v: number = this.bgVersion;
    if (v < 0) {
      return '默认';
    }
    return BackgroundStore.get().path.length > 0 ? '已自定义' : '默认（纯色）';
  }

  private sleepText(): string {
    const left: number = Math.max(0, Math.ceil((this.sleepEnd - this.nowMs) / 60000));
    return `${left} 分钟后自动暂停`;
  }

  private async pickBackground(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker(ctx);
      const opts: picker.PhotoSelectOptions = {
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const result: picker.PhotoSelectResult = await photoPicker.select(opts);
      if (result.photoUris.length === 0) {
        return;
      }
      const ok: boolean = await BackgroundStore.get().setFromUri(result.photoUris[0]);
      promptAction.showToast({ message: ok ? '背景已更新' : '设置背景失败，请重试' });
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'pick background failed %{public}s', err.message);
      promptAction.showToast({ message: '设置背景失败，请重试' });
    }
  }

  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(SUB)
      .width('100%')
      .padding({ left: 4, top: 6 })
  }

  @Builder
  SpeedChip(label: string, idx: number) {
    Text(label)
      .fontSize(12)
      .fontColor(this.speedIdx === idx ? '#FFFFFF' : '#5B6878')
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(12)
      .backgroundColor(this.speedIdx === idx ? ACCENT : '#F1F4F9')
      .animation({ duration: 180, curve: Curve.EaseOut })
      .onClick(() => {
        AudioService.get().setSpeedIndex(idx);
      })
  }

  @Builder
  SleepChip(label: string, min: number) {
    Text(label)
      .fontSize(12)
      .fontColor(this.sleepMin === min ? '#FFFFFF' : '#5B6878')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(10)
      .backgroundColor(this.sleepMin === min ? '#1F3A5F' : '#F1F4F9')
      .animation({ duration: 180, curve: Curve.EaseOut })
      .onClick(() => {
        AudioService.get().setSleep(min);
      })
  }

  @Builder
  LibRow(title: string, value: string, kind: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor(INK)
      Blank()
      Text(value)
        .fontSize(12)
        .fontColor(SUB)
      Text('›')
        .fontSize(16)
        .fontColor('#C3CBD8')
        .margin({ left: 4 })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .onClick(() => {
      if (kind === 'import') {
        this.onImport();
      } else if (kind === 'groups') {
        this.onGroups();
      } else if (kind === 'batch') {
        this.onBatch();
      }
    })
  }

  build() {
    Column() {
      Row() {
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(INK)
        Blank()
        Text('完成')
          .fontSize(14)
          .fontColor(ACCENT)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 8 })

      Scroll() {
        Column({ space: 10 }) {
          this.SectionTitle('播放')

          Column() {
            Row() {
              Column({ space: 3 }) {
                Text('自动连播下一篇')
                  .fontSize(14)
                  .fontColor(INK)
                Text('当前音频播完后自动播放下一首')
                  .fontSize(11)
                  .fontColor(SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoNext })
                .selectedColor(ACCENT)
                .onChange((isOn: boolean) => {
                  AudioService.get().setAutoNext(isOn);
                })
            }
            .width('100%')
            .padding({ top: 10, bottom: 12 })

            Divider().color('#F0F3F8')

            Column({ space: 8 }) {
              Text('播放速度')
                .fontSize(14)
                .fontColor(INK)
                .width('100%')
              Row({ space: 8 }) {
                ForEach(SPEEDS, (label: string, idx: number) => {
                  this.SpeedChip(label, idx)
                }, (label: string) => label)
              }
              .width('100%')
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })

            Divider().color('#F0F3F8')

            Column({ space: 8 }) {
              Text('睡眠定时')
                .fontSize(14)
                .fontColor(INK)
                .width('100%')
              Row({ space: 8 }) {
                ForEach(SLEEPS, (min: number) => {
                  this.SleepChip(min === 0 ? '关' : `${min}′`, min)
                }, (min: number) => min.toString())
              }
              .width('100%')
              if (this.sleepEnd > 0) {
                Text(this.sleepText())
                  .fontSize(11)
                  .fontColor(SUB)
                  .width('100%')
              }
            }
            .width('100%')
            .padding({ top: 12, bottom: 6 })
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .borderRadius(16)
          .backgroundColor('#FFFFFF')

          this.SectionTitle('外观')

          Column() {
            Row() {
              Column({ space: 3 }) {
                Text('应用背景')
                  .fontSize(14)
                  .fontColor(INK)
                Text(this.bgText())
                  .fontSize(11)
                  .fontColor(SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('选择图片')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(12)
                .backgroundColor(ACCENT)
                .onClick(() => {
                  this.pickBackground();
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })

            if (this.bgVersion >= 0 && this.bgText() === '已自定义') {
              Divider().color('#F0F3F8')
              Text('恢复默认背景')
                .fontSize(14)
                .fontColor('#C1651A')
                .width('100%')
                .padding({ top: 13, bottom: 13 })
                .onClick(() => {
                  BackgroundStore.get().clear();
                  promptAction.showToast({ message: '已恢复默认背景' });
                })
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .borderRadius(16)
          .backgroundColor('#FFFFFF')

          this.SectionTitle('音频库')

          Column() {
            this.LibRow('导入音频', `${this.trackCount()} 首`, 'import')
            Divider().color('#F0F3F8')
            this.LibRow('管理分组', `${this.groupCount()} 个`, 'groups')
            Divider().color('#F0F3F8')
            this.LibRow('批量管理', '多选移动 / 删除', 'batch')
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .borderRadius(16)
          .backgroundColor('#FFFFFF')

          this.SectionTitle('关于')

          Column() {
            Row() {
              Text('应用')
                .fontSize(14)
                .fontColor(INK)
              Blank()
              Text('晨读美文')
                .fontSize(12)
                .fontColor(SUB)
            }
            .width('100%')
            .padding({ top: 13, bottom: 13 })

            Divider().color('#F0F3F8')

            Row() {
              Text('版本')
                .fontSize(14)
                .fontColor(INK)
              Blank()
              Text('0.1.0')
                .fontSize(12)
                .fontColor(SUB)
            }
            .width('100%')
            .padding({ top: 13, bottom: 13 })
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .borderRadius(16)
          .backgroundColor('#FFFFFF')

          Text('音频与背景图片均保存在应用沙箱内，卸载后会被清除')
            .fontSize(11)
            .fontColor('#B9C2CE')
            .margin({ top: 4, bottom: 20 + this.bottomInset })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F5F9')
    .borderRadius({ topLeft: 26, topRight: 26 })
  }
}
