import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import window from '@ohos.window';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';

const DOMAIN: number = 0x0100;
const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'loadContent succeeded');
      this.applyImmersive(windowStage);
    });
  }

  private applyImmersive(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen failed %{public}s', e.message);
      });
      const dark: boolean = this.context.config.colorMode
        === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      this.applySystemBars(win, dark);
    }).catch((e: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'getMainWindow failed %{public}s', e.message);
    });
  }

  private applySystemBars(win: window.Window, dark: boolean): void {
    const content: string = dark ? '#FFFFFF' : '#1B2A41';
    const props: window.SystemBarProperties = {
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: content,
      navigationBarContentColor: content
    };
    win.setWindowSystemBarProperties(props).catch((e: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'setWindowSystemBarProperties failed %{public}s', e.message);
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
  }

  onBackground(): void {
  }
}
