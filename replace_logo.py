import os
import re

lib_dir = 'lib'
pattern1 = re.compile(r"Image\.asset\(\s*\([^)]*?'assets/images/logo(?:_dark)?\.png'[^)]*\)\s*,\s*height:\s*32,")
pattern2 = re.compile(r"Image\.asset\(\s*isDarkMode\s*\?\s*'assets/images/logo_dark\.png'\s*:\s*'assets/images/logo\.png'\s*,\s*height:\s*32,")
pattern3 = re.compile(r"Image\.asset\(\s*assetPath\s*,\s*height:\s*32,") # some files use assetPath

# Some files use assetPath = (Theme... ? ... : ...)
pattern_assetPath = re.compile(r"String assetPath = \(Theme\.of\(context\)\.brightness == Brightness\.dark \? 'assets/images/logo_dark\.png' : 'assets/images/logo\.png'\); // default")

for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            
            original_content = content

            # Replace the asset path assignments
            content = re.sub(pattern_assetPath, "String assetPath = 'assets/images/logo_new.png';", content)
            
            # Pattern 1
            replacement1 = '''Container(
                  padding: Theme.of(context).brightness == Brightness.dark ? const EdgeInsets.all(2.0) : null,
                  decoration: Theme.of(context).brightness == Brightness.dark 
                      ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)) 
                      : null,
                  child: Image.asset(
                    'assets/images/logo_new.png',
                    height: 32,'''
            content = re.sub(pattern1, replacement1, content)

            # Pattern 2 (admin_screen)
            replacement2 = '''Container(
                  padding: isDarkMode ? const EdgeInsets.all(2.0) : null,
                  decoration: isDarkMode 
                      ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)) 
                      : null,
                  child: Image.asset(
                    'assets/images/logo_new.png',
                    height: 32,'''
            content = re.sub(pattern2, replacement2, content)

            # Pattern 3 (assetPath)
            replacement3 = '''Container(
                  padding: Theme.of(context).brightness == Brightness.dark ? const EdgeInsets.all(2.0) : null,
                  decoration: Theme.of(context).brightness == Brightness.dark 
                      ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)) 
                      : null,
                  child: Image.asset(
                    'assets/images/logo_new.png',
                    height: 32,'''
            # but wait, business_map_view doesn't have Theme.of(context).brightness in scope maybe? Yes it does.
            content = re.sub(pattern3, replacement3, content)

            if content != original_content:
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(content)
                print(f"Updated {filepath}")
