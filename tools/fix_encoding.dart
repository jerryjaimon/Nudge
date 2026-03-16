import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('lib/screens/gym/exercise_info.dart');
  final bytes = file.readAsBytesSync();
  final content = utf8.decode(bytes, allowMalformed: true);
  file.writeAsStringSync(content, encoding: utf8);
  print('Fixed encoding context.');
}
