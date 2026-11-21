import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import environment from '@ohos.file.environment';
import fileshare from '@ohos.fileshare';
import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';

const DOMAIN: number = 0x0100;
const TAG: string = 'Library';

export const DEFAULT_GROUP_ID: string = 'g_default';
export const ALL_GROUP_ID: string = 'all';
export const DOWNLOAD_FOLDER: string = '晨读美文';
export const DOWNLOAD_DIR_PATH: string = '/storage/Users/currentUser/Download/' + DOWNLOAD_FOLDER;
export const DOWNLOAD_DIR_URI: string = 'file://docs/storage/Users/currentUser/Download/' + DOWNLOAD_FOLDER;
export const AUDIO_EXTS: string[] = ['.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg', '.opus'];

export interface Track {
  id: string;
  title: string;
  path: string;
  groupId: string;
  duration: number;
}

export interface Group {
  id: string;
  name: string;
}

interface TrackRaw {
  id: string;
  title: string;
  path: string;
  groupId: string;
  duration: number;
}

interface GroupRaw {
  id: string;
  name: string;
}

/**
 * 用户音频库（单例）。
 * 音频从系统文件选择器导入后复制到沙箱 filesDir/audio，索引存 preferences。
 * 变更后递增 AppStorage 'libVersion' 通知 UI 重建列表。
 */
export class LibraryStore {
  private static inst: LibraryStore | null = null;

  static get(): LibraryStore {
    if (LibraryStore.inst === null) {
      LibraryStore.inst = new LibraryStore();
    }
    return LibraryStore.inst;
  }

  groups: Group[] = [];
  tracks: Track[] = [];

