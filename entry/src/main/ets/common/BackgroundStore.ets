import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';

const DOMAIN: number = 0x0100;
const TAG: string = 'Background';

/**
 * 自定义应用背景（单例）。
 * 用户选中的图片复制到沙箱 filesDir/bg 下，路径存 preferences。
 * 变更后递增 AppStorage 'bgVersion' 通知 UI 刷新。
 */
export class BackgroundStore {
  private static inst: BackgroundStore | null = null;

  static get(): BackgroundStore {
    if (BackgroundStore.inst === null) {
      BackgroundStore.inst = new BackgroundStore();
    }
    return BackgroundStore.inst;
  }

  path: string = '';

  private store: preferences.Preferences | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private version: number = 0;
  private loaded: boolean = false;

  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.loaded) {
      return;
    }
    this.ctx = ctx;
    this.loaded = true;
    try {
      this.store = await preferences.getPreferences(ctx, 'reading_theme');
      const saved: preferences.ValueType = await this.store.get('bgPath', '');
      if (typeof saved === 'string' && saved.length > 0 && fs.accessSync(saved)) {
        this.path = saved;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'load background failed %{public}s', err.message);
    }
    this.bump();
  }

  /** 把用户选择的图片复制到沙箱并设为背景 */
  async setFromUri(uri: string): Promise<boolean> {
    const ctx = this.ctx;
    if (ctx === null || uri.length === 0) {
      return false;
    }
    const dir: string = ctx.filesDir + '/bg';
    try {
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
      const dest: string = dir + '/background' + BackgroundStore.extOf(uri);
      const src: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      fs.copyFileSync(src.fd, dest);
      fs.closeSync(src);
      if (this.path.length > 0 && this.path !== dest) {
        try {
          fs.unlinkSync(this.path);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'remove old background failed');
        }
      }
      this.path = dest;
      this.persist();
      this.bump();
      return true;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'set background failed %{public}s', err.message);
      return false;
    }
  }

  clear(): void {
    this.path = '';
    this.persist();
    this.bump();
  }

  private persist(): void {
    const s = this.store;
    if (s === null) {
      return;
    }
    s.put('bgPath', this.path)
      .then(() => {
        s.flush();
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'persist background failed %{public}s', err.message);
      });
  }

  private bump(): void {
    this.version = this.version + 1;
    AppStorage.setOrCreate<number>('bgVersion', this.version);
  }

  private static extOf(uri: string): string {
    let name: string = uri;
    const slash: number = name.lastIndexOf('/');
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    const dot: number = name.lastIndexOf('.');
    if (dot >= 0) {
      const ext: string = name.substring(dot).toLowerCase();
      if (ext === '.png' || ext === '.jpg' || ext === '.jpeg' || ext === '.webp' || ext === '.bmp') {
        return ext;
      }
    }
    return '.jpg';
  }
}
