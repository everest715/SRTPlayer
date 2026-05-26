class SpeedSetting {
  final int? id;
  final int audioFileId;
  final double speed;

  SpeedSetting({
    this.id,
    required this.audioFileId,
    required this.speed,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'audioFileId': audioFileId,
      'speed': speed,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory SpeedSetting.fromMap(Map<String, dynamic> map) {
    return SpeedSetting(
      id: map['id'] as int?,
      audioFileId: map['audioFileId'] as int,
      speed: (map['speed'] as num).toDouble(),
    );
  }
}
