import os
import re

lib_dir = 'lib'

for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            
            original = content
            
            # Pattern 1
            content = re.sub(
                r"Image\.asset\(\s*\(Theme\.of\(context\)\.brightness == Brightness\.dark \? 'assets/images/logo_dark\.png' : 'assets/images/logo\.png'\),\s*height:\s*(\d+),",
                r"""Container(
                  padding: Theme.of(context).brightness == Brightness.dark ? const EdgeInsets.all(2.0) : null,
                  decoration: Theme.of(context).brightness == Brightness.dark 
                      ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)) 
                      : null,
                  child: Image.asset(
                    'assets/images/logo_new.png',
                    height: \1,""",
                content
            )
            
            # Pattern 2 (admin_screen)
            content = re.sub(
                r"Image\.asset\(\s*isDarkMode \? 'assets/images/logo_dark\.png' : 'assets/images/logo\.png',\s*height:\s*(\d+),",
                r"""Container(
              padding: isDarkMode ? const EdgeInsets.all(2.0) : null,
              decoration: isDarkMode 
                  ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)) 
                  : null,
              child: Image.asset(
                'assets/images/logo_new.png',
                height: \1,""",
                content
            )

            if content != original:
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(content)
                print(f"Updated {filepath}")
