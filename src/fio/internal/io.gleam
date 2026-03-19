/// Internal I/O operations. Bridges FFI to Gleam types.
import fio/error.{type FioError}
import fio/types.{type FileInfo, type FilePermissions}
import gleam/option.{type Option}

/// Read a file as a UTF-8 string.
pub fn read(path: String) -> Result(String, FioError) {
  do_read(path) |> map_ffi_error
}

/// Read a file as raw bytes.
pub fn read_bits(path: String) -> Result(BitArray, FioError) {
  do_read_bits(path) |> map_ffi_error
}

/// Write a string to a file (overwrites).
pub fn write(path: String, content: String) -> Result(Nil, FioError) {
  do_write(path, content) |> map_ffi_error
}

/// Write bytes to a file (overwrites).
pub fn write_bits(path: String, content: BitArray) -> Result(Nil, FioError) {
  do_write_bits(path, content) |> map_ffi_error
}

/// Write a string atomically (write to a temp sibling, then rename).
/// Readers never observe partial content;
/// returns `AtomicFailed` when the temp write or rename fails.
pub fn write_atomic(path: String, content: String) -> Result(Nil, FioError) {
  do_write_atomic(path, content) |> map_ffi_error
}

/// Write bytes atomically (write to a temp sibling, then rename).
pub fn write_bits_atomic(
  path: String,
  content: BitArray,
) -> Result(Nil, FioError) {
  do_write_bits_atomic(path, content) |> map_ffi_error
}

/// Append a string to a file.
pub fn append(path: String, content: String) -> Result(Nil, FioError) {
  do_append(path, content) |> map_ffi_error
}

/// Append bytes to a file.
pub fn append_bits(path: String, content: BitArray) -> Result(Nil, FioError) {
  do_append_bits(path, content) |> map_ffi_error
}

/// Delete a file (not a directory).
pub fn delete_file(path: String) -> Result(Nil, FioError) {
  do_delete_file(path) |> map_ffi_error
}

/// Delete an empty directory.
pub fn delete_directory(path: String) -> Result(Nil, FioError) {
  do_delete_directory(path) |> map_ffi_error
}

/// Delete a file or directory recursively.
pub fn delete_recursive(path: String) -> Result(Nil, FioError) {
  do_delete_directory_recursive(path) |> map_ffi_error
}

/// Check if a path exists.
pub fn exists(path: String) -> Bool {
  do_exists(path)
}

/// Get file metadata (follows symlinks).
pub fn file_info(path: String) -> Result(FileInfo, FioError) {
  do_file_info(path) |> map_file_info_result
}

/// Get file metadata (does NOT follow symlinks).
pub fn link_info(path: String) -> Result(FileInfo, FioError) {
  do_link_info(path) |> map_file_info_result
}

/// Check if path is a directory.
pub fn is_directory(path: String) -> Result(Bool, FioError) {
  do_is_directory(path) |> map_ffi_error
}

/// Check if path is a regular file.
pub fn is_file(path: String) -> Result(Bool, FioError) {
  do_is_file(path) |> map_ffi_error
}

/// Check if path is a symbolic link.
pub fn is_symlink(path: String) -> Result(Bool, FioError) {
  do_is_symlink(path) |> map_ffi_error
}

/// Copy a file.
pub fn copy_file(src: String, dest: String) -> Result(Nil, FioError) {
  do_copy_file(src, dest) |> map_ffi_error
}

/// Rename/move a file or directory.
pub fn rename(src: String, dest: String) -> Result(Nil, FioError) {
  do_rename(src, dest) |> map_ffi_error
}

/// Create a symbolic link.
pub fn create_symlink(
  target target: String,
  link link: String,
) -> Result(Nil, FioError) {
  do_create_symlink(target, link) |> map_ffi_error
}

/// Create a hard link.
pub fn create_hard_link(
  target target: String,
  link link: String,
) -> Result(Nil, FioError) {
  do_create_hard_link(target, link) |> map_ffi_error
}

/// Set file permissions (octal).
pub fn set_permissions_octal(path: String, mode: Int) -> Result(Nil, FioError) {
  do_set_permissions(path, mode) |> map_ffi_error
}

/// Set file permissions using FilePermissions type.
pub fn set_permissions(
  path: String,
  permissions: FilePermissions,
) -> Result(Nil, FioError) {
  let mode = types.file_permissions_to_octal(permissions)
  do_set_permissions(path, mode) |> map_ffi_error
}

/// Create a directory (parent must exist).
pub fn create_directory(path: String) -> Result(Nil, FioError) {
  do_make_directory(path) |> map_ffi_error
}

/// Create a directory and all parents.
pub fn create_directory_all(path: String) -> Result(Nil, FioError) {
  do_make_directory_p(path) |> map_ffi_error
}

/// List directory contents (names only).
pub fn list_directory(path: String) -> Result(List(String), FioError) {
  do_list_directory(path) |> map_ffi_error
}

/// Get current working directory.
pub fn current_directory() -> Result(String, FioError) {
  do_current_directory() |> map_ffi_error
}

