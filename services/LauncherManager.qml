pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.services
import qs.components.methods

/*
 * LauncherManager provides application filtering and launching logic.
 * It also persists application launch times for recency-based sorting.
 */
QtObject {
  id: manager

  // --- Public Properties ---
  property var filteredApps: []
  property int maxResults: 7
  property var launchTimes: ({})

  property var _stateHandler: StateManager.createStateHandler("launcher")


  // --- Public Signals ---
  signal appsFiltered()

  // --- Public Methods ---

  /**
   * @brief Filters the list of all applications based on search text.
   * The results are sorted by recency of launch, then alphabetically.
   * @param searchText The text to filter by.
   */
  function filterApps(searchText) {
    const filterText = searchText.trim().toLowerCase();

    if (filterText === "") {
      filteredApps = [];
      appsFiltered();
      return;
    }

    const allApps = DesktopEntries.applications.values;

    // Filter apps matching search criteria
    let filtered = allApps.filter(app => {
      if (app.noDisplay) return false;

      return app.name.toLowerCase().includes(filterText) ||
             app.genericName.toLowerCase().includes(filterText) ||
             app.keywords.some(k => k.toLowerCase().includes(filterText));
    });

    // Sort by recency first, then alphabetically
    filtered.sort((a, b) => {
      const aTime = launchTimes[a.id] || 0;
      const bTime = launchTimes[b.id] || 0;

      // Most recent first
      if (aTime !== bTime) {
        return bTime - aTime;
      }

      // Alphabetical for apps with same recency
      return a.name.localeCompare(b.name);
    });

    filteredApps = filtered.slice(0, maxResults);
    appsFiltered();
  }

  /**
   * @brief Launches a desktop application and records the launch time.
   * @param appEntry The desktop entry object to launch.
   * @returns {boolean} True if the launch was successful, false otherwise.
   */
  function launchApp(appEntry) {
    if (!appEntry) return false;

    try {
      // Record launch time
      const now = Date.now();
      let times = launchTimes;
      times[appEntry.id] = now;
      launchTimes = times;
      _stateHandler.save(launchTimes);

      // Execute the app
      appEntry.execute();
      return true;
    } catch (e) {
      console.error("Failed to launch app:", e);
      return false;
    }
  }

  /**
   * @brief Clears the current application filter.
   */
  function clearFilter() {
    filteredApps = [];
    appsFiltered();
  }

  // --- Private Implementation ---
  Component.onCompleted: {
    console.log("[LauncherManager] ♻ LauncherManager service started.");
    launchTimes = _stateHandler.load({});
  }
}
