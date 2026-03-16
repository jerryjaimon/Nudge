import 'dart:io';
import 'dart:convert';

void main() {
  final dir = Directory('lib/screens');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    try {
      String content = file.readAsStringSync(encoding: utf8);
      bool changed = false;
      
      if (content.contains('NudgeTokens.textHigh')) {
        // 1. Add import if needed
        if (!content.contains('nudge_theme_extension.dart')) {
           final lastImportIdx = content.lastIndexOf(RegExp(r"import '.*';"));
           if (lastImportIdx != -1) {
              final endOfLine = content.indexOf('\n', lastImportIdx);
              content = "${content.substring(0, endOfLine + 1)}import 'package:nudge/utils/nudge_theme_extension.dart';\n${content.substring(endOfLine + 1)}";
              changed = true;
           }
        }
        
        // 2. Replace NudgeTokens.textHigh
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('NudgeTokens.textHigh')) {
             lines[i] = lines[i].replaceAll('const TextStyle', 'TextStyle');
             lines[i] = lines[i].replaceAll('const Text', 'Text');
             lines[i] = lines[i].replaceAll('const Icon', 'Icon');
             lines[i] = lines[i].replaceAll('NudgeTokens.textHigh', '(Theme.of(context).extension<NudgeThemeExtension>()?.textColor ?? NudgeTokens.textHigh)');
             changed = true;
          }
        }
        if (changed) {
          file.writeAsStringSync(lines.join('\n'));
          print('Updated ${file.path}');
        }
      }
    } catch (e) {
      print('Skipped ${file.path}: $e');
    }
  }
}