/// Get system temp directory.
pub fn tmp_dir() -> String {
  do_get_tmp_dir()
}

/// Touch a file — create if not exists, update mtime if it does.
pub fn touch(path: String) -> Result(Nil, FioError) {
  do_touch(path) |> map_ffi_error
}

/// Read the target of a symbolic link.
pub fn read_link(path: String) -> Result(String, FioError) {
  do_read_link(path) |> map_ffi_error
}

/// Compute file checksum.
pub fn checksum(path: String, algorithm: String) -> Result(String, FioError) {
  do_checksum(path, algorithm) |> map_ffi_error
}

// --- File Handles ---

/// Open a file with the given mode string ("r", "w", "a").
/// Returns a platform-native `RawHandle`.
/// Call `close_handle` when done.
pub fn open_handle(path: String, mode: String) -> Result(RawHandle, FioError) {
  do_open_handle(path, mode) |> map_ffi_error
}

/// Close a `RawHandle`, releasing the underlying OS file descriptor.
pub fn close_handle(handle: RawHandle) -> Result(Nil, FioError) {
  do_close_handle(handle) |> map_ffi_error
}

/// Read up to `size` bytes from the handle.
/// Returns `Ok(Some(data))` for a chunk, `Ok(None)` at EOF.
pub fn read_chunk(
  handle: RawHandle,
  size: Int,
) -> Result(Option(BitArray), FioError) {
  do_read_chunk(handle, size) |> map_ffi_error
}

/// Write a UTF-8 string to the handle at the current position.
pub fn write_handle(handle: RawHandle, content: String) -> Result(Nil, FioError) {
  do_write_handle(handle, content) |> map_ffi_error
}

/// Write raw bytes to the handle at the current position.
pub fn write_handle_bits(
  handle: RawHandle,
  content: BitArray,
) -> Result(Nil, FioError) {
  do_write_handle_bits(handle, content) |> map_ffi_error
}

/// Move the file cursor to `position` bytes from the start of the file.
/// The next `read_chunk` or `write_handle` call will operate from that offset.
pub fn seek(handle: RawHandle, position: Int) -> Result(Nil, FioError) {
  do_seek_handle(handle, position) |> map_ffi_error
}

/// Return the current byte offset of the file cursor.
pub fn tell(handle: RawHandle) -> Result(Int, FioError) {
  do_tell_handle(handle) |> map_ffi_error
}

// --- FFI bindings ---

@external(erlang, "fio_ffi", "read_file")
@external(javascript, "../../fio_ffi.mjs", "read_file")
fn do_read(path: String) -> Result(String, FfiError)

@external(erlang, "fio_ffi", "read_file_bits")
@external(javascript, "../../fio_ffi.mjs", "read_file_bits")
fn do_read_bits(path: String) -> Result(BitArray, FfiError)

@external(erlang, "fio_ffi", "write_file")
@external(javascript, "../../fio_ffi.mjs", "write_file")
fn do_write(path: String, content: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "write_file_bits")
@external(javascript, "../../fio_ffi.mjs", "write_file_bits")
fn do_write_bits(path: String, content: BitArray) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "write_file_atomic")
@external(javascript, "../../fio_ffi.mjs", "write_file_atomic")
fn do_write_atomic(path: String, content: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "write_file_bits_atomic")
@external(javascript, "../../fio_ffi.mjs", "write_file_bits_atomic")
fn do_write_bits_atomic(
  path: String,
  content: BitArray,
) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "append_file")
@external(javascript, "../../fio_ffi.mjs", "append_file")
fn do_append(path: String, content: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "append_file_bits")
@external(javascript, "../../fio_ffi.mjs", "append_file_bits")
fn do_append_bits(path: String, content: BitArray) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "delete_file")
@external(javascript, "../../fio_ffi.mjs", "delete_file")
fn do_delete_file(path: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "delete_directory")
@external(javascript, "../../fio_ffi.mjs", "delete_directory")
fn do_delete_directory(path: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "delete_directory_recursive")
@external(javascript, "../../fio_ffi.mjs", "delete_directory_recursive")
fn do_delete_directory_recursive(path: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "file_exists")
@external(javascript, "../../fio_ffi.mjs", "file_exists")
fn do_exists(path: String) -> Bool

@external(erlang, "fio_ffi", "file_info")
@external(javascript, "../../fio_ffi.mjs", "file_info")
fn do_file_info(path: String) -> Result(RawFileInfo, FfiError)

@external(erlang, "fio_ffi", "link_info")
@external(javascript, "../../fio_ffi.mjs", "link_info")
fn do_link_info(path: String) -> Result(RawFileInfo, FfiError)

@external(erlang, "fio_ffi", "is_directory")
@external(javascript, "../../fio_ffi.mjs", "is_directory")
fn do_is_directory(path: String) -> Result(Bool, FfiError)

@external(erlang, "fio_ffi", "is_file")
@external(javascript, "../../fio_ffi.mjs", "is_file")
fn do_is_file(path: String) -> Result(Bool, FfiError)

@external(erlang, "fio_ffi", "is_symlink")
@external(javascript, "../../fio_ffi.mjs", "is_symlink")
fn do_is_symlink(path: String) -> Result(Bool, FfiError)

