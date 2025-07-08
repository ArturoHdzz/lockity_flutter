class TextFormatters {
  static String formatName(String name) {
    if (name.trim().isEmpty) return name;
    
    return name.trim()
      .toLowerCase()
      .split(' ')
      .map((word) => word.isEmpty 
        ? '' 
        : word[0].toUpperCase() + word.substring(1))
      .join(' ');
  }
  
  static String cleanSpaces(String text) => 
    text.replaceAll(RegExp(r'\s+'), ' ').trim();
}