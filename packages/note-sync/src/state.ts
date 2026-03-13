import { readLifeClipFile, writeLifeClipFile } from "@lifeclip/shared";

interface NoteSyncState {
  /** Map of file path -> last known mtime (ms) */
  files: Record<string, number>;
  lastSync: string; // ISO timestamp
}

const STATE_FILE = "note-sync-state.json";

export function loadNoteSyncState(): NoteSyncState {
  return readLifeClipFile<NoteSyncState>(STATE_FILE) ?? {
    files: {},
    lastSync: new Date(0).toISOString(),
  };
}

export function saveNoteSyncState(state: NoteSyncState): void {
  writeLifeClipFile(STATE_FILE, state);
}

/** Determine which files are new or changed */
export function findChangedFiles(
  scanned: Array<{ path: string; mtime: number }>,
  state: NoteSyncState
): Array<{ path: string; mtime: number; isNew: boolean }> {
  const changed: Array<{ path: string; mtime: number; isNew: boolean }> = [];
  for (const file of scanned) {
    const prevMtime = state.files[file.path];
    if (prevMtime === undefined) {
      changed.push({ ...file, isNew: true });
    } else if (file.mtime > prevMtime) {
      changed.push({ ...file, isNew: false });
    }
  }
  return changed;
}
