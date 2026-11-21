import media from '@ohos.multimedia.media';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import wantAgent from '@ohos.app.ability.wantAgent';
import avSession from '@ohos.multimedia.avsession';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import fs from '@ohos.file.fs';
import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';
import { LibraryStore, Track } from './Library';

const DOMAIN: number = 0x0100;
const TAG: string = 'ReadingAudio';

/**
 * 全局播放服务（单例）。
 * 播放状态通过 AppStorage 同步给 UI：
 *   curId / curNo / curTitle / curGroup / playing / pos / dur / speedIdx / autoNext
 */
export class AudioService {
  private static inst: AudioService | null = null;

  static get(): AudioService {
    if (AudioService.inst === null) {
      AudioService.inst = new AudioService();
    }
    return AudioService.inst;
  }

  private player: media.AVPlayer | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private store: preferences.Preferences | null = null;
  private session: avSession.AVSession | null = null;
  private taskRunning: boolean = false;
  private lastSync: number = 0;
  private sleepTimer: number = -1;
  private aMs: number = 0;
  private bMs: number = 0;
  private fileFd: number = -1;
  private currentId: string = '';
  private pendingPlay: boolean = false;
  private savedPos: Map<string, number> = new Map<string, number>();
  private speed: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  private speedValues: media.PlaybackSpeed[] = [
    media.PlaybackSpeed.SPEED_FORWARD_0_75_X,
    media.PlaybackSpeed.SPEED_FORWARD_1_00_X,
    media.PlaybackSpeed.SPEED_FORWARD_1_25_X,
    media.PlaybackSpeed.SPEED_FORWARD_1_75_X
  ];

