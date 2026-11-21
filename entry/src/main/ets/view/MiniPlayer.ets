import { AudioService } from '../common/AudioService';

@Component
export struct MiniPlayer {
  @StorageLink('curId') curId: string = '';
  @StorageLink('curNo') curNo: number = 0;
  @StorageLink('curTitle') curTitle: string = '';
  @StorageLink('curGroup') curGroup: string = '';
  @StorageLink('playing') playing: boolean = false;
  @StorageLink('pos') pos: number = 0;
  @StorageLink('dur') dur: number = 0;
  @Prop bottomInset: number = 0;
  onOpen: () => void = () => {
  };

  private percent(): number {
    if (this.dur <= 0) {
      return 0;
    }
    return Math.min(100, Math.max(0, this.pos * 100 / this.dur));
  }

  private timeText(ms: number): string {
    const total: number = Math.floor(ms / 1000);
    const m: number = Math.floor(total / 60);
    const s: number = total % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  private titleOf(): string {
    return this.curTitle.length > 0 ? this.curTitle : '还没有音频，点右上角导入';
  }

  private badge(): string {
    if (this.curNo > 0) {
      return `${this.curNo}`;
    }
    return '♪';
  }

  private subtitle(): string {
    const group: string = this.curGroup.length > 0 ? this.curGroup + ' · ' : '';
    return `${group}${this.timeText(this.pos)} / ${this.timeText(this.dur)}`;
  }

  build() {
    Row({ space: 12 }) {
      Stack() {
        Text(this.badge())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor('rgba(255,255,255,0.18)')

      Column({ space: 3 }) {
        Text(this.titleOf())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.subtitle())
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.78)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(3)
            .borderRadius(1.5)
            .backgroundColor('rgba(255,255,255,0.24)')
          Row()
            .width(`${this.percent()}%`)
            .height(3)
            .borderRadius(1.5)
            .backgroundColor('#FFFFFF')
            .animation({ duration: 500, curve: Curve.Linear })
        }
        .width('100%')
        .height(3)
        .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        this.onOpen();
      })

      Stack() {
        if (this.playing) {
          SymbolGlyph($r('sys.symbol.pause'))
            .fontSize(20)
            .fontColor(['#1F6FB2'])
        } else {
          SymbolGlyph($r('sys.symbol.play_fill'))
            .fontSize(20)
            .fontColor(['#1F6FB2'])
        }
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor('#FFFFFF')
      .scale({ x: this.playing ? 1 : 0.94, y: this.playing ? 1 : 0.94 })
      .animation({ duration: 220, curve: Curve.Friction })
      .onClick(() => {
        AudioService.get().toggle();
      })

      Stack() {
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .fontSize(20)
          .fontColor(['#FFFFFF'])
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor('rgba(255,255,255,0.16)')
      .onClick(() => {
        AudioService.get().next();
      })
    }
    .width('calc(100% - 24vp)')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(28)
    .linearGradient({
      angle: 135,
      colors: [['#2E86CE', 0.0], ['#1F6FB2', 0.5], ['#1B3A63', 1.0]]
    })
    .shadow({ radius: 24, color: 'rgba(31,111,178,0.5)', offsetY: 6 })
    .margin({ left: 12, right: 12, bottom: 12 + this.bottomInset })
  }
}
