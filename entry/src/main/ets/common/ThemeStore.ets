import common from '@ohos.app.ability.common';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import preferences from '@ohos.data.preferences';
import window from '@ohos.window';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';

const DOMAIN: number = 0x0100;
const TAG: string = 'Theme';

export const THEME_SYSTEM: string = 'system';
export const THEME_LIGHT: string = 'light';
export const THEME_DARK: string = 'dark';

/**
 * 深色模式设置（单例）。
 * mode: system / light / dark，通过 setColorMode 切换资源目录（base / dark）。
 * UI 用 @StorageLink('themeMode') 订阅当前选择。
 */
export class ThemeStore {
  private static inst: ThemeStore | null = null;

  static get(): ThemeStore {
    if (ThemeStore.inst === null) {
      ThemeStore.inst = new ThemeStore();
    }
    return ThemeStore.inst;
  }

  mode: string = THEME_SYSTEM;

  private store: preferences.Preferences | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private loaded: boolean = false;

  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.loaded) {
      return;
    }
    this.ctx = ctx;
    this.loaded = true;
    try {
      this.store = await preferences.getPreferences(ctx, 'reading_theme');
      const saved: preferences.ValueType = await this.store.get('themeMode', THEME_SYSTEM);
      if (typeof saved === 'string'
        && (saved === THEME_SYSTEM || saved === THEME_LIGHT || saved === THEME_DARK)) {
        this.mode = saved;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'load theme failed %{public}s', err.message);
    }
    this.apply();
    this.bump();
  }

  setMode(mode: string): void {
    if (mode !== THEME_SYSTEM && mode !== THEME_LIGHT && mode !== THEME_DARK) {
      return;
    }
    this.mode = mode;
    this.apply();
    this.persist();
    this.bump();
  }

  isDarkEffective(): boolean {
    const ctx = this.ctx;
    if (ctx === null) {
      return false;
    }
    if (this.mode === THEME_DARK) {
      return true;
    }
    if (this.mode === THEME_LIGHT) {
      return false;
    }
    return ctx.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  private apply(): void {
    const ctx = this.ctx;
    if (ctx === null) {
      return;
    }
    let target: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (this.mode === THEME_DARK) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else if (this.mode === THEME_LIGHT) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    }
    ctx.getApplicationContext().setColorMode(target);
    this.updateBars();
  }

  private updateBars(): void {
    const ctx = this.ctx;
    if (ctx === null) {
      return;
    }
    const dark: boolean = this.isDarkEffective();
    const content: string = dark ? '#FFFFFF' : '#1B2A41';
    window.getLastWindow(ctx).then((win: window.Window) => {
      const props: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: content,
        navigationBarContentColor: content
      };
      win.setWindowSystemBarProperties(props).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'set bars failed %{public}s', err.message);
      });
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'get window failed %{public}s', err.message);
    });
  }

  private persist(): void {
    const s = this.store;
    if (s === null) {
      return;
    }
    s.put('themeMode', this.mode)
      .then(() => {
        s.flush();
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'persist theme failed %{public}s', err.message);
      });
  }

  private bump(): void {
    AppStorage.setOrCreate<string>('themeMode', this.mode);
  }
}
