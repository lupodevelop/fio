import fio/error.{type FioError}
import fio/internal/io as internal
import fio/path
import fio/recursive
import fio/types.{type FileInfo, type FilePermissions}
import gleam/result

// Reading

/// Read a UTF-8 text file. Returns `NotUtf8(path)` on invalid UTF-8.
pub fn read(path: String) -> Result(String, FioError) {
  internal.read(path)
}

/// Read a file as raw bytes (`BitArray`).
pub fn read_bits(path: String) -> Result(BitArray, FioError) {
  internal.read_bits(path)
}

// Writing

/// Write UTF-8 text to a file (creates/overwrites).
pub fn write(path: String, content: String) -> Result(Nil, FioError) {
  internal.write(path, content)
}

/// Write raw bytes (`BitArray`) to a file (creates/overwrites).
pub fn write_bits(path: String, content: BitArray) -> Result(Nil, FioError) {
  internal.write_bits(path, content)
}

/// Append UTF-8 text to a file (creates if missing).
pub fn append(path: String, content: String) -> Result(Nil, FioError) {
  internal.append(path, content)
}

/// Append raw bytes (`BitArray`) to a file.
pub fn append_bits(path: String, content: BitArray) -> Result(Nil, FioError) {
  internal.append_bits(path, content)
}

/// Write UTF-8 text atomically: writes to a sibling temp file, then renames
/// it into place with a single `rename(2)` syscall.
/// Readers never observe partial content. Returns `AtomicFailed` on error.
pub fn write_atomic(path: String, content: String) -> Result(Nil, FioError) {
  internal.write_atomic(path, content)
}

/// Write raw bytes (`BitArray`) atomically.
/// Same atomic guarantee as `write_atomic`.
pub fn write_bits_atomic(
  path: String,
  content: BitArray,
) -> Result(Nil, FioError) {
  internal.write_bits_atomic(path, content)
}

// Deleting

/// Delete a file (not a directory).
pub fn delete(path: String) -> Result(Nil, FioError) {
  internal.delete_file(path)
}

/// Delete an empty directory.
pub fn delete_directory(path: String) -> Result(Nil, FioError) {
  internal.delete_directory(path)
}

/// Delete a path recursively; idempotent (succeeds if missing).
pub fn delete_all(path: String) -> Result(Nil, FioError) {
  internal.delete_recursive(path)
}

// Querying

/// Check if a path exists (file, directory, or symlink).
pub fn exists(path: String) -> Bool {
  internal.exists(path)
}

/// Get file metadata (follows symlinks).
pub fn file_info(path: String) -> Result(FileInfo, FioError) {
  internal.file_info(path)
}

/// Get file metadata without following symlinks.
pub fn link_info(path: String) -> Result(FileInfo, FioError) {
  internal.link_info(path)
}

/// Check if a path is a directory (follows symlinks).
pub fn is_directory(path: String) -> Result(Bool, FioError) {
  internal.is_directory(path)
}

/// Check if a path is a regular file (follows symlinks).
pub fn is_file(path: String) -> Result(Bool, FioError) {
  internal.is_file(path)
}

/// Check if a path is a symbolic link (does not follow symlinks).
pub fn is_symlink(path: String) -> Result(Bool, FioError) {
  internal.is_symlink(path)
}

// Copy & Rename

/// Copy a file from source to destination.
pub fn copy(src: String, dest: String) -> Result(Nil, FioError) {
  internal.copy_file(src, dest)
}

/// Rename or move a file or directory.
pub fn rename(src: String, dest: String) -> Result(Nil, FioError) {
  internal.rename(src, dest)
}

// Symlinks & Links

/// Create a symbolic link.
pub fn create_symlink(
  target target: String,
  link link: String,
) -> Result(Nil, FioError) {
  internal.create_symlink(target:, link:)
}

/// Create a hard link to an existing file.
pub fn create_hard_link(
  target target: String,
  link link: String,
) -> Result(Nil, FioError) {
  internal.create_hard_link(target:, link:)
}

/// Read the target path of a symbolic link.
pub fn read_link(path: String) -> Result(String, FioError) {
  internal.read_link(path)
}

// Permissions

/// Set file permissions using the `FilePermissions` type.
pub fn set_permissions(
  path: String,
  permissions: FilePermissions,
) -> Result(Nil, FioError) {
  internal.set_permissions(path, permissions)
}

/// Set file permissions with an octal integer.
pub fn set_permissions_octal(path: String, mode: Int) -> Result(Nil, FioError) {
  internal.set_permissions_octal(path, mode)
}

// Directories

