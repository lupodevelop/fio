/// Path operations abstraction layer delegating to `filepath`.
import filepath
import gleam/string

/// Join two path segments.
pub fn join(left: String, right: String) -> String {
  filepath.join(left, right)
}

/// Split a path into its segments.
pub fn split(path: String) -> List(String) {
  filepath.split(path)
}

/// Get the base name (filename) of a path.
pub fn base_name(path: String) -> String {
  filepath.base_name(path)
}

/// Get the directory portion of a path.
pub fn directory_name(path: String) -> String {
  filepath.directory_name(path)
}

/// Get the file extension (without dot).
pub fn extension(path: String) -> Result(String, Nil) {
  filepath.extension(path)
}

/// Remove the extension from a path.
pub fn strip_extension(path: String) -> String {
  filepath.strip_extension(path)
}

/// Check if a path is absolute.
pub fn is_absolute(path: String) -> Bool {
  filepath.is_absolute(path)
}

/// Expand/normalize a path, resolving `.` and `..` segments.
/// Returns Error(Nil) if `..` would go above the root.
pub fn expand(path: String) -> Result(String, Nil) {
  filepath.expand(path)
}

// --- fio-specific additions (not in filepath) ---

/// Get the stem (filename without extension).
pub fn stem(path: String) -> String {
  let name = base_name(path)
  case extension(path) {
    Ok(_) -> strip_extension(name)
    Error(_) -> name
  }
}

/// Change the extension of a path.
pub fn with_extension(path: String, ext: String) -> String {
  strip_extension(path) <> "." <> ext
}

/// Join a list of path segments.
pub fn join_all(segments: List(String)) -> String {
  // An empty list is ambiguous; returning "." is often more useful than
  // an empty string which can confuse callers (e.g. comparing to a path).  
  // This aligns with the behaviour of many CLI utilities.
  case segments {
    [] -> "."
    [first, ..rest] -> join_all_loop(first, rest)
  }
}

fn join_all_loop(acc: String, segments: List(String)) -> String {
  case segments {
    [] -> acc
    [next, ..rest] -> join_all_loop(join(acc, next), rest)
  }
}

fn is_windows_drive(path: String) -> Bool {
  // True if the path begins with a drive letter followed by ':'
  case string.length(path) >= 2 {
    True -> {
      let first = string.lowercase(string.slice(path, 0, 1))
      let second = string.slice(path, 1, 1)

      second == ":" && string.contains("abcdefghijklmnopqrstuvwxyz", first)
    }
    False -> False
  }
}

/// Validate that a path is a safe relative path (does not escape root).
///
/// This is primarily intended for sanitizing user-provided paths. On Windows,
/// backslashes are treated as separators and are normalized to forward slashes.
pub fn safe_relative(path: String) -> Result(String, Nil) {
  let normalized = normalize_separators(path)

  case is_absolute(normalized) || is_windows_drive(normalized) {
    True -> Error(Nil)
    False ->
      case expand(normalized) {
        Ok(expanded) ->
          case is_absolute(expanded) {
            True -> Error(Nil)
            False -> Ok(expanded)
          }
        Error(_) -> Error(Nil)
      }
  }
}

fn normalize_separators(path: String) -> String {
  // Convert Windows backslashes to forward slashes so that `expand` and
  // path normalization behave consistently across platforms.
  string.join(string.split(path, "\\"), "/")
}
