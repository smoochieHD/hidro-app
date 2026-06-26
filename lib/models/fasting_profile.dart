/// Um conjunto guardado de definições de jejum (protocolo, janela de
/// comer, meta de água) que o utilizador pode aplicar rapidamente sem
/// reconfigurar cada valor manualmente. Ex: "Dias de trabalho" (16:8,
/// meta 2L) vs "Fim de semana" (14:10, meta 2.5L).
class FastingProfile {
  final String id;
  final String name;
  final int protocolMinutes;
  final int eatingWindowMinutes;
  final int waterGoalMl;

  const FastingProfile({
    required this.id,
    required this.name,
    required this.protocolMinutes,
    required this.eatingWindowMinutes,
    required this.waterGoalMl,
  });

  FastingProfile copyWith({
    String? name,
    int? protocolMinutes,
    int? eatingWindowMinutes,
    int? waterGoalMl,
  }) {
    return FastingProfile(
      id: id,
      name: name ?? this.name,
      protocolMinutes: protocolMinutes ?? this.protocolMinutes,
      eatingWindowMinutes: eatingWindowMinutes ?? this.eatingWindowMinutes,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocolMinutes': protocolMinutes,
        'eatingWindowMinutes': eatingWindowMinutes,
        'waterGoalMl': waterGoalMl,
      };

  factory FastingProfile.fromJson(Map<String, dynamic> json) {
    return FastingProfile(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Perfil',
      protocolMinutes: (json['protocolMinutes'] as num?)?.toInt() ?? 16 * 60,
      eatingWindowMinutes:
          (json['eatingWindowMinutes'] as num?)?.toInt() ?? 8 * 60,
      waterGoalMl: (json['waterGoalMl'] as num?)?.toInt() ?? 2000,
    );
  }
}
