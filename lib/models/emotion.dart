/// Emotion data model — quadrants and specific emotion labels
class EmotionQuadrant {
  final String key; // 'red', 'yellow', 'green', 'blue'
  final String label; // Chinese quadrant name
  final String emoji; // Quadrant-level emoji
  final List<EmotionItem> emotions;

  const EmotionQuadrant({
    required this.key,
    required this.label,
    required this.emoji,
    required this.emotions,
  });
}

class EmotionItem {
  final String label; // Chinese name
  final String labelEn; // English name
  final String emoji;

  const EmotionItem({
    required this.label,
    required this.labelEn,
    required this.emoji,
  });
}

/// All emotion data organized by quadrant
class EmotionData {
  EmotionData._();

  static const List<EmotionQuadrant> quadrants = [
    EmotionQuadrant(
      key: 'red',
      label: '有点烦',
      emoji: '\u{1F624}', // grimacing
      emotions: [
        EmotionItem(label: '生气', labelEn: 'Angry', emoji: '\u{1F624}'),
        EmotionItem(label: '焦虑', labelEn: 'Anxious', emoji: '\u{1F630}'),
        EmotionItem(label: '烦躁', labelEn: 'Irritated', emoji: '\u{1F620}'),
        EmotionItem(label: '压力大', labelEn: 'Stressed', emoji: '\u{1F62B}'),
        EmotionItem(label: '不耐烦', labelEn: 'Impatient', emoji: '\u{1F612}'),
        EmotionItem(label: '委屈', labelEn: 'Wronged', emoji: '\u{1F616}'),
      ],
    ),
    EmotionQuadrant(
      key: 'yellow',
      label: '很开心',
      emoji: '\u{1F604}', // grinning face with smiling eyes
      emotions: [
        EmotionItem(label: '开心', labelEn: 'Happy', emoji: '\u{1F604}'),
        EmotionItem(label: '兴奋', labelEn: 'Excited', emoji: '\u{1F929}'),
        EmotionItem(label: '自豪', labelEn: 'Proud', emoji: '\u{1F60A}'),
        EmotionItem(label: '激动', labelEn: 'Thrilled', emoji: '\u{1F973}'),
        EmotionItem(label: '期待', labelEn: 'Expectant', emoji: '\u{1F601}'),
        EmotionItem(label: '有信心', labelEn: 'Confident', emoji: '\u{1F4AA}'),
      ],
    ),
    EmotionQuadrant(
      key: 'green',
      label: '很平静',
      emoji: '\u{1F60C}', // relieved face
      emotions: [
        EmotionItem(label: '平静', labelEn: 'Calm', emoji: '\u{1F60C}'),
        EmotionItem(label: '感激', labelEn: 'Grateful', emoji: '\u{1F64F}'),
        EmotionItem(label: '满足', labelEn: 'Content', emoji: '\u{1F60A}'),
        EmotionItem(label: '放松', labelEn: 'Relaxed', emoji: '\u{1F9D8}'),
        EmotionItem(label: '温暖', labelEn: 'Warm', emoji: '\u{2600}\u{FE0F}'),
        EmotionItem(label: '安全', labelEn: 'Safe', emoji: '\u{1F6E1}\u{FE0F}'),
      ],
    ),
    EmotionQuadrant(
      key: 'blue',
      label: '不太好',
      emoji: '\u{1F622}', // crying face
      emotions: [
        EmotionItem(label: '难过', labelEn: 'Sad', emoji: '\u{1F622}'),
        EmotionItem(label: '失落', labelEn: 'Lost', emoji: '\u{1F614}'),
        EmotionItem(label: '孤单', labelEn: 'Lonely', emoji: '\u{1F61E}'),
        EmotionItem(label: '疲惫', labelEn: 'Tired', emoji: '\u{1F629}'),
        EmotionItem(label: '无聊', labelEn: 'Bored', emoji: '\u{1F636}'),
        EmotionItem(label: '想家', labelEn: 'Homesick', emoji: '\u{1F97A}'),
      ],
    ),
  ];

  /// Find quadrant by key
  static EmotionQuadrant? findQuadrant(String key) {
    try {
      return quadrants.firstWhere((q) => q.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Find emotion item by label within a quadrant
  static EmotionItem? findEmotion(String quadrantKey, String label) {
    final quadrant = findQuadrant(quadrantKey);
    if (quadrant == null) return null;
    try {
      return quadrant.emotions.firstWhere((e) => e.label == label);
    } catch (_) {
      return null;
    }
  }

  /// Find emotion item by label across all quadrants
  static EmotionItem? findEmotionByLabel(String label) {
    for (final q in quadrants) {
      for (final e in q.emotions) {
        if (e.label == label) return e;
      }
    }
    return null;
  }

  /// Parse a comma-separated emotionLabel into individual labels.
  /// Handles both single-label (old data) and multi-label (new data).
  static List<String> parseLabels(String emotionLabel) {
    return emotionLabel
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Get combined emojis for a (possibly comma-separated) emotionLabel.
  static String getEmojis(String emotionLabel) {
    final labels = parseLabels(emotionLabel);
    return labels
        .map((l) => findEmotionByLabel(l)?.emoji ?? '')
        .where((e) => e.isNotEmpty)
        .join('');
  }

  /// Get display text for a (possibly comma-separated) emotionLabel,
  /// joining multiple labels with Chinese comma.
  static String getDisplayText(String emotionLabel) {
    final labels = parseLabels(emotionLabel);
    return labels.join('\u3001');
  }

  /// Context/scene options
  static const List<ContextOption> contextOptions = [
    ContextOption(key: 'school', label: '学校', icon: '\u{1F393}'),
    ContextOption(key: 'recess', label: '休息', icon: '\u{2615}'),
    ContextOption(key: 'lunch', label: '午餐', icon: '\u{1F374}'),
    ContextOption(key: 'home', label: '家里', icon: '\u{1F3E0}'),
    ContextOption(key: 'commute', label: '在路上', icon: '\u{1F68C}'),
  ];

  /// Find context label by key
  static String contextLabel(String key) {
    try {
      return contextOptions.firstWhere((c) => c.key == key).label;
    } catch (_) {
      return key;
    }
  }
}

class ContextOption {
  final String key;
  final String label;
  final String icon; // emoji icon

  const ContextOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}