/// Create a directory. Parent directory must exist.
pub fn create_directory(path: String) -> Result(Nil, FioError) {
  internal.create_directory(path)
}

/// Create a directory and all parent directories.
pub fn create_directory_all(path: String) -> Result(Nil, FioError) {
  internal.create_directory_all(path)
}

/// List the contents of a directory (names only).
pub fn list(path: String) -> Result(List(String), FioError) {
  internal.list_directory(path)
}

// Utility

/// Get the current working directory.
pub fn current_directory() -> Result(String, FioError) {
  internal.current_directory()
}

/// Get the system temporary directory path.
pub fn tmp_dir() -> String {
  internal.tmp_dir()
}

/// Touch a file: create or update modification time.
pub fn touch(path: String) -> Result(Nil, FioError) {
  internal.touch(path)
}

// --- Temporary Files ---

/// Run a callback with a path to a temporary file that is automatically
/// deleted when the callback returns (even if it returns an Error).
pub fn with_temp_file(
  callback: fn(String) -> Result(a, FioError),
) -> Result(a, FioError) {
  let path =
    path.join(internal.tmp_dir(), internal.unique_name("fio_tmp_file_"))
  let result = callback(path)
  let _ = internal.delete_file(path)
  // Best effort cleanup
  result
}

/// Run a callback with a path to a temporary directory that is automatically
/// deleted (recursively) when the callback returns.
pub fn with_temp_directory(
  callback: fn(String) -> Result(a, FioError),
) -> Result(a, FioError) {
  let path = path.join(internal.tmp_dir(), internal.unique_name("fio_tmp_dir_"))
  let result =
    internal.create_directory(path)
    |> result.try(fn(_) { callback(path) })

  let _ = internal.delete_recursive(path)
  // Best effort cleanup
  result
}

// Recursive Operations

/// Recursively list files and directories (paths relative to `path`).
pub fn list_recursive(path: String) -> Result(List(String), FioError) {
  recursive.list_recursive(path)
}

/// Recursively copy a directory and its contents.
pub fn copy_directory(src: String, dest: String) -> Result(Nil, FioError) {
  recursive.copy_directory(src, dest)
}

// --- Checksums ---

/// Compute a file checksum using the specified algorithm.
/// Returns a hex-encoded string.
pub fn checksum(
  path: String,
  algorithm: types.HashAlgorithm,
) -> Result(String, FioError) {
  let algo_str = case algorithm {
    types.Sha256 -> "sha256"
    types.Sha512 -> "sha512"
    types.Md5 -> "md5"
  }
  internal.checksum(path, algo_str)
}

/// Verify that a file's checksum matches the expected hex-encoded hash.
pub fn verify_checksum(
  path: String,
  expected: String,
  algorithm: types.HashAlgorithm,
) -> Result(Bool, FioError) {
  checksum(path, algorithm)
  |> result.map(fn(actual) { actual == expected })
}

// --- Path helpers (facade) ---

/// Join two path segments.
pub fn join(left: String, right: String) -> String {
  path.join(left, right)
}

/// Split a path into its segments.
pub fn split(path_str: String) -> List(String) {
  path.split(path_str)
}

/// Get the base name (filename) of a path.
pub fn base_name(path_str: String) -> String {
  path.base_name(path_str)
}

/// Get the directory portion of a path.
pub fn directory_name(path_str: String) -> String {
  path.directory_name(path_str)
}

/// Get the file extension (without dot).
pub fn extension(path_str: String) -> Result(String, Nil) {
  path.extension(path_str)
}

/// Remove the extension from a path.
pub fn strip_extension(path_str: String) -> String {
  path.strip_extension(path_str)
}

/// Get the stem (filename without extension).
pub fn stem(path_str: String) -> String {
  path.stem(path_str)
}

/// Change the extension of a path.
pub fn with_extension(path_str: String, ext: String) -> String {
  path.with_extension(path_str, ext)
}

/// Join a list of path segments.
pub fn join_all(segments: List(String)) -> String {
  path.join_all(segments)
}

/// Check if a path is absolute.
pub fn is_absolute(path_str: String) -> Bool {
  path.is_absolute(path_str)
}

/// Expand/normalize a path, resolving `.` and `..` segments.
/// Returns `Error(Nil)` if `..` would go above the root.
pub fn expand(path_str: String) -> Result(String, Nil) {
  path.expand(path_str)
}

/// Validate that a path is a safe relative path (does not escape root).
/// On Windows it also normalizes backslashes into `/`.
pub fn safe_relative(path_str: String) -> Result(String, Nil) {
  path.safe_relative(path_str)
}
