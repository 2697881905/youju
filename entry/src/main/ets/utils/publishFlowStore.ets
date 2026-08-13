import { PublishDraft, PublishDraftMode, clonePublishDraft } from './publishDraft';

export type PublishMode = PublishDraftMode;
export type PublishIntent = 'idle' | 'new' | 'edit' | 'sync' | 'reset';

// New drafts retain their entry type. Existing drafts without it use the old fallback.
function modeOfDraft(draft: PublishDraft): PublishMode {
  if (draft.mode === 'photo' || draft.mode === 'text' || draft.mode === 'video') {
    return draft.mode;
  }
  if (typeof draft.videoUrl === 'string' && draft.videoUrl.length > 0) {
    return 'video';
  }
  return draft.images.length === 0 ? 'text' : 'photo';
}

export interface PublishSession {
  intent: PublishIntent;
  mode: PublishMode;
  activeDraftId: string;
  previewDraft: PublishDraft | null;
  completedDraftId: string;
  revision: number;
}

type PublishFlowListener = (session: PublishSession) => void;

function copySession(session: PublishSession): PublishSession {
  return {
    intent: session.intent,
    mode: session.mode,
    activeDraftId: session.activeDraftId,
    previewDraft: session.previewDraft === null ? null : clonePublishDraft(session.previewDraft),
    completedDraftId: session.completedDraftId,
    revision: session.revision,
  };
}

class PublishFlowStoreImpl {
  private session: PublishSession = {
    intent: 'idle',
    mode: 'photo',
    activeDraftId: '',
    previewDraft: null,
    completedDraftId: '',
    revision: 0,
  };
  private listeners: PublishFlowListener[] = [];

  getSession(): PublishSession {
    return copySession(this.session);
  }

  startNew(mode: PublishMode): void {
    this.update('new', mode, '', null, '');
  }

  editSavedDraft(id: string, draft: PublishDraft): void {
    this.update('edit', modeOfDraft(draft), id, draft, '');
  }

  beginPreview(draft: PublishDraft, activeDraftId: string): void {
    this.update('sync', modeOfDraft(draft), activeDraftId, draft, '');
  }

  updatePreview(draft: PublishDraft): void {
    this.update('sync', modeOfDraft(draft), this.session.activeDraftId, draft, '');
  }

  setActiveDraftId(id: string): void {
    this.update('sync', this.session.mode, id, this.session.previewDraft, '');
  }

  completePublish(): void {
    this.update('reset', this.session.mode, '', null, this.session.activeDraftId);
  }

  subscribe(listener: PublishFlowListener): () => void {
    this.listeners.push(listener);
    return (): void => {
      const index: number = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  private update(intent: PublishIntent, mode: PublishMode, activeDraftId: string,
    previewDraft: PublishDraft | null, completedDraftId: string): void {
    this.session = {
      intent: intent,
      mode: mode,
      activeDraftId: activeDraftId,
      previewDraft: previewDraft === null ? null : clonePublishDraft(previewDraft),
      completedDraftId: completedDraftId,
      revision: this.session.revision + 1,
    };
    const snapshot: PublishSession = copySession(this.session);
    for (const listener of this.listeners) {
      listener(snapshot);
    }
  }
}

// 发布会话只在当前进程中存在；持久化草稿始终由 postDraftStore 负责。
export const publishFlowStore: PublishFlowStoreImpl = new PublishFlowStoreImpl();
