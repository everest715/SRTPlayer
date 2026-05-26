class AudioFile {
  final int? id;
  final String fileName;
  final String audioUri;
  final String? srtUri;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final String status; // 'normal' | 'offline'

  AudioFile({
    this.id,
    required this.fileName,
    required this.audioUri,
    this.srtUri,
    required this.createdAt,
    this.lastPlayedAt,
    this.status = 'normal',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'audioUri': audioUri,
      'srtUri': srtUri,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory AudioFile.fromMap(Map<String, dynamic> map) {
    return AudioFile(
      id: map['id'] as int?,
      fileName: map['fileName'] as String,
      audioUri: map['audioUri'] as String,
      srtUri: map['srtUri'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastPlayedAt: map['lastPlayedAt'] != null
          ? DateTime.parse(map['lastPlayedAt'] as String)
          : null,
      status: map['status'] as String? ?? 'normal',
    );
  }

  AudioFile copyWith({
    int? id,
    String? fileName,
    String? audioUri,
    String? srtUri,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    String? status,
  }) {
    return AudioFile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      audioUri: audioUri ?? this.audioUri,
      srtUri: srtUri ?? this.srtUri,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      status: status ?? this.status,
    );
  }
}
