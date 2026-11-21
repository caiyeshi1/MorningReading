import { AudioService } from '../common/AudioService';

const ACCENT: string = '#1F6FB2';
const INK: string = '#1B2A41';
const SUB: string = '#8A93A6';
const SPEEDS: string[] = ['0.75×', '1.0×', '1.25×', '1.75×'];
const SLEEPS: number[] = [0, 15, 30, 45, 60];

@Component
export struct PlayerPanel {
  @StorageLink('curId') curId: string = '';
  @StorageLink('curNo') curNo: number = 0;
  @StorageLink('curTitle') curTitle: string = '';
  @StorageLink('curGroup') curGroup: string = '';
  @StorageLink('playing') playing: boolean = false;
  @StorageLink('pos') pos: number = 0;
  @StorageLink('dur') dur: number = 0;
  @StorageLink('speedIdx') speedIdx: number = 1;
  @StorageLink('autoNext') autoNext: boolean = true;
  @StorageLink('sleepEnd') sleepEnd: number = 0;
  @StorageLink('sleepMin') sleepMin: number = 0;
  @StorageLink('abA') abA: number = 0;
  @StorageLink('abB') abB: number = 0;
  @State dragging: boolean = false;
  @State dragPos: number = 0;
  @State nowMs: number = Date.now();
  private ticker: number = -1;
  @Prop inSheet: boolean = false;
  onClose: () => void = () => {
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

  private sleepText(): string {
    const left: number = Math.max(0, Math.ceil((this.sleepEnd - this.nowMs) / 60000));
    return left > 0 ? `${left} 分钟后自动暂停` : '即将暂停…';
  }

  private titleOf(): string {
    return this.curTitle.length > 0 ? this.curTitle : '还没有音频';
  }

  private badge(): string {
    if (this.curNo > 0) {
      return `${this.curNo}`;
    }
    return '♪';
  }

  private timeText(ms: number): string {
    const total: number = Math.floor(ms / 1000);
    const m: number = Math.floor(total / 60);
    const s: number = total % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  private coverColor(): string {
    const idx: number = this.curNo % 3;
    if (idx === 1) {
      return '#6A4C93';
    }
    if (idx === 2) {
      return '#C1651A';
    }
    return '#1F6FB2';
  }

  @Builder
  RoundButton(isNext: boolean) {
    Stack() {
      if (isNext) {
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(24)
          .fontColor([INK])
      } else {
        SymbolGlyph($r('sys.symbol.backward_end_fill'))
          .fontSize(24)
          .fontColor([INK])
      }
    }
    .width(52)
    .height(52)
    .borderRadius(26)
    .backgroundColor('#F1F4F9')
    .onClick(() => {
      if (isNext) {
        AudioService.get().next();
      } else {
        AudioService.get().prev();
      }
    })
  }

  @Builder
  SkipButton(delta: number) {
    Text(delta > 0 ? '+10s' : '-10s')
      .fontSize(12)
      .fontColor(SUB)
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .borderRadius(12)
      .backgroundColor('#F7F9FC')
      .onClick(() => {
        AudioService.get().seekRelative(delta);
      })
  }

  @Builder
  AbButton(label: string, active: boolean) {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(active ? '#FFFFFF' : '#5B6878')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(10)
      .backgroundColor(active ? '#C1651A' : '#F1F4F9')
      .onClick(() => {
        AudioService.get().setAB(label === 'A' ? 'a' : 'b');
      })
  }

  build() {
    Column() {
      if (this.inSheet) {
        Row() {
          Text('收起')
            .fontSize(13)
            .fontColor(SUB)
            .onClick(() => {
              this.onClose();
            })
          Blank()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14 })

        Row() {
          Blank().width(44).height(5).borderRadius(3).backgroundColor('#D9DFE9')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 2, bottom: 8 })
      }

      Stack() {
        Text(this.badge())
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(this.inSheet ? 132 : 116)
      .height(this.inSheet ? 132 : 116)
      .borderRadius(30)
      .backgroundColor(this.coverColor())
      .scale({ x: this.playing ? 1 : 0.96, y: this.playing ? 1 : 0.96 })
      .animation({ duration: 360, curve: Curve.EaseInOut })
      .margin({ top: this.inSheet ? 6 : 18 })

      Text(this.titleOf())
        .fontSize(this.inSheet ? 20 : 18)
        .fontWeight(FontWeight.Bold)
        .fontColor(INK)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 24, right: 24, top: 14 })

      Text(this.curGroup.length > 0 ? this.curGroup : '未分组')
        .fontSize(12)
        .fontColor(SUB)
        .margin({ top: 6 })

      Slider({
        value: this.dragging ? this.dragPos : this.pos,
        min: 0,
        max: Math.max(this.dur, 1),
        step: 1000
      })
        .width('86%')
        .blockColor(ACCENT)
        .selectedColor(ACCENT)
        .trackColor('#E3E8F0')
        .margin({ top: 18 })
        .onChange((value: number, mode: SliderChangeMode) => {
          this.dragPos = value;
          if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
            this.dragging = true;
          } else {
            this.dragging = false;
            AudioService.get().seekTo(value);
          }
        })

