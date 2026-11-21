import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import picker from '@ohos.file.picker';
import promptAction from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';
import { AudioService } from '../common/AudioService';
import { ALL_GROUP_ID, Group, LibraryStore, Track } from '../common/Library';
import { BackgroundStore } from '../common/BackgroundStore';
import { ThemeStore } from '../common/ThemeStore';
import { immersiveDialog, immersiveToast } from '../common/UiMaterial';
import { MiniPlayer } from '../view/MiniPlayer';
import { PlayerPanel } from '../view/PlayerPanel';
import { GroupManager } from '../view/GroupManager';
import { SettingsPanel } from '../view/SettingsPanel';
import { PlayingBars } from '../view/PlayingBars';

const DOMAIN: number = 0x0100;
const TAG: string = 'Index';
const ACCENT: Resource = $r('app.color.accent');
const INK: Resource = $r('app.color.text_primary');
const SUB: Resource = $r('app.color.text_secondary');
const COLORS: Resource[] = [$r('app.color.accent'), $r('app.color.accent_purple'), $r('app.color.accent_orange'), $r('app.color.accent_green'), $r('app.color.accent_red'), $r('app.color.chip_brand')];

@Entry
@Component
struct Index {
  @StorageLink('curNo') curNo: number = 0;
  @StorageLink('curId') curId: string = '';
  @StorageLink('playing') playing: boolean = false;
  @StorageLink('libVersion') libVersion: number = 0;
  @StorageLink('bgVersion') bgVersion: number = 0;

