/// Moves [delta] entries through the browser's history. Only the web has
/// one, so elsewhere this does nothing.
void browserHistoryGo(int delta) {}

/// The state the app stored with the browser's current history entry, which
/// survives a reload. Null off the web.
Object? browserHistoryState() => null;
