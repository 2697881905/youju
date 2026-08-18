import { PublishDraft } from './publishDraft';

const SAVED_POST_DRAFTS_KEY: string = 'savedPostDrafts';
const SAVED_POST_DRAFTS_VERSION: number = 1;

// 草稿为本机私有数据，按登录账号隔离，避免切换账号后看到其他账号的未发布内容。
PersistentStorage.persistProp(SAVED_POST_DRAFTS_KEY, '[]');

export interface SavedPostDraft extends PublishDraft {
  id: string;
  ownerId: string;
  createdAt: number;
  updatedAt: number;
}

interface DraftStorageEnvelope {
  version: number;
  drafts: SavedPostDraft[];
}

type DraftListener = () => void;
const draftListeners: DraftListener[] = [];

function isValidDraft(value: Object): boolean {
  const draft: SavedPostDraft = value as SavedPostDraft;
  return typeof draft.id === 'string' && typeof draft.ownerId === 'string' &&
    typeof draft.createdAt === 'number' && typeof draft.updatedAt === 'number' &&
    typeof draft.title === 'string' && typeof draft.content === 'string' &&
    (draft.mode === undefined || draft.mode === 'photo' || draft.mode === 'text' || draft.mode === 'video') &&
    Array.isArray(draft.tags) && draft.tags.every((tag: string): boolean => typeof tag === 'string') &&
    Array.isArray(draft.images) && draft.images.every((image: string): boolean => typeof image === 'string') &&
    (draft.videoUrl === undefined || typeof draft.videoUrl === 'string') &&
    (draft.videoCover === undefined || typeof draft.videoCover === 'string') &&
    (draft.videoAspectRatio === undefined || typeof draft.videoAspectRatio === 'number') &&
    typeof draft.structuredData === 'object' && draft.structuredData !== null &&
    (draft.textPosterStyle === undefined || typeof draft.textPosterStyle === 'string');
}

function allDrafts(): SavedPostDraft[] {
  const raw: string = (AppStorage.get<string>(SAVED_POST_DRAFTS_KEY) ?? '[]') as string;
  try {
    const parsed: Object = JSON.parse(raw) as Object;
    // 兼容旧版本直接保存数组的数据；新写入统一为版本化信封，便于后续迁移。
    const candidates: Object[] = Array.isArray(parsed)
      ? parsed as Object[]
      : ((parsed as DraftStorageEnvelope).version === SAVED_POST_DRAFTS_VERSION &&
        Array.isArray((parsed as DraftStorageEnvelope).drafts)
        ? (parsed as DraftStorageEnvelope).drafts as Object[] : []);
    if (candidates.length === 0) {
      return [];
    }
    return candidates.filter((item: Object): boolean => isValidDraft(item)) as SavedPostDraft[];
  } catch (_) {
    return [];
  }
}

function writeDrafts(drafts: SavedPostDraft[]): void {
  const payload: DraftStorageEnvelope = { version: SAVED_POST_DRAFTS_VERSION, drafts: drafts };
  AppStorage.setOrCreate<string>(SAVED_POST_DRAFTS_KEY, JSON.stringify(payload));
  for (const listener of draftListeners) {
    listener();
  }
}

export function subscribePostDrafts(listener: DraftListener): () => void {
  draftListeners.push(listener);
  return (): void => {
    const index: number = draftListeners.indexOf(listener);
    if (index >= 0) {
      draftListeners.splice(index, 1);
    }
  };
}

export function listPostDrafts(ownerId: number): SavedPostDraft[] {
  const owner: string = String(ownerId);
  return allDrafts()
    .filter((draft: SavedPostDraft): boolean => draft.ownerId === owner)
    .sort((a: SavedPostDraft, b: SavedPostDraft): number => b.updatedAt - a.updatedAt);
}

export function getPostDraft(ownerId: number, id: string): SavedPostDraft | null {
  const owner: string = String(ownerId);
  for (const draft of allDrafts()) {
    if (draft.ownerId === owner && draft.id === id) {
      return draft;
    }
  }
  return null;
}

export function savePostDraft(ownerId: number, draft: PublishDraft, existingId?: string): SavedPostDraft {
  const now: number = Date.now();
  const owner: string = String(ownerId);
  const drafts: SavedPostDraft[] = allDrafts();
  let previous: SavedPostDraft | null = null;
  let insertAt: number = -1;
  if (existingId !== undefined && existingId.length > 0) {
    for (let i = 0; i < drafts.length; i++) {
      if (drafts[i].id === existingId && drafts[i].ownerId === owner) {
        previous = drafts[i];
        insertAt = i;
        break;
      }
    }
  }
  const saved: SavedPostDraft = {
    id: previous?.id ?? (String(now) + '_' + String(Math.floor(Math.random() * 1000000))),
    ownerId: owner,
    createdAt: previous?.createdAt ?? now,
    updatedAt: now,
    mode: draft.mode,
    title: draft.title,
    content: draft.content,
    genre: draft.genre,
    tags: [...draft.tags],
    structuredData: draft.structuredData,
    images: [...draft.images],
    videoUrl: draft.videoUrl,
    videoCover: draft.videoCover,
    videoAspectRatio: draft.videoAspectRatio,
    textPosterStyle: draft.textPosterStyle,
  };
  if (insertAt >= 0) {
    drafts[insertAt] = saved;
  } else {
    drafts.push(saved);
  }
  writeDrafts(drafts);
  return saved;
}

export function removePostDraft(ownerId: number, id: string): void {
  const owner: string = String(ownerId);
  writeDrafts(allDrafts().filter((draft: SavedPostDraft): boolean => draft.ownerId !== owner || draft.id !== id));
}