      Row() {
        Text(this.timeText(this.dragging ? this.dragPos : this.pos))
          .fontSize(11)
          .fontColor(SUB)
        Blank()
        Text(this.timeText(this.dur))
          .fontSize(11)
          .fontColor(SUB)
      }
      .width('86%')

      Row({ space: 18 }) {
        this.RoundButton(false)
        this.SkipButton(-10000)

        Stack() {
          if (this.playing) {
            SymbolGlyph($r('sys.symbol.pause'))
              .fontSize(32)
              .fontColor(['#FFFFFF'])
          } else {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(34)
              .fontColor(['#FFFFFF'])
          }
        }
        .width(74)
        .height(74)
        .borderRadius(37)
        .backgroundColor(ACCENT)
        .shadow({ radius: 16, color: 'rgba(31,111,178,0.35)', offsetY: 6 })
        .scale({ x: this.playing ? 1 : 0.94, y: this.playing ? 1 : 0.94 })
        .animation({ duration: 240, curve: Curve.Friction })
        .onClick(() => {
          AudioService.get().toggle();
        })

        this.SkipButton(10000)
        this.RoundButton(true)
      }
      .margin({ top: 22 })

      Row({ space: 8 }) {
        ForEach(SPEEDS, (label: string, idx: number) => {
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
        }, (label: string) => label)
      }
      .margin({ top: 24 })

      Row({ space: 8 }) {
        Text('复读')
          .fontSize(12)
          .fontColor(SUB)
          .width(30)
        this.AbButton('A', this.abA > 0)
        this.AbButton('B', this.abB > 0)
        Text('取消')
          .fontSize(12)
          .fontColor(SUB)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(10)
          .backgroundColor('#F7F9FC')
          .onClick(() => {
            AudioService.get().setAB('clear');
          })
        Blank()
      }
      .width('86%')
      .margin({ top: 16 })

      if (this.abA > 0) {
        Text(this.abB > 0
          ? `A ${this.timeText(this.abA)} → B ${this.timeText(this.abB)}，循环复读中`
          : `A 点 ${this.timeText(this.abA)}，再点 B 设定终点`)
          .fontSize(11)
          .fontColor('#C1651A')
          .margin({ top: 6 })
      }

      Row({ space: 8 }) {
        Text('定时')
          .fontSize(12)
          .fontColor(SUB)
          .width(30)
        ForEach(SLEEPS, (min: number, idx: number) => {
          Text(min === 0 ? '关' : `${min}′`)
            .fontSize(12)
            .fontColor(this.sleepMin === min ? '#FFFFFF' : '#5B6878')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(10)
            .backgroundColor(this.sleepMin === min ? '#1F3A5F' : '#F1F4F9')
            .onClick(() => {
              AudioService.get().setSleep(min);
            })
        }, (min: number) => min.toString())
        Blank()
      }
      .width('86%')
      .margin({ top: 10 })

      if (this.sleepEnd > 0) {
        Text(this.sleepText())
          .fontSize(11)
          .fontColor(SUB)
          .margin({ top: 6 })
      }

      Row() {
        Text('自动连播下一篇')
          .fontSize(13)
          .fontColor('#5B6878')
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.autoNext })
          .selectedColor(ACCENT)
          .onChange((isOn: boolean) => {
            AudioService.get().setAutoNext(isOn);
          })
      }
      .width('86%')
      .margin({ top: 14 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
