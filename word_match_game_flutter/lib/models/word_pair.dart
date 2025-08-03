import 'dart:convert';

class WordPair {
  final String english;
  final String chinese;

  WordPair(this.english, this.chinese);

  factory WordPair.fromJson(Map<String, dynamic> json) {
    return WordPair(
      json['english'] as String,
      json['chinese'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'english': english,
        'chinese': chinese,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordPair &&
          runtimeType == other.runtimeType &&
          english == other.english &&
          chinese == other.chinese;

  @override
  int get hashCode => english.hashCode ^ chinese.hashCode;
}
