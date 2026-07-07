import os

target_files = [
    'lib/widgets/system_point_history_dialog.dart',
    'lib/widgets/admin_personal_notice_tab.dart',
    'lib/widgets/admin_notification_badge.dart',
    'lib/services/preferences_service.dart',
    'lib/screens/post_write_screen.dart',
    'lib/screens/post_detail_screen.dart',
    'lib/screens/more_screen.dart',
    'lib/screens/more_menu_sheet.dart',
    'lib/screens/login_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/community_screen.dart',
    'lib/screens/admin_screen.dart',
    'lib/main.dart'
]

for file in target_files:
    if os.path.exists(file):
        with open(file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if 'hdcc6th@gmail.com' in content and 'uhakae2026@gmail.com' not in content:
            print('Updating ' + file)
            content = content.replace("'hdcc6th@gmail.com',", "'hdcc6th@gmail.com',\n      'uhakae2026@gmail.com',")
            content = content.replace('"hdcc6th@gmail.com",', '"hdcc6th@gmail.com",\n      "uhakae2026@gmail.com",')
            with open(file, 'w', encoding='utf-8') as f:
                f.write(content)
