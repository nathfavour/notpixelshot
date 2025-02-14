class IndexService {
  static Future<void> initialize() async {
    // Set up local database, if needed
  }

  static Future<void> scanAndIndexScreenshots() async {
    // Use Tesseract CLI to extract text from each screenshot
    // Call Ollama for explanations
    // Update local index (e.g., SQLite)
  }
}
