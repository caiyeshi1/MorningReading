import { DEFAULT_GROUP_ID, Group, LibraryStore } from '../common/Library';

const ACCENT: Resource = $r('app.color.accent');
const INK: Resource = $r('app.color.text_primary');
const SUB: Resource = $r('app.color.text_secondary');

@Component
export struct GroupManager {
  @StorageLink('libVersion') libVersion: number = 0;
  @State newName: string = '';
  @State editingId: string = '';
  @State editingName: string = '';
  @State tip: string = '';
  @Prop bottomInset: number = 0;
  onClose: () => void = () => {
  };

  private groups(): Group[] {
    const v: number = this.libVersion;
    if (v < 0) {
      return [];
    }
    return LibraryStore.get().groups;
  }

  private add(): void {
    const ok: boolean = LibraryStore.get().addGroup(this.newName);
    if (ok) {
      this.newName = '';
      this.tip = '已添加分组';
    } else {
      this.tip = '名称不能为空且不能重复';
    }
  }

  private saveRename(): void {
    const ok: boolean = LibraryStore.get().renameGroup(this.editingId, this.editingName);
    this.tip = ok ? '已重命名' : '名称不能为空';
    this.editingId = '';
    this.editingName = '';
  }

  build() {
    Column() {
      Row() {
        Text('分组管理')
          .fontSize(18)
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
      .padding({ left: 20, right: 20, top: 20, bottom: 10 })

      List({ space: 10 }) {
        ForEach(this.groups(), (g: Group) => {
          ListItem() {
            Row({ space: 10 }) {
              if (this.editingId === g.id) {
                TextInput({ text: this.editingName })
                  .layoutWeight(1)
                  .height(40)
                  .fontSize(14)
                  .borderRadius(10)
                  .backgroundColor($r('app.color.bg_card_alt'))
                  .onChange((value: string) => {
                    this.editingName = value;
                  })
                Text('保存')
                  .fontSize(13)
                  .fontColor($r('app.color.text_on_accent'))
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .borderRadius(10)
                  .backgroundColor(ACCENT)
                  .onClick(() => {
                    this.saveRename();
                  })
                Text('取消')
                  .fontSize(13)
                  .fontColor(SUB)
                  .onClick(() => {
                    this.editingId = '';
                    this.editingName = '';
                  })
              } else {
                Column({ space: 3 }) {
                  Text(g.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(INK)
                  Text(`${LibraryStore.get().countOf(g.id)} 首音频`)
                    .fontSize(11)
                    .fontColor(SUB)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('重命名')
                  .fontSize(12)
                  .fontColor(ACCENT)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .borderRadius(10)
                  .backgroundColor($r('app.color.accent_soft'))
                  .onClick(() => {
                    this.editingId = g.id;
                    this.editingName = g.name;
                  })

                if (g.id !== DEFAULT_GROUP_ID) {
                  Text('删除')
                    .fontSize(12)
                    .fontColor($r('app.color.accent_orange'))
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .borderRadius(10)
                    .backgroundColor($r('app.color.accent_orange_soft'))
                    .onClick(() => {
                      LibraryStore.get().deleteGroup(g.id);
                      this.tip = '分组已删除，音频已移到默认分组';
                    })
                }
              }
            }
            .width('100%')
            .padding(12)
            .borderRadius(14)
            .backgroundColor($r('app.color.bg_card_alt'))
          }
        }, (g: Group) => g.id + '_' + g.name)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 20, right: 20 })
      .scrollBar(BarState.Off)

      Row({ space: 10 }) {
        TextInput({ placeholder: '新分组名称', text: this.newName })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card_alt'))
          .onChange((value: string) => {
            this.newName = value;
          })
        Text('添加分组')
          .fontSize(13)
          .fontColor($r('app.color.text_on_accent'))
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .borderRadius(12)
          .backgroundColor(ACCENT)
          .onClick(() => {
            this.add();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 10 })

      Text(this.tip)
        .fontSize(11)
        .fontColor(SUB)
        .height(18)
        .margin({ bottom: 12 + this.bottomInset })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_card'))
    .borderRadius({ topLeft: 26, topRight: 26 })
  }
}
