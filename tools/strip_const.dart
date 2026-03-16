import 'dart:io';

void main() {
  final dir = Directory('lib/screens');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    String content;
    try {
      content = file.readAsStringSync();
    } catch (e) {
      continue;
    }
    
    if (!content.contains('NudgeThemeExtension')) continue;
    
    // Strip const before Capital letters (classes/widgets) and before [ (lists)
    String newContent = content.replaceAll(RegExp(r'\bconst\s+(?=[A-Z\[])'), '');
    
    if (content != newContent) {
      file.writeAsStringSync(newContent);
      print('Stripped consts from ${file.path}');
    }
  }
}