  private store: preferences.Preferences | null = null;
  private ctx: common.UIAbilityContext | null = null;
  private version: number = 0;
  private downloadDir: string = DOWNLOAD_DIR_PATH;
  private downloadUri: string = '';
  private loaded: boolean = false;

  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.loaded) {
      return;
    }
    this.ctx = ctx;
    try {
      this.store = await preferences.getPreferences(ctx, 'reading_lib');
      const gRaw: preferences.ValueType = await this.store.get('groups', '[]');
      const tRaw: preferences.ValueType = await this.store.get('tracks', '[]');
      if (typeof gRaw === 'string') {
        this.groups = LibraryStore.parseGroups(gRaw);
      }
      if (typeof tRaw === 'string') {
        this.tracks = LibraryStore.parseTracks(tRaw);
      }
      const dRaw: preferences.ValueType = await this.store.get('downloadUri', '');
      if (typeof dRaw === 'string' && dRaw.length > 0) {
        this.downloadUri = dRaw;
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'load library failed %{public}s', err.message);
    }
    if (this.groups.length === 0) {
      this.groups.push({ id: DEFAULT_GROUP_ID, name: '默认分组' });
    }
    this.dropMissing();
    this.ensureDownloadFolder();
    this.loaded = true;
    this.bump();
  }

  private static parseGroups(text: string): Group[] {
    const list: Group[] = [];
    try {
      const raw: GroupRaw[] = JSON.parse(text) as GroupRaw[];
      for (let i = 0; i < raw.length; i++) {
        const item: GroupRaw = raw[i];
        if (typeof item.id === 'string' && typeof item.name === 'string'
          && item.id.length > 0 && item.name.length > 0) {
          list.push({ id: item.id, name: item.name });
        }
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'bad groups json');
    }
    return list;
  }

  private static parseTracks(text: string): Track[] {
    const list: Track[] = [];
    try {
      const raw: TrackRaw[] = JSON.parse(text) as TrackRaw[];
      for (let i = 0; i < raw.length; i++) {
        const item: TrackRaw = raw[i];
        if (typeof item.id !== 'string' || typeof item.path !== 'string' || item.path.length === 0) {
          continue;
        }
        const title: string = typeof item.title === 'string' ? item.title : '未命名音频';
        const groupId: string = typeof item.groupId === 'string' ? item.groupId : DEFAULT_GROUP_ID;
        const duration: number = typeof item.duration === 'number' ? item.duration : 0;
        list.push({ id: item.id, title: title, path: item.path, groupId: groupId, duration: duration });
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'bad tracks json');
    }
    return list;
  }

  private dropMissing(): void {
    const kept: Track[] = [];
    for (let i = 0; i < this.tracks.length; i++) {
      const item: Track = this.tracks[i];
      let ok: boolean = false;
      try {
        ok = fs.accessSync(item.path);
      } catch (e) {
        ok = false;
      }
      if (ok) {
        kept.push(item);
      }
    }
    this.tracks = kept;
  }

  private bump(): void {
    this.version = this.version + 1;
    AppStorage.setOrCreate<number>('libVersion', this.version);
  }

  private persist(): void {
    const s = this.store;
    if (s === null) {
      return;
    }
    s.put('groups', JSON.stringify(this.groups))
      .then(() => {
        return s.put('tracks', JSON.stringify(this.tracks));
      })
      .then(() => {
        return s.put('downloadUri', this.downloadUri);
      })
      .then(() => {
        s.flush();
      })
      .catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'persist library failed %{public}s', err.message);
      });
  }

  // ---------- 分组 ----------

  groupName(id: string): string {
    for (let i = 0; i < this.groups.length; i++) {
      if (this.groups[i].id === id) {
        return this.groups[i].name;
      }
    }
    return '未分组';
  }

  addGroup(name: string): boolean {
    const n: string = name.trim();
    if (n.length === 0) {
      return false;
    }
    for (let i = 0; i < this.groups.length; i++) {
      if (this.groups[i].name === n) {
        return false;
      }
    }
    this.groups.push({ id: 'g' + Date.now().toString(), name: n });
    this.persist();
    this.bump();
    return true;
  }

  renameGroup(id: string, name: string): boolean {
    const n: string = name.trim();
    if (n.length === 0) {
      return false;
    }
    for (let i = 0; i < this.groups.length; i++) {
      if (this.groups[i].id === id) {
        this.groups[i].name = n;
        this.persist();
        this.bump();
        return true;
      }
    }
    return false;
  }

  deleteGroup(id: string): void {
    if (id === DEFAULT_GROUP_ID) {
      return;
    }
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].groupId === id) {
        this.tracks[i].groupId = DEFAULT_GROUP_ID;
      }
    }
    const kept: Group[] = [];
    for (let i = 0; i < this.groups.length; i++) {
      if (this.groups[i].id !== id) {
        kept.push(this.groups[i]);
      }
    }
    this.groups = kept;
    this.persist();
    this.bump();
  }

  countOf(groupId: string): number {
    let count: number = 0;
    for (let i = 0; i < this.tracks.length; i++) {
      if (groupId === ALL_GROUP_ID || this.tracks[i].groupId === groupId) {
        count++;
      }
    }
    return count;
  }

  // ---------- 音频 ----------

  find(id: string): Track | null {
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].id === id) {
        return this.tracks[i];
      }
    }
    return null;
  }

  indexOf(id: string): number {
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].id === id) {
        return i;
      }
    }
    return -1;
  }

  firstId(): string {
    if (this.tracks.length === 0) {
      return '';
    }
    return this.tracks[0].id;
  }

  moveTrack(id: string, groupId: string): void {
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].id === id) {
        this.tracks[i].groupId = groupId;
        this.persist();
        this.bump();
        return;
      }
    }
  }

  removeTrack(id: string): void {
    const kept: Track[] = [];
    for (let i = 0; i < this.tracks.length; i++) {
      const item: Track = this.tracks[i];
      if (item.id === id) {
        try {
          fs.unlinkSync(item.path);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'unlink failed');
        }
      } else {
        kept.push(item);
      }
    }
    this.tracks = kept;
    this.persist();
    this.bump();
  }

  moveTracks(ids: string[], groupId: string): void {
    for (let i = 0; i < this.tracks.length; i++) {
      if (ids.indexOf(this.tracks[i].id) >= 0) {
        this.tracks[i].groupId = groupId;
      }
    }
    this.persist();
    this.bump();
  }

  removeTracks(ids: string[]): void {
    const kept: Track[] = [];
    for (let i = 0; i < this.tracks.length; i++) {
      const item: Track = this.tracks[i];
      if (ids.indexOf(item.id) >= 0) {
        try {
          fs.unlinkSync(item.path);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'unlink failed');
        }
      } else {
        kept.push(item);
      }
    }
    this.tracks = kept;
    this.persist();
    this.bump();
  }

  setDuration(id: string, ms: number): void {
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].id === id) {
        if (Math.abs(this.tracks[i].duration - ms) > 800) {
          this.tracks[i].duration = ms;
          this.persist();
          this.bump();
        }
        return;
      }
    }
  }

  /** 从文件选择器返回的 uri 导入音频，返回成功数量 */
  async importUris(uris: string[]): Promise<number> {
    const ctx = this.ctx;
    if (ctx === null || uris.length === 0) {
      return 0;
    }
    const dir: string = ctx.filesDir + '/audio';
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
    }
    let count: number = 0;
    for (let i = 0; i < uris.length; i++) {
      const uri: string = uris[i];
      const title: string = LibraryStore.titleOf(uri);
      if (this.hasTitle(title)) {
        continue;
      }
      try {
        const id: string = 't' + Date.now().toString() + '_' + i.toString();
        const dest: string = dir + '/' + id + LibraryStore.extOf(uri);
        const src: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        fs.copyFileSync(src.fd, dest);
        fs.closeSync(src);
        this.tracks.push({
          id: id,
          title: title,
          path: dest,
          groupId: DEFAULT_GROUP_ID,
          duration: 0
        });
        count++;
      } catch (e) {
        const err = e as BusinessError;
        hilog.error(DOMAIN, TAG, 'import failed %{public}s', err.message);
      }
    }
    if (count > 0) {
      this.persist();
      this.bump();
    }
    return count;
  }

  private hasTitle(title: string): boolean {
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].title === title) {
        return true;
      }
    }
    return false;
  }

  private ensureDownloadFolder(): void {
    try {
      const base: string = environment.getUserDownloadDir();
      this.downloadDir = base + '/' + DOWNLOAD_FOLDER;
      hilog.info(DOMAIN, TAG, 'download dir = %{public}s', this.downloadDir);
      if (!fs.accessSync(this.downloadDir)) {
        fs.mkdirSync(this.downloadDir);
      }
      hilog.info(DOMAIN, TAG, 'download dir ready');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'download dir unavailable, will use picker');
      try {
        if (!fs.accessSync(this.downloadDir)) {
          fs.mkdirSync(this.downloadDir);
        }
      } catch (e2) {
        hilog.warn(DOMAIN, TAG, 'create download folder failed');
      }
    }
  }

  private static listAudioFiles(dir: string): string[] | null {
    let names: string[] = [];
    try {
      names = fs.listFileSync(dir);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'list dir failed %{public}s', dir);
      return null;
    }
    const result: string[] = [];
    for (let i = 0; i < names.length; i++) {
      const lower: string = names[i].toLowerCase();
      for (let j = 0; j < AUDIO_EXTS.length; j++) {
        if (lower.endsWith(AUDIO_EXTS[j])) {
          result.push(names[i]);
          break;
        }
      }
    }
    return result;
  }

  /** 从 Download/晨读美文 自动导入；返回 -1 表示无法访问该目录（需要走文件夹选择器） */
  async importFromDownload(): Promise<number> {
    if (this.downloadUri.length > 0) {
      const byUri: string[] | null = LibraryStore.listAudioFiles(this.downloadUri);
      if (byUri !== null) {
        return await this.importNames(this.downloadUri, byUri);
      }
      this.downloadUri = '';
    }
    const names: string[] | null = LibraryStore.listAudioFiles(this.downloadDir);
    if (names === null) {
      return -1;
    }
    return await this.importNames(this.downloadDir, names);
  }

  /** 从文件选择器选中的文件夹 uri 导入，并记住该文件夹以便下次自动扫描 */
  async importFromFolderUri(uri: string): Promise<number> {
    const names: string[] | null = LibraryStore.listAudioFiles(uri);
    if (names === null) {
      return -1;
    }
    this.downloadUri = uri;
    this.persist();
    this.persistFolderPermission(uri);
    return await this.importNames(uri, names);
  }

  private persistFolderPermission(uri: string): void {
    try {
      if (!canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
        return;
      }
      const policy: fileshare.PolicyInfo = {
        uri: uri,
        operationMode: fileshare.OperationMode.READ_MODE
      };
      const policies: fileshare.PolicyInfo[] = [policy];
      fileshare.persistPermission(policies).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'persist permission failed %{public}s', err.message);
      });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'persist permission unavailable');
    }
  }

  private async importNames(dir: string, names: string[]): Promise<number> {
    if (names.length === 0) {
      return 0;
    }
    let base: string = dir;
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    const uris: string[] = [];
    for (let i = 0; i < names.length; i++) {
      uris.push(base + '/' + encodeURIComponent(names[i]));
    }
    return await this.importUris(uris);
  }

  private static titleOf(uri: string): string {
    let name: string = uri;
    const slash: number = name.lastIndexOf('/');
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    try {
      name = decodeURIComponent(name);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'decode uri failed');
    }
    const dot: number = name.lastIndexOf('.');
    if (dot > 0) {
      name = name.substring(0, dot);
    }
    return name.length > 0 ? name : '未命名音频';
  }

  private static extOf(uri: string): string {
    let name: string = uri;
    const slash: number = name.lastIndexOf('/');
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    const dot: number = name.lastIndexOf('.');
    if (dot >= 0) {
      return name.substring(dot).toLowerCase();
    }
    return '.mp3';
  }
}
