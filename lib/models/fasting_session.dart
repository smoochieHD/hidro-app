/// Formata uma duração total em minutos como "Xh Ymin" (ou só "Xh" /
/// "Ymin" quando uma das partes é zero). Usado para mostrar protocolos de
/// jejum de forma legível em toda a app.
String formatDurationMinutes(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h > 0 && m > 0) return '${h}h ${m}min';
  if (h > 0) return '${h}h';
  return '${m}min';
}

/// Representa uma sessão de jejum, ativa ou já terminada.
class FastingSession {
  final DateTime startTime;
  DateTime? endTime;
  final Duration goalDuration;

  /// Água consumida (em ml) durante este ciclo — desde o início deste
  /// jejum até ao momento em que terminar (ou até agora, se ainda ativo).
  /// Substitui o antigo modelo de água "por dia civil": a meta diária do
  /// utilizador continua a aplicar-se, mas o contador reinicia a cada
  /// novo jejum, porque um "dia" de jejum intermitente normalmente
  /// atravessa a meia-noite e não corresponde a um dia civil.
  int waterMl;

  FastingSession({
    required this.startTime,
    this.endTime,
    required this.goalDuration,
    this.waterMl = 0,
  });

  /// Verdadeiro se o jejum ainda está em curso (não foi terminado).
  bool get isActive => endTime == null;

  /// Duração já decorrida desde o início até agora (ou até ao fim, se já terminou).
  Duration get elapsed {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Progresso entre 0.0 e 1.0 em relação ao objetivo definido.
  double get progress {
    final ratio = elapsed.inSeconds / goalDuration.inSeconds;
    if (ratio.isNaN || ratio.isInfinite) return 0.0;
    return ratio.clamp(0.0, 1.0);
  }

  /// Verdadeiro se a meta de duração já foi atingida ou superada.
  bool get goalReached => elapsed >= goalDuration;

  /// Hora prevista de fim, com base na hora de início e no objetivo.
  DateTime get plannedEndTime => startTime.add(goalDuration);

  void addWater(int ml) {
    waterMl += ml;
    if (waterMl < 0) waterMl = 0;
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'goalDurationMinutes': goalDuration.inMinutes,
        'waterMl': waterMl,
      };

  factory FastingSession.fromJson(Map<String, dynamic> json) {
    return FastingSession(
      startTime:
          DateTime.tryParse(json['startTime'] as String? ?? '') ??
              DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
      goalDuration:
          Duration(minutes: (json['goalDurationMinutes'] as num?)?.toInt() ?? 16 * 60),
      waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
    );
  }

  FastingSession copyWith({DateTime? endTime}) {
    return FastingSession(
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      goalDuration: goalDuration,
      waterMl: waterMl,
    );
  }

  /// Duração da janela de alimentação correspondente a este protocolo de
  /// jejum, assumindo um ciclo de 24h (ex: jejum de 16h -> janela de 8h).
  /// Protocolos acima de 24h (não suportados na v1) dão janela zero.
  Duration get eatingWindowDuration {
    final remaining = const Duration(hours: 24) - goalDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Protocolos de jejum predefinidos, com o número de horas de jejum.
class FastingProtocol {
  final String label;
  final String description;
  final int fastingHours;

  const FastingProtocol({
    required this.label,
    required this.description,
    required this.fastingHours,
  });

  static const sixteenEight = FastingProtocol(
    label: '16:8',
    description: 'Mais popular, ideal para iniciantes',
    fastingHours: 16,
  );

  static const eighteenSix = FastingProtocol(
    label: '18:6',
    description: 'Para quem já tem experiência',
    fastingHours: 18,
  );

  static const twentyFour = FastingProtocol(
    label: '20:4',
    description: 'Avançado',
    fastingHours: 20,
  );

  static const List<FastingProtocol> presets = [
    sixteenEight,
    eighteenSix,
    twentyFour,
  ];
}
