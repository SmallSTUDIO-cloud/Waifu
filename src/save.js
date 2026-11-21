const KEY = 'scarlet-veil-save-v1';
export const defaultSave = () => ({ version: 1, muted: false, reducedMotion: false, wins: 0, bestTime: null });
export function normalizeSave(value) {
  const base = defaultSave();
  if (!value || value.version !== 1) return base;
  return { ...base, muted: value.muted === true, reducedMotion: value.reducedMotion === true,
    wins: Number.isSafeInteger(value.wins) && value.wins >= 0 ? value.wins : 0,
    bestTime: Number.isFinite(value.bestTime) && value.bestTime >= 0 ? value.bestTime : null };
}
export function loadSave(storage) {
  try { return normalizeSave(JSON.parse(storage.getItem(KEY))); } catch { return defaultSave(); }
}
export function writeSave(storage, save) {
  try { storage.setItem(KEY, JSON.stringify(normalizeSave(save))); return true; } catch { return false; }
}
export function recordVictory(save, seconds) {
  const next = normalizeSave(save);
  if (!Number.isFinite(seconds) || seconds < 0) return next;
  next.wins += 1;
  next.bestTime = next.bestTime === null ? seconds : Math.min(next.bestTime, seconds);
  return next;
}