  @State groupId: string = ALL_GROUP_ID;
  @State keyword: string = '';
  @State wide: boolean = false;
  @State showSheet: boolean = false;
  @State showGroups: boolean = false;
  @State showSettings: boolean = false;
  @State avoidTop: number = 0;
  @State avoidBottom: number = 0;
  @State selecting: boolean = false;
  @State selectedIds: string[] = [];

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    AudioService.get().init(ctx);
    BackgroundStore.get().init(ctx);
    ThemeStore.get().init(ctx);
    this.observeWindow();
  }

  onBackPress(): boolean {
    if (this.showSettings) {
      this.showSettings = false;
      return true;
    }
    if (this.showGroups) {
      this.showGroups = false;
      return true;
    }
    if (this.showSheet) {
      this.showSheet = false;
      return true;
    }
    return false;
  }

  observeWindow(): void {
    const ctx = getContext(this) as common.Context;
    window.getLastWindow(ctx).then((win: window.Window) => {
      this.updateInsets(win);
      const prop: window.WindowProperties = win.getWindowProperties();
      this.wide = this.getUIContext().px2vp(prop.windowRect.width) >= 600;
      win.on('windowSizeChange', (size: window.Size) => {
        this.wide = this.getUIContext().px2vp(size.width) >= 600;
        this.updateInsets(win);
      });
    }).catch((err: BusinessError) => {
      this.wide = false;
    });
  }

  private updateInsets(win: window.Window): void {
    try {
      const system: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const indicator: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const topPx: number = Math.max(system.topRect.height, indicator.topRect.height);
      const bottomPx: number = Math.max(system.bottomRect.height, indicator.bottomRect.height);
      this.avoidTop = this.getUIContext().px2vp(topPx);
      this.avoidBottom = this.getUIContext().px2vp(bottomPx);
    } catch (e) {
      this.avoidTop = 0;
      this.avoidBottom = 0;
    }
  }

  private groups(): Group[] {
    const v: number = this.libVersion;
    if (v < 0) {
      return [];
    }
    return LibraryStore.get().groups;
  }

  private activeGroup(): string {
    const list: Group[] = this.groups();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === this.groupId) {
        return this.groupId;
      }
    }
    return ALL_GROUP_ID;
  }

  private visibleTracks(): Track[] {
    const v: number = this.libVersion;
    if (v < 0) {
      return [];
    }
    const lib: LibraryStore = LibraryStore.get();
    const gid: string = this.activeGroup();
    const kw: string = this.keyword.trim().toLowerCase();
    const result: Track[] = [];
    for (let i = 0; i < lib.tracks.length; i++) {
      const item: Track = lib.tracks[i];
      const okGroup: boolean = gid === ALL_GROUP_ID || item.groupId === gid;
      const okKeyword: boolean = kw.length === 0 || item.title.toLowerCase().indexOf(kw) >= 0;
      if (okGroup && okKeyword) {
        result.push(item);
      }
    }
    return result;
  }

  private totalCount(): number {
    const v: number = this.libVersion;
    if (v < 0) {
      return 0;
    }
    return LibraryStore.get().tracks.length;
  }

  private colorOf(groupId: string): Resource {
    const list: Group[] = this.groups();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === groupId) {
        return COLORS[i % COLORS.length];
      }
    }
    return ACCENT;
  }

  private badgeOf(item: Track): string {
    if (item.title.length === 0) {
      return '♪';
    }
    return item.title.substring(0, 1).toUpperCase();
  }

  private timeText(ms: number): string {
    if (ms <= 0) {
      return '--:--';
    }
    const total: number = Math.floor(ms / 1000);
    const m: number = Math.floor(total / 60);
    const s: number = total % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  private bgPath(): string {
    const v: number = this.bgVersion;
    if (v < 0) {
      return '';
    }
    return BackgroundStore.get().path;
  }

  private async importAudio(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const viewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const opts: picker.DocumentSelectOptions = {
        maxSelectNumber: 20,
        fileSuffixFilters: ['音频|.mp3,.m4a,.wav,.aac,.flac,.ogg,.opus']
      };
      const uris: string[] = await viewPicker.select(opts);
      if (uris.length === 0) {
        return;
      }
      const count: number = await LibraryStore.get().importUris(uris);
      if (count > 0) {
        promptAction.showToast({ message: `已导入 ${count} 个音频`, systemMaterial: immersiveToast() });
      } else {
        promptAction.showToast({ message: '导入失败，请重试', systemMaterial: immersiveToast() });
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'import failed %{public}s', err.message);
      promptAction.showToast({ message: '导入失败，请重试', systemMaterial: immersiveToast() });
    }
  }

  private menuFor(item: Track): MenuElement[] {
    const lib: LibraryStore = LibraryStore.get();
    const list: MenuElement[] = [];
    for (let i = 0; i < lib.groups.length; i++) {
      const g: Group = lib.groups[i];
      if (g.id === item.groupId) {
        continue;
      }
      list.push({
        value: `移到「${g.name}」`,
        action: () => {
          lib.moveTrack(item.id, g.id);
        }
      });
    }
    list.push({
      value: '删除音频',
      action: () => {
        this.removeTrack(item);
      }
    });
    return list;
  }

  private isSelected(id: string): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private toggleSelect(id: string): void {
    const next: string[] = [];
    let removed: boolean = false;
    for (let i = 0; i < this.selectedIds.length; i++) {
      if (this.selectedIds[i] === id) {
        removed = true;
      } else {
        next.push(this.selectedIds[i]);
      }
    }
    if (!removed) {
      next.push(id);
    }
    this.selectedIds = next;
  }

  private selectAll(): void {
    const list: Track[] = this.visibleTracks();
    const ids: string[] = [];
    for (let i = 0; i < list.length; i++) {
      ids.push(list[i].id);
    }
    this.selectedIds = ids;
  }

  private enterSelect(firstId: string): void {
    this.selecting = true;
    const ids: string[] = [];
    if (firstId.length > 0) {
      ids.push(firstId);
    }
    this.selectedIds = ids;
  }

  private exitSelect(): void {
    this.selecting = false;
    const empty: string[] = [];
    this.selectedIds = empty;
  }

  private moveMenu(): MenuElement[] {
    const lib: LibraryStore = LibraryStore.get();
    const list: MenuElement[] = [];
    for (let i = 0; i < lib.groups.length; i++) {
      const g: Group = lib.groups[i];
      list.push({
        value: `移到「${g.name}」`,
        action: () => {
          this.moveSelected(g.id);
        }
      });
    }
    return list;
  }

  private moveSelected(groupId: string): void {
    const ids: string[] = this.selectedIds;
    if (ids.length === 0) {
      promptAction.showToast({ message: '请先选择音频', systemMaterial: immersiveToast() });
      return;
    }
    LibraryStore.get().moveTracks(ids, groupId);
    promptAction.showToast({ message: `已移动 ${ids.length} 个音频`, systemMaterial: immersiveToast() });
    this.exitSelect();
  }

  private confirmDeleteSelected(): void {
    const count: number = this.selectedIds.length;
    if (count === 0) {
      promptAction.showToast({ message: '请先选择音频', systemMaterial: immersiveToast() });
      return;
    }
    AlertDialog.show({
      title: '删除音频',
      message: `确定删除选中的 ${count} 个音频？文件会一并删除，无法恢复。`,
      autoCancel: true,
      systemMaterial: immersiveDialog(),
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.accent_orange'),
        action: () => {
          this.deleteSelected();
        }
      }
    });
  }

  private deleteSelected(): void {
    const ids: string[] = this.selectedIds;
    if (ids.length === 0) {
      return;
    }
    const wasCurrent: boolean = ids.indexOf(this.curId) >= 0;
    if (wasCurrent) {
      AudioService.get().pause();
    }
    LibraryStore.get().removeTracks(ids);
    if (wasCurrent) {
      const first: string = LibraryStore.get().firstId();
      if (first.length > 0) {
        AudioService.get().load(first, false);
      }
    }
    this.exitSelect();
    promptAction.showToast({ message: `已删除 ${ids.length} 个音频`, systemMaterial: immersiveToast() });
  }

  private removeTrack(item: Track): void {
    const wasCurrent: boolean = item.id === this.curId;
    if (wasCurrent) {
      AudioService.get().pause();
    }
    LibraryStore.get().removeTrack(item.id);
    if (wasCurrent) {
      const first: string = LibraryStore.get().firstId();
      if (first.length > 0) {
        AudioService.get().load(first, false);
      }
    }
    promptAction.showToast({ message: '已删除音频', systemMaterial: immersiveToast() });
  }

  @Builder
  TrackCard(item: Track) {
    Row({ space: 12 }) {
      Stack() {
        Text(this.badgeOf(item))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_on_accent'))
      }
      .width(46)
      .height(46)
      .borderRadius(14)
      .backgroundColor(this.colorOf(item.groupId))

      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(INK)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 8 }) {
          Text(LibraryStore.get().groupName(item.groupId))
            .fontSize(11)
            .fontColor(SUB)
          Text(this.timeText(item.duration))
            .fontSize(11)
            .fontColor(SUB)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.selecting) {
        Stack() {
          if (this.isSelected(item.id)) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(14)
              .fontColor([$r('app.color.text_on_accent')])
          }
        }
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(this.isSelected(item.id) ? ACCENT : $r('app.color.bg_card'))
        .border({ width: 1.5, color: this.isSelected(item.id) ? ACCENT : $r('app.color.border_chip') })
      } else if (item.id === this.curId) {
        if (this.playing) {
          PlayingBars({ active: true })
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        } else {
          Stack() {
            SymbolGlyph($r('sys.symbol.play_fill'))
              .fontSize(15)
              .fontColor([ACCENT])
          }
          .width(30)
          .height(30)
          .borderRadius(15)
          .backgroundColor($r('app.color.accent_soft'))
        }
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(16)
    .backgroundColor(this.selecting && this.isSelected(item.id) ? $r('app.color.bg_selected_strong')
      : (item.id === this.curId ? $r('app.color.bg_selected') : $r('app.color.bg_card')))
    .animation({ duration: 220, curve: Curve.EaseOut })
    .onClick(() => {
      if (this.selecting) {
        this.toggleSelect(item.id);
      } else {
        AudioService.get().select(item.id);
      }
    })
    .bindMenu(this.menuFor(item))
  }

  @Builder
  ListPane() {
    Column() {
      if (this.selecting) {
        Row({ space: 8 }) {
          Text(`已选 ${this.selectedIds.length} 项`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_brand'))
          Blank()
          Text('全选')
            .fontSize(12)
            .fontColor(ACCENT)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(12)
            .backgroundColor($r('app.color.bg_card'))
            .onClick(() => {
              this.selectAll();
            })
          Text('完成')
            .fontSize(12)
            .fontColor($r('app.color.text_on_accent'))
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(12)
            .backgroundColor($r('app.color.chip_brand'))
            .onClick(() => {
              this.exitSelect();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16 + this.avoidTop, bottom: 12 })
      } else {
      Row({ space: 6 }) {
        Column({ space: 3 }) {
          Text('晨读美文')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_brand'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('本地音频 · 离线播放')
            .fontSize(11)
            .fontColor(SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('设置')
          .fontSize(11)
          .fontColor($r('app.color.text_body'))
          .padding({ left: 9, right: 9, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))
          .onClick(() => {
            this.showSettings = true;
          })

        Text('+ 导入')
          .fontSize(11)
          .fontColor($r('app.color.text_on_accent'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor(ACCENT)
          .onClick(() => {
            this.importAudio();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 + this.avoidTop, bottom: 12 })
      }

      TextInput({ placeholder: '搜索音频名称', text: this.keyword })
        .height(42)
        .borderRadius(14)
        .backgroundColor($r('app.color.bg_card'))
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_secondary'))
        .padding({ left: 14, right: 14 })
        .margin({ left: 20, right: 20 })
        .onChange((value: string) => {
          this.keyword = value;
        })

      Scroll() {
        Row({ space: 8 }) {
          Text(`全部 ${this.totalCount()}`)
            .fontSize(12)
            .fontColor(this.activeGroup() === ALL_GROUP_ID ? $r('app.color.text_on_accent') : $r('app.color.text_body'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(14)
            .backgroundColor(this.activeGroup() === ALL_GROUP_ID ? $r('app.color.chip_brand') : $r('app.color.bg_card'))
            .animation({ duration: 200, curve: Curve.EaseOut })
            .onClick(() => {
              this.groupId = ALL_GROUP_ID;
            })
          ForEach(this.groups(), (item: Group) => {
            Text(`${item.name} ${LibraryStore.get().countOf(item.id)}`)
              .fontSize(12)
              .fontColor(this.activeGroup() === item.id ? $r('app.color.text_on_accent') : $r('app.color.text_body'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .borderRadius(14)
              .backgroundColor(this.activeGroup() === item.id ? $r('app.color.chip_brand') : $r('app.color.bg_card'))
              .animation({ duration: 200, curve: Curve.EaseOut })
              .onClick(() => {
                this.groupId = item.id;
              })
          }, (item: Group) => item.id + '_' + item.name)
        }
        .padding({ left: 20, right: 20, top: 12, bottom: 2 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      if (this.totalCount() === 0) {
        Column({ space: 10 }) {
          Text('还没有音频')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(INK)
          Text('点击右上角「+ 导入」，从文件管理器选择 mp3 / m4a / wav 等音频')
            .fontSize(12)
            .fontColor(SUB)
            .textAlign(TextAlign.Center)
            .padding({ left: 40, right: 40 })
          Text('导入后可长按音频，移动到自定义分组')
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else if (this.visibleTracks().length === 0) {
        Column({ space: 8 }) {
          Text('没有找到音频')
            .fontSize(14)
            .fontColor(SUB)
          Text('换个关键词或分组试试')
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List({ space: 10 }) {
          ForEach(this.visibleTracks(), (item: Track) => {
            ListItem() {
              this.TrackCard(item)
            }
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: 16 }))
              .animation({ duration: 260, curve: Curve.FastOutSlowIn }))
          }, (item: Track) => item.id + '_' + item.title)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 20, right: 20, top: 8 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }

      if (!this.wide) {
        Blank()
          .height(92 + this.avoidBottom)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.bgPath().length > 0) {
        Image('file://' + this.bgPath())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(24)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.bg_scrim'))
      }

      Row() {
        this.ListPane()

        if (this.wide) {
          Column() {
            Row() {
              Text('正在播放')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(INK)
              Blank()
            }
            .width('100%')
            .padding({ left: 22, right: 22, top: 22 + this.avoidTop, bottom: 4 })

            Scroll() {
              PlayerPanel({ inSheet: false })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
          }
          .width('42%')
          .height('100%')
          .backgroundColor($r('app.color.bg_card'))
        }
      }
      .width('100%')
      .height('100%')

      if (this.selecting) {
        Row({ space: 10 }) {
          Text('移动到分组')
            .fontSize(14)
            .fontColor($r('app.color.text_on_accent'))
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .borderRadius(20)
            .backgroundColor(ACCENT)
            .bindMenu(this.moveMenu())
          Text('删除')
            .fontSize(14)
            .fontColor($r('app.color.accent_orange'))
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .borderRadius(20)
            .backgroundColor($r('app.color.accent_orange_soft'))
            .onClick(() => {
              this.confirmDeleteSelected();
            })
        }
        .width('calc(100% - 24vp)')
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .borderRadius(24)
        .backgroundColor($r('app.color.bg_card'))
        .shadow({ radius: 18, color: 'rgba(31,58,95,0.16)', offsetY: 4 })
        .margin({ left: 12, right: 12, bottom: 12 + this.avoidBottom })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.move(TransitionEdge.BOTTOM))
          .animation({ duration: 260, curve: Curve.FastOutSlowIn }))
      } else if (!this.wide) {
        MiniPlayer({
          bottomInset: this.avoidBottom,
          onOpen: () => {
            this.showSheet = true;
          }
        })
      }

      if (!this.wide && this.showSheet) {
        Scroll() {
          Column() {
            PlayerPanel({
              inSheet: true,
              onClose: () => {
                this.showSheet = false;
              }
            })
          }
          .padding({ bottom: 20 + this.avoidBottom })
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_card'))
        .borderRadius({ topLeft: 26, topRight: 26 })
        .scrollBar(BarState.Off)
        .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
          .combine(TransitionEffect.OPACITY)
          .animation({ duration: 300, curve: Curve.FastOutSlowIn }))
      }

      if (this.showGroups) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.bg_dim'))
            .onClick(() => {
              this.showGroups = false;
            })
          Column() {
            GroupManager({
              bottomInset: this.avoidBottom,
              onClose: () => {
                this.showGroups = false;
              }
            })
          }
          .width('100%')
          .height('72%')
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 320 }))
          .animation({ duration: 280, curve: Curve.FastOutSlowIn }))
      }

      if (this.showSettings) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.bg_dim'))
            .onClick(() => {
              this.showSettings = false;
            })
          Column() {
            SettingsPanel({
              bottomInset: this.avoidBottom,
              onClose: () => {
                this.showSettings = false;
              },
              onGroups: () => {
                this.showSettings = false;
                this.showGroups = true;
              },
              onBatch: () => {
                this.showSettings = false;
                this.enterSelect('');
              },
              onImport: () => {
                this.showSettings = false;
                this.importAudio();
              }
            })
          }
          .width('100%')
          .height('92%')
          .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
            .animation({ duration: 300, curve: Curve.FastOutSlowIn }))
        }
        .width('100%')
        .height('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
