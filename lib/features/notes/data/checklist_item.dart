class ChecklistItem {
  const ChecklistItem({required this.text, required this.completed});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    text: json['text'] as String,
    completed: json['completed'] as bool,
  );

  final String text;
  final bool completed;

  ChecklistItem copyWith({String? text, bool? completed}) => ChecklistItem(
    text: text ?? this.text,
    completed: completed ?? this.completed,
  );

  Map<String, dynamic> toJson() => {'text': text, 'completed': completed};
}