  autoNext: boolean = true;

  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.player !== null) {
      return;
    }
    this.ctx = ctx;
    await LibraryStore.get().init(ctx);
    await this.restoreState(ctx);
    if (LibraryStore.get().find(this.currentId) === null) {
      this.currentId = LibraryStore.get().firstId();
    }
    AppStorage.setOrCreate<string>('curId', this.currentId);
    AppStorage.setOrCreate<number>('curNo', 0);
    AppStorage.setOrCreate<string>('curTitle', '');
    AppStorage.setOrCreate<string>('curGroup', '');
    AppStorage.setOrCreate<boolean>('playing', false);
    AppStorage.setOrCreate<number>('pos', 0);
    AppStorage.setOrCreate<number>('dur', 0);
    AppStorage.setOrCreate<boolean>('autoNext', true);
    AppStorage.setOrCreate<number>('speedIdx', 1);
    AppStorage.setOrCreate<number>('sleepEnd', 0);
    AppStorage.setOrCreate<number>('sleepMin', 0);
    AppStorage.setOrCreate<number>('abA', 0);
    AppStorage.setOrCreate<number>('abB', 0);
    try {
      const p: media.AVPlayer = await media.createAVPlayer();
      this.player = p;
      p.on('stateChange', (state: media.AVPlayerState) => {
        this.onState(state);
      });
      p.on('timeUpdate', (time: number) => {
        AppStorage.setOrCreate<number>('pos', time);
        if (this.bMs > this.aMs && this.aMs > 0 && time >= this.bMs) {
          this.seekTo(this.aMs);
        }
        const now: number = Date.now();
        if (now - this.lastSync > 1000) {
          this.lastSync = now;
          this.publishState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
        }
      });
      p.on('durationUpdate', (duration: number) => {
        AppStorage.setOrCreate<number>('dur', duration);
        if (this.currentId.length > 0 && duration > 0) {
          LibraryStore.get().setDuration(this.currentId, duration);
        }
        this.publishMetadata();
      });
      p.on('error', (err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'player error %{public}d %{public}s', err.code, err.message);
        AppStorage.setOrCreate<boolean>('playing', false);
      });
      await this.initSession(ctx);
      if (this.currentId.length > 0) {
        await this.load(this.currentId, false);
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'createAVPlayer failed %{public}s', err.message);
    }
  }

  private onState(state: media.AVPlayerState): void {
    const p = this.player;
    if (p === null) {
      return;
    }
    if (state === 'initialized') {
      p.prepare();
    } else if (state === 'prepared') {
      p.setSpeed(this.speed);
      AppStorage.setOrCreate<number>('dur', p.duration);
      if (this.currentId.length > 0 && p.duration > 0) {
        LibraryStore.get().setDuration(this.currentId, p.duration);
      }
      const resume: number | undefined = this.savedPos.get(this.currentId);
      if (resume !== undefined && resume > 2000 && resume < p.duration - 3000) {
        p.seek(resume, media.SeekMode.SEEK_CLOSEST);
      }
      this.savedPos.delete(this.currentId);
      this.publishMetadata();
      if (this.pendingPlay) {
        p.play().catch((err: BusinessError) => {
          hilog.error(DOMAIN, TAG, 'play failed %{public}s', err.message);
        });
      }
    } else if (state === 'playing') {
      AppStorage.setOrCreate<boolean>('playing', true);
      this.publishState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
      this.startBackgroundTask();
    } else if (state === 'paused') {
      AppStorage.setOrCreate<boolean>('playing', false);
      this.publishState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      this.stopBackgroundTask();
      this.persistState();
    } else if (state === 'completed') {
      AppStorage.setOrCreate<boolean>('playing', false);
      if (this.autoNext) {
        this.next();
      } else {
        this.publishState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
        this.stopBackgroundTask();
      }
    }
  }

  private setTrackInfo(track: Track): void {
    const lib: LibraryStore = LibraryStore.get();
    AppStorage.setOrCreate<string>('curId', track.id);
    AppStorage.setOrCreate<number>('curNo', lib.indexOf(track.id) + 1);
    AppStorage.setOrCreate<string>('curTitle', track.title);
    AppStorage.setOrCreate<string>('curGroup', lib.groupName(track.groupId));
  }

  /** 载入某一首；play 为 true 时自动开始播放 */
  async load(id: string, play: boolean): Promise<void> {
    const p = this.player;
    const track: Track | null = LibraryStore.get().find(id);
    if (p === null || track === null) {
      return;
    }
    const cur: number | undefined = AppStorage.get<number>('pos');
    if (cur !== undefined && (p.state === 'playing' || p.state === 'paused')) {
      this.savedPos.set(this.currentId, cur);
    }
    this.persistState();
    this.currentId = id;
    this.pendingPlay = play;
    this.setAB('clear');
    this.setTrackInfo(track);
    AppStorage.setOrCreate<number>('pos', 0);
    AppStorage.setOrCreate<number>('dur', track.duration);
    try {
      if (p.state !== 'idle') {
        await p.reset();
      }
      if (this.fileFd >= 0) {
        fs.closeSync(this.fileFd);
        this.fileFd = -1;
      }
      const file = fs.openSync(track.path, fs.OpenMode.READ_ONLY);
      this.fileFd = file.fd;
      p.url = 'fd://' + this.fileFd;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'load failed %{public}s', err.message);
    }
  }

  /** 点列表：同一首则暂停/继续，否则切歌 */
  select(id: string): void {
    const p = this.player;
    if (p === null) {
      return;
    }
    if (id === this.currentId && (p.state === 'playing' || p.state === 'paused')) {
      this.toggle();
    } else {
      this.load(id, true);
    }
  }

  async toggle(): Promise<void> {
    const p = this.player;
    if (p === null) {
      return;
    }
    if (p.state === 'playing') {
      await p.pause();
    } else if (p.state === 'paused' || p.state === 'prepared') {
      this.pendingPlay = true;
      await p.play();
    } else if (this.currentId.length > 0) {
      await this.load(this.currentId, true);
    }
  }

  async seekTo(ms: number): Promise<void> {
    const p = this.player;
    if (p === null) {
      return;
    }
    if (p.state === 'playing' || p.state === 'paused' || p.state === 'completed') {
      await p.seek(ms, media.SeekMode.SEEK_CLOSEST);
    }
  }

  seekRelative(delta: number): void {
    const cur: number | undefined = AppStorage.get<number>('pos');
    const dur: number | undefined = AppStorage.get<number>('dur');
    let target: number = (cur === undefined ? 0 : cur) + delta;
    if (target < 0) {
      target = 0;
    }
    if (dur !== undefined && target > dur - 500) {
      target = dur - 500;
    }
    this.seekTo(target);
  }

  next(): void {
    const lib: LibraryStore = LibraryStore.get();
    const total: number = lib.tracks.length;
    if (total === 0) {
      return;
    }
    const idx: number = lib.indexOf(this.currentId);
    const nextIdx: number = idx < 0 ? 0 : (idx + 1) % total;
    this.load(lib.tracks[nextIdx].id, true);
  }

  prev(): void {
    const lib: LibraryStore = LibraryStore.get();
    const total: number = lib.tracks.length;
    if (total === 0) {
      return;
    }
    const idx: number = lib.indexOf(this.currentId);
    const prevIdx: number = idx <= 0 ? total - 1 : idx - 1;
    this.load(lib.tracks[prevIdx].id, true);
  }

  setSpeedIndex(idx: number): void {
    if (idx < 0 || idx >= this.speedValues.length) {
      return;
    }
    this.speed = this.speedValues[idx];
    AppStorage.setOrCreate<number>('speedIdx', idx);
    const p = this.player;
    if (p !== null && (p.state === 'prepared' || p.state === 'playing' || p.state === 'paused')) {
      p.setSpeed(this.speed);
    }
  }

  setAutoNext(on: boolean): void {
    this.autoNext = on;
    AppStorage.setOrCreate<boolean>('autoNext', on);
  }

  // ---------- 锁屏 / 蓝牙耳机控制（AVSession）与后台播放 ----------

  private async initSession(ctx: common.UIAbilityContext): Promise<void> {
    try {
      const s: avSession.AVSession = await avSession.createAVSession(ctx, 'morning-reading', 'audio');
      this.session = s;
      s.on('play', () => {
        this.toggle();
      });
      s.on('pause', () => {
        this.pause();
      });
      s.on('stop', () => {
        this.pause();
      });
      s.on('playNext', () => {
        this.next();
      });
      s.on('playPrevious', () => {
        this.prev();
      });
      s.on('seek', (time: number) => {
        this.seekTo(time);
      });
      const agent = await this.buildWantAgent(ctx);
      if (agent !== null) {
        await s.setLaunchAbility(agent);
      }
      await s.activate();
      this.publishMetadata();
      this.publishState(avSession.PlaybackState.PLAYBACK_STATE_INITIAL);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'initSession failed %{public}s', err.message);
    }
  }

  private async buildWantAgent(ctx: common.UIAbilityContext) {
    try {
      const want: Want = {
        bundleName: ctx.abilityInfo.bundleName,
        abilityName: ctx.abilityInfo.name
      };
      const info: wantAgent.WantAgentInfo = {
        wants: [want],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      return await wantAgent.getWantAgent(info);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'buildWantAgent failed %{public}s', err.message);
      return null;
    }
  }

  private publishMetadata(): void {
    const s = this.session;
    if (s === null) {
      return;
    }
    const title: string | undefined = AppStorage.get<string>('curTitle');
    const group: string | undefined = AppStorage.get<string>('curGroup');
    const dur: number | undefined = AppStorage.get<number>('dur');
    const meta: avSession.AVMetadata = {
      assetId: this.currentId,
      title: title === undefined ? '' : title,
      artist: group === undefined ? '' : group,
      album: 'Morning Reading',
      duration: dur === undefined ? 0 : dur
    };
    s.setAVMetadata(meta).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'setAVMetadata failed %{public}s', err.message);
    });
  }

  private publishState(state: avSession.PlaybackState): void {
    const s = this.session;
    if (s === null) {
      return;
    }
    const pos: number | undefined = AppStorage.get<number>('pos');
    const dur: number | undefined = AppStorage.get<number>('dur');
    const pb: avSession.AVPlaybackState = {
      state: state,
      speed: this.speedValue(),
      position: {
        elapsedTime: pos === undefined ? 0 : pos,
        updateTime: Date.now()
      },
      duration: dur === undefined ? 0 : dur
    };
    s.setAVPlaybackState(pb).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'setAVPlaybackState failed %{public}s', err.message);
    });
  }

  private speedValue(): number {
    if (this.speed === media.PlaybackSpeed.SPEED_FORWARD_0_75_X) {
      return 0.75;
    }
    if (this.speed === media.PlaybackSpeed.SPEED_FORWARD_1_25_X) {
      return 1.25;
    }
    if (this.speed === media.PlaybackSpeed.SPEED_FORWARD_1_75_X) {
      return 1.75;
    }
    return 1.0;
  }

  private async startBackgroundTask(): Promise<void> {
    if (this.taskRunning) {
      return;
    }
    const ctx = this.ctx;
    if (ctx === null) {
      return;
    }
    try {
      const agent = await this.buildWantAgent(ctx);
      if (agent === null) {
        return;
      }
      await backgroundTaskManager.startBackgroundRunning(ctx,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      this.taskRunning = true;
      hilog.info(DOMAIN, TAG, 'background task started');
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'startBackgroundRunning failed %{public}s', err.message);
    }
  }

  private async stopBackgroundTask(): Promise<void> {
    if (!this.taskRunning) {
      return;
    }
    const ctx = this.ctx;
    if (ctx === null) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(ctx);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'stopBackgroundRunning failed %{public}s', err.message);
    }
    this.taskRunning = false;
  }

  async pause(): Promise<void> {
    const p = this.player;
    if (p !== null && p.state === 'playing') {
      await p.pause();
    }
  }

  // ---------- 睡眠定时 / A-B 复读 ----------

  /** minutes 为 0 表示关闭定时 */
  setSleep(minutes: number): void {
    if (this.sleepTimer >= 0) {
      clearTimeout(this.sleepTimer);
      this.sleepTimer = -1;
    }
    if (minutes <= 0) {
      AppStorage.setOrCreate<number>('sleepEnd', 0);
      AppStorage.setOrCreate<number>('sleepMin', 0);
      return;
    }
    const ms: number = minutes * 60 * 1000;
    this.sleepTimer = setTimeout(() => {
      this.pause();
      this.sleepTimer = -1;
      AppStorage.setOrCreate<number>('sleepEnd', 0);
      AppStorage.setOrCreate<number>('sleepMin', 0);
      hilog.info(DOMAIN, TAG, 'sleep timer fired, paused');
    }, ms);
    AppStorage.setOrCreate<number>('sleepEnd', Date.now() + ms);
    AppStorage.setOrCreate<number>('sleepMin', minutes);
  }

  /** kind: 'a' 设起点，'b' 设终点，'clear' 取消 */
  setAB(kind: string): void {
    const pos: number | undefined = AppStorage.get<number>('pos');
    const cur: number = pos === undefined ? 0 : pos;
    if (kind === 'a') {
      this.aMs = cur;
      this.bMs = 0;
    } else if (kind === 'b') {
      if (this.aMs > 0 && cur > this.aMs + 1000) {
        this.bMs = cur;
      }
    } else {
      this.aMs = 0;
      this.bMs = 0;
    }
    AppStorage.setOrCreate<number>('abA', this.aMs);
    AppStorage.setOrCreate<number>('abB', this.bMs);
  }

  private async restoreState(ctx: common.UIAbilityContext): Promise<void> {
    try {
      this.store = await preferences.getPreferences(ctx, 'reading_store');
      const lastId: preferences.ValueType = await this.store.get('lastId', '');
      if (typeof lastId === 'string' && lastId.length > 0) {
        this.currentId = lastId;
      }
      const lastPos: preferences.ValueType = await this.store.get('lastPos', 0);
      if (typeof lastPos === 'number' && lastPos > 3000) {
        this.savedPos.set(this.currentId, lastPos);
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'restore state failed %{public}s', err.message);
    }
  }

  private persistState(): void {
    const s = this.store;
    if (s === null) {
      return;
    }
    const cur: number | undefined = AppStorage.get<number>('pos');
    const value: number = cur === undefined ? 0 : cur;
    s.put('lastId', this.currentId)
      .then(() => {
        return s.put('lastPos', value);
      })
      .then(() => {
        s.flush();
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'persist state failed %{public}s', err.message);
      });
  }
}
