

class RuntimeFetcher {
  // Simulates fetching runtime. In a real app, this would hit TMDB API.
  // For MVP, we return a mock value to demonstrate the UI flow.
  static Future<int> fetchRuntime(String title) async {
    await Future.delayed(const Duration(seconds: 1)); // Fake network delay
    // Return a random runtime between 90 and 180 minutes for "movies"
    // Or 20-60 for "series" guesses.
    
    // Deterministic mock based on string length for consistency during testing
    return 30 + (title.length * 5) % 120; 
  }
}
