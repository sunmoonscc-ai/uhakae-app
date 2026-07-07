import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    // We can find all lines with 'assets/images/logo.png'
    if (content.contains("'assets/images/logo.png'") || content.contains("'assets/images/logo_dark.png'")) {
      // Find where Image.asset is used for logos.
      // Easiest is to replace the file path itself, but we want to add background.
      
      // Let's replace the string directly:
      // (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png')
      // -> 'assets/images/logo_new.png'
      
      final p1 = RegExp(r"\(Theme\.of\(context\)\.brightness == Brightness\.dark \? 'assets/images/logo_dark\.png' : 'assets/images/logo\.png'\)");
      if (p1.hasMatch(content)) {
        content = content.replaceAll(p1, "'assets/images/logo_new.png'");
        changed = true;
      }

      final p2 = RegExp(r"isDarkMode \? 'assets/images/logo_dark\.png' : 'assets/images/logo\.png'");
      if (p2.hasMatch(content)) {
        content = content.replaceAll(p2, "'assets/images/logo_new.png'");
        changed = true;
      }
      
      // Now we need to add the white background wrapper if the Image is inside an Image.asset.
      // But instead of wrapping the image, what if we just wrap the Image.asset(...) with a Container?
      // It's hard to parse AST with regex.
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated \${file.path}');
    }
  }
}
