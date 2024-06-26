abstract class SyncStatus {
  const SyncStatus();
  double progress();
}

class SyncingSyncStatus extends SyncStatus {
  SyncingSyncStatus(this.blocksLeft, this.ptc, this.height);

  final double ptc;
  final int blocksLeft;
  final int height;

  @override
  double progress() => ptc;

  @override
  String toString() => '$blocksLeft';
}

class SyncedSyncStatus extends SyncStatus {
  @override
  double progress() => 1.0;
}

class NotConnectedSyncStatus extends SyncStatus {
  const NotConnectedSyncStatus();

  @override
  double progress() => 0.0;
}

class StartingSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class FailedSyncStatus extends SyncStatus {
  @override
  double progress() => 1.0;
}

class ConnectingSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class ConnectedSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class LostConnectionSyncStatus extends SyncStatus {
  @override
  double progress() => 1.0;
}
