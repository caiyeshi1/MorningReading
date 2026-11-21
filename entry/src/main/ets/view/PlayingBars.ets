const ACCENT: Resource = $r('app.color.accent');

const PATTERN: number[][] = [
  [10, 16, 7],
  [16, 8, 14],
  [7, 14, 10]
];

@Component
export struct PlayingBars {
  @Prop active: boolean = true;
  @State phase: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.phase = (this.phase + 1) % PATTERN.length;
    }, 380);
  }

  aboutToDisappear(): void {
    clearInterval(this.timer);
    this.timer = -1;
  }

  private barHeight(idx: number): number {
    return PATTERN[this.phase][idx];
  }

  build() {
    Row({ space: 3 }) {
      Rect()
        .width(3)
        .height(this.barHeight(0))
        .radius(2)
        .fill(ACCENT)
        .animation({ duration: 340, curve: Curve.EaseInOut })
      Rect()
        .width(3)
        .height(this.barHeight(1))
        .radius(2)
        .fill(ACCENT)
        .animation({ duration: 340, curve: Curve.EaseInOut })
      Rect()
        .width(3)
        .height(this.barHeight(2))
        .radius(2)
        .fill(ACCENT)
        .animation({ duration: 340, curve: Curve.EaseInOut })
    }
    .height(18)
    .alignItems(VerticalAlign.Bottom)
    .opacity(this.active ? 1 : 0.35)
  }
}
