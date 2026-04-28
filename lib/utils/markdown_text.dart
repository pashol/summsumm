String markdownWithHardLineBreaks(String text) {
  final normalized = text.replaceAll('\r\n', '\n');
  final buffer = StringBuffer();

  for (var i = 0; i < normalized.length; i++) {
    final char = normalized[i];
    if (char == '\n' &&
        i > 0 &&
        i < normalized.length - 1 &&
        normalized[i - 1] != '\n' &&
        normalized[i + 1] != '\n') {
      buffer.write('  \n');
    } else {
      buffer.write(char);
    }
  }

  return buffer.toString();
}
