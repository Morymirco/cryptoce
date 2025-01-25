import 'package:hive/hive.dart';

part 'history_item.g.dart';

@HiveType(typeId: 0)
class HistoryItem extends HiveObject {
  @HiveField(0)
  final String inputText;

  @HiveField(1)
  final String outputText;

  @HiveField(2)
  final int shift;

  @HiveField(3)
  final bool wasEncrypted;

  @HiveField(4)
  final DateTime timestamp;

  HistoryItem({
    required this.inputText,
    required this.outputText,
    required this.shift,
    required this.wasEncrypted,
    required this.timestamp,
  });
} 