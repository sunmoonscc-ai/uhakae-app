import os

lib_dir = 'lib'

pattern1 = """Image.asset(
                  (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                  height: 32,"""

pattern2 = """Image.asset(
                (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                height: 32,"""

pattern3 = """Image.asset(
              (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
              height: 32,"""
              
pattern4 = """Image.asset(
                    (Theme.of(context).brightness == Brightness.dark ? 'assets/images/logo_dark.png' : 'assets/images/logo.png'),
                    height: 32,"""

pattern_admin = """Image.asset(
              isDarkMode ? 'assets/images/logo_dark.png' : 'assets/images/logo.png',
              height: 32,"""

replacement = '''Container(
                  padding: Theme.of(context).brightness == Brightness.dark ? const EdgeInsets.all(2.0) : null,
                  decoration: Theme.of(context).brightness == Brightness.dark 
                      ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)) 
                      : null,
                  child: Image.asset(
                    'assets/images/logo_new.png',
                    height: 32,'''
                    
replacement_admin = '''Container(
              padding: isDarkMode ? const EdgeInsets.all(2.0) : null,
              decoration: isDarkMode 
                  ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)) 
                  : null,
              child: Image.asset(
                'assets/images/logo_new.png',
                height: 32,'''

for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            
            original = content
            
            # Simple string replacements to ignore whitespace issues, let's normalize spaces somewhat.
            # Even better, let's just do regex replacing only the image asset part.
            import re
            
            # This matches Image.asset((Theme...), height: 32,
            content = re.sub(
                r"Image\.asset\(\s*\(Theme\.of\(context\)\.brightness == Brightness\.dark \? 'assets/images/logo_dark\.png' : 'assets/images/logo\.png'\),\s*height:\s*32,",
                replacement,
                content
            )
            
            content = re.sub(
                r"Image\.asset\(\s*isDarkMode \? 'assets/images/logo_dark\.png' : 'assets/images/logo\.png',\s*height:\s*32,",
                replacement_admin,
                content
            )

            if content != original:
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(content)
                print(f"Updated {filepath}")
