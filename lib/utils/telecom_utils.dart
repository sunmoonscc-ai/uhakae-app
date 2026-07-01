class TelecomUtils {
  static const List<String> _globePrefixes = [
    '0905', '0906', '0915', '0916', '0917', '0926', '0927', '0935', '0936', '0937',
    '0945', '0953', '0954', '0955', '0956', '0965', '0966', '0967', '0973', '0975',
    '0977', '0978', '0979', '0995', '0997', '0817'
  ];

  static const List<String> _smartPrefixes = [
    '0908', '0918', '0919', '0920', '0921', '0922', '0923', '0924', '0925', '0928',
    '0929', '0932', '0933', '0934', '0938', '0939', '0942', '0943', '0946', '0947', 
    '0948', '0949', '0950', '0951', '0961', '0963', '0968', '0969', '0970', '0973', 
    '0974', '0981', '0989', '0998', '0999', '0813'
  ];

  static const List<String> _ditoPrefixes = [
    '0991', '0992', '0993', '0994', '0895', '0896', '0897', '0898'
  ];

  static String getPhilippineTelecom(String number) {
    // Remove all non-numeric characters
    final cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Check for landlines first (Cebu: 032, Baguio: 074, Clark/Pampanga: 045, Bohol: 038)
    if (cleanNumber.startsWith('032') || 
        cleanNumber.startsWith('074') || 
        cleanNumber.startsWith('045') || 
        cleanNumber.startsWith('038')) {
      return 'Landline';
    }

    // Check if it's long enough and starts with 09 or 639
    String prefix = '';
    if (cleanNumber.length >= 4 && cleanNumber.startsWith('09')) {
      prefix = cleanNumber.substring(0, 4);
    } else if (cleanNumber.length >= 12 && cleanNumber.startsWith('639')) {
      prefix = '0${cleanNumber.substring(2, 5)}';
    }

    if (prefix.isNotEmpty) {
      if (_globePrefixes.contains(prefix)) {
        return 'Globe / TM / Cherry';
      } else if (_smartPrefixes.contains(prefix)) {
        return 'Smart / TNT / Sun';
      } else if (_ditoPrefixes.contains(prefix)) {
        return 'DITO';
      }
    }
    
    return '';
  }
}
