class NavigationController {
  int selectedIndex = 0;

  // ==========================================================
  // Select page
  // ==========================================================

  void select(int index) {
    selectedIndex = index;
  }

  // ==========================================================
  // Reset to home
  // ==========================================================

  void reset() {
    selectedIndex = 0;
  }

  // ==========================================================
  // Page helpers
  // ==========================================================

  bool get isHome =>
      selectedIndex == 0;

  bool get isSettings =>
      selectedIndex == 1;

  bool get isAbout =>
      selectedIndex == 2;
}