/// An in-memory "data changed since the last snapshot" flag (ADR 0010). The
/// write paths [mark] it; the lifecycle auto-backup checks it and [reset]s it,
/// so backgrounding without edits writes no snapshot (story #19). Not persisted
/// — it only guards the on-device ring within a single app run.
class BackupDirtyFlag {
  bool _dirty = false;
  bool get isDirty => _dirty;
  void mark() => _dirty = true;
  void reset() => _dirty = false;
}
