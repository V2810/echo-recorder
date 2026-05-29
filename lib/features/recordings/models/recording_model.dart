class Recording {
  final String id;
  final String title;
  final DateTime date;
  final Duration duration;
  final bool isFavorite;

  const Recording({
    required this.id,
    required this.title,
    required this.date,
    required this.duration,
    this.isFavorite = false,
  });

  String get durationFormatted {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