@external(erlang, "fio_ffi", "make_directory")
@external(javascript, "../../fio_ffi.mjs", "make_directory")
fn do_make_directory(path: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "make_directory_p")
@external(javascript, "../../fio_ffi.mjs", "make_directory_p")
fn do_make_directory_p(path: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "list_directory")
@external(javascript, "../../fio_ffi.mjs", "list_directory")
fn do_list_directory(path: String) -> Result(List(String), FfiError)

@external(erlang, "fio_ffi", "copy_file")
@external(javascript, "../../fio_ffi.mjs", "copy_file")
fn do_copy_file(src: String, dest: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "rename_file")
@external(javascript, "../../fio_ffi.mjs", "rename_file")
fn do_rename(src: String, dest: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "create_symlink")
@external(javascript, "../../fio_ffi.mjs", "create_symlink")
fn do_create_symlink(target: String, link: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "create_hard_link")
@external(javascript, "../../fio_ffi.mjs", "create_hard_link")
fn do_create_hard_link(target: String, link: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "set_permissions")
@external(javascript, "../../fio_ffi.mjs", "set_permissions")
fn do_set_permissions(path: String, mode: Int) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "current_directory")
@external(javascript, "../../fio_ffi.mjs", "current_directory")
fn do_current_directory() -> Result(String, FfiError)

@external(erlang, "fio_ffi", "get_tmp_dir")
@external(javascript, "../../fio_ffi.mjs", "get_tmp_dir")
fn do_get_tmp_dir() -> String

@external(erlang, "fio_ffi", "touch")
@external(javascript, "../../fio_ffi.mjs", "touch")
fn do_touch(path: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "unique_name")
@external(javascript, "../../fio_ffi.mjs", "unique_name")
pub fn unique_name(prefix: String) -> String

@external(erlang, "fio_ffi", "read_link")
@external(javascript, "../../fio_ffi.mjs", "read_link")
fn do_read_link(path: String) -> Result(String, FfiError)

@external(erlang, "fio_ffi", "checksum")
@external(javascript, "../../fio_ffi.mjs", "checksum")
fn do_checksum(path: String, algo: String) -> Result(String, FfiError)

@external(erlang, "fio_ffi", "open_handle")
@external(javascript, "../../fio_ffi.mjs", "open_handle")
fn do_open_handle(path: String, mode: String) -> Result(RawHandle, FfiError)

@external(erlang, "fio_ffi", "close_handle")
@external(javascript, "../../fio_ffi.mjs", "close_handle")
fn do_close_handle(handle: RawHandle) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "read_chunk")
@external(javascript, "../../fio_ffi.mjs", "read_chunk")
fn do_read_chunk(
  handle: RawHandle,
  size: Int,
) -> Result(Option(BitArray), FfiError)

@external(erlang, "fio_ffi", "write_handle")
@external(javascript, "../../fio_ffi.mjs", "write_handle")
fn do_write_handle(handle: RawHandle, content: String) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "write_handle_bits")
@external(javascript, "../../fio_ffi.mjs", "write_handle_bits")
fn do_write_handle_bits(
  handle: RawHandle,
  content: BitArray,
) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "seek_handle")
@external(javascript, "../../fio_ffi.mjs", "seek_handle")
fn do_seek_handle(handle: RawHandle, position: Int) -> Result(Nil, FfiError)

@external(erlang, "fio_ffi", "tell_handle")
@external(javascript, "../../fio_ffi.mjs", "tell_handle")
fn do_tell_handle(handle: RawHandle) -> Result(Int, FfiError)

// --- FFI error mapping ---

/// Raw FFI error type mapped to `FioError` by the bridge.
type FfiError

/// Raw file info tuple from FFI.
type RawFileInfo

/// Platform-native file handle. Opaque to callers outside this package.
/// Obtain via `open_handle`, release via `close_handle`.
/// Public so that `fio/handle` can wrap it in the typed `FileHandle`.
pub type RawHandle

/// Map FFI error to FioError. The actual mapping is done at the FFI boundary —
/// each platform FFI returns atoms/objects that match FioError constructor names.
@external(erlang, "fio_ffi_bridge", "map_error")
@external(javascript, "../../fio_ffi_bridge.mjs", "map_error")
fn ffi_error_to_fio(err: FfiError) -> FioError

@external(erlang, "fio_ffi_bridge", "map_file_info")
@external(javascript, "../../fio_ffi_bridge.mjs", "map_file_info")
fn ffi_raw_to_file_info(raw: RawFileInfo) -> FileInfo

fn map_ffi_error(result: Result(a, FfiError)) -> Result(a, FioError) {
  case result {
    Ok(value) -> Ok(value)
    Error(err) -> Error(ffi_error_to_fio(err))
  }
}

fn map_file_info_result(
  result: Result(RawFileInfo, FfiError),
) -> Result(FileInfo, FioError) {
  case result {
    Ok(raw) -> Ok(ffi_raw_to_file_info(raw))
    Error(err) -> Error(ffi_error_to_fio(err))
  }
}
