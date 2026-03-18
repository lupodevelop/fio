/// Resource-safe file handle API for `fio`.
///
/// Provides open/close/read/write primitives built on top of platform-native
/// file descriptors (Erlang `IoDevice`, Node.js integer fd).
///
/// ## Preferred usage — `with` (no handle leak possible)
///
/// `handle.with` opens a file, runs a callback, and **always** closes the
/// handle before returning — even if the callback returns an `Error`.
/// Use it with Gleam's `use` syntax for clean, leak-free code:
///
/// ```gleam
/// import fio/handle
/// import gleam/result
///
/// pub fn read_config(path: String) -> Result(String, error.FioError) {
///   use h <- handle.with(path, handle.ReadOnly)
///   handle.read_all(h)
/// }
/// ```
///
/// ## Manual lifecycle — `open` / `close`
///
/// When you need to keep a handle alive across multiple operations and
/// manage the lifetime yourself:
///
/// ```gleam
/// let assert Ok(h) = handle.open("log.txt", handle.AppendOnly)
/// let assert Ok(_) = handle.write(h, "line 1\n")
/// let assert Ok(_) = handle.write(h, "line 2\n")
/// let assert Ok(_) = handle.close(h)
/// ```
///
/// ## Sequential and random access
///
/// `FileHandle` supports both sequential (stream-style) and random-access
/// (seek-based) reads and writes:
///
/// - `read_chunk` / `write` / `write_bits` advance the cursor sequentially.
/// - `seek(h, offset)` jumps to any byte offset from the start of the file.
/// - `tell(h)` reads the current cursor position.
///
/// This means you can mix the two styles freely:
///
/// ```gleam
/// use h <- handle.with(path, handle.ReadOnly)
/// let assert Ok(Some(header)) = handle.read_chunk(h, 16)  // sequential
/// let assert Ok(pos)          = handle.tell(h)             // pos == 16
/// let assert Ok(_)            = handle.seek(h, 0)          // rewind
/// let assert Ok(Some(again))  = handle.read_chunk(h, 16)   // re-read
/// // header == again
/// ```
///
/// ## Design note
///
/// `FileHandle` is intentionally opaque: its raw platform handle is
/// invisible outside this module.
import fio/error.{type FioError}
import fio/internal/io
import gleam/bit_array
import gleam/option.{type Option, None, Some}
import gleam/result

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Mode used when opening a file handle.
pub type OpenMode {
  /// Open for reading only. File must already exist.
  ReadOnly
  /// Open for writing only. Creates the file or truncates it.
  WriteOnly
  /// Open for appending only. Creates the file if absent.
  AppendOnly
}

/// An opaque, resource-safe file handle.
///
/// Always release with `close/1` when done.
/// The internal platform handle (Erlang IoDevice or Node.js fd integer)
/// is invisible outside this module.
pub opaque type FileHandle {
  FileHandle(inner: io.RawHandle)
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// Open a file and return a `FileHandle`.
///
/// Returns `Error(FioError)` if the file cannot be opened (e.g. `Enoent`,
/// `Eacces`). Use `close` to release the underlying OS file descriptor
/// when done.
pub fn open(path: String, mode: OpenMode) -> Result(FileHandle, FioError) {
  let mode_str = case mode {
    ReadOnly -> "r"
    WriteOnly -> "w"
    AppendOnly -> "a"
  }
  io.open_handle(path, mode_str)
  |> result.map(FileHandle)
}

/// Close a `FileHandle`, releasing the underlying OS file descriptor.
pub fn close(handle: FileHandle) -> Result(Nil, FioError) {
  io.close_handle(handle.inner)
}

/// Open a file, run `callback` with the handle, then **always** close it.
///
/// This is the recommended way to use file handles. It is equivalent to
/// try-finally in other languages: the handle is closed even if `callback`
/// returns `Error` or if the Gleam runtime panics.
///
/// Designed for use with Gleam's `use` syntax:
///
/// ```gleam
/// pub fn word_count(path: String) -> Result(Int, error.FioError) {
///   use h <- handle.with(path, handle.ReadOnly)
///   use text <- result.try(handle.read_all(h))
///   Ok(string.split(text, " ") |> list.length)
/// }
/// ```
///
/// The return type of `callback` determines the return type of `with`.
/// The handle is **always** closed before `with` returns.
pub fn with(
  path: String,
  mode: OpenMode,
  callback: fn(FileHandle) -> Result(a, FioError),
) -> Result(a, FioError) {
  use h <- result.try(open(path, mode))
  let outcome = callback(h)
  // Close unconditionally; if close fails and callback succeeded,
  // surface the close error so no failure is silently swallowed.
  case close(h) {
    Ok(_) -> outcome
    Error(close_err) ->
      case outcome {
        // Callback failed already — keep that error, it's more informative.
        Error(_) -> outcome
        // Callback passed but close failed — surface the close error.
        Ok(_) -> Error(close_err)
      }
  }
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

/// Read up to `size` bytes from the **current cursor position** of
/// the handle.
///
/// - `Ok(Some(data))` — a chunk was read; cursor advances by `|data|` bytes.
/// - `Ok(None)` — end of file reached; cursor stays at the end.
/// - `Error(FioError)` — a read error occurred.
///
/// Use `seek` to move the cursor before calling `read_chunk` if you need
/// to read from a specific offset.
///
/// This is the primitive on which higher-level streaming can be built.
pub fn read_chunk(
  handle: FileHandle,
  size: Int,
) -> Result(Option(BitArray), FioError) {
  io.read_chunk(handle.inner, size)
}

/// Read all remaining bytes from the handle into a `BitArray`.
///
/// Reads sequentially in 64 KiB chunks until EOF. Suitable for files of
/// arbitrary size (only the final result is materialised in memory).
pub fn read_all_bits(handle: FileHandle) -> Result(BitArray, FioError) {
  // Tail-recursive implementation in case the compiler does not optimise
  // very deep recursion; on current Gleam/Erlang this becomes a simple loop.
  do_read_all_bits(handle, <<>>)
}

fn do_read_all_bits(
  handle: FileHandle,
  acc: BitArray,
) -> Result(BitArray, FioError) {
  use chunk <- result.try(io.read_chunk(handle.inner, 65_536))
  case chunk {
    None -> Ok(acc)
    Some(data) -> do_read_all_bits(handle, bit_array.append(acc, data))
  }
}

/// Read all remaining content from the handle as a UTF-8 `String`.
///
/// Returns `Error(NotUtf8("(handle)"))` if the bytes are not valid UTF-8.
pub fn read_all(handle: FileHandle) -> Result(String, FioError) {
  use bits <- result.try(read_all_bits(handle))
  bit_array.to_string(bits)
  |> result.map_error(fn(_) { error.NotUtf8("(handle)") })
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/// Write a UTF-8 string to the handle at the **current cursor position**.
///
/// The cursor advances by the number of bytes written.
/// Use `seek` to write at a specific offset.
pub fn write(handle: FileHandle, content: String) -> Result(Nil, FioError) {
  io.write_handle(handle.inner, content)
}

/// Write raw bytes to the handle at the **current cursor position**.
///
/// The cursor advances by the number of bytes written.
/// Use `seek` to write at a specific offset.
pub fn write_bits(
  handle: FileHandle,
  content: BitArray,
) -> Result(Nil, FioError) {
  io.write_handle_bits(handle.inner, content)
}

// ---------------------------------------------------------------------------
// Random access (seek / tell)
// ---------------------------------------------------------------------------

/// Move the file cursor to `position` bytes from the start of the file.
///
/// After `seek`, the next `read_chunk`, `read_all_bits`, `write`, or
/// `write_bits` call will operate from the new offset.
///
/// ```gleam
/// // Re-read the first 10 bytes of a file
/// let assert Ok(h)   = handle.open(path, handle.ReadOnly)
/// let assert Ok(_)   = handle.seek(h, 0)   // already at 0 after open
/// let assert Ok(a)   = handle.read_chunk(h, 10)
/// let assert Ok(_)   = handle.seek(h, 0)   // back to start
/// let assert Ok(b)   = handle.read_chunk(h, 10)
/// // a == b
/// ```
///
/// **Append mode note**: in `AppendOnly` mode, `seek` moves the read cursor
/// (useful for mixed-use handles) but writes are always forced to end-of-file
/// by the OS regardless of cursor position. This is standard POSIX behaviour.
///
/// Passing an offset beyond the end of the file is allowed on most
/// platforms (a subsequent write will create a sparse region).
pub fn seek(handle: FileHandle, position: Int) -> Result(Nil, FioError) {
  io.seek(handle.inner, position)
}

/// Return the current byte offset of the file cursor.
///
/// Useful to record a position before reading a block so you can return
/// to it later with `seek`.
///
/// ```gleam
/// let assert Ok(start) = handle.tell(h)           // save position
/// let assert Ok(_)     = handle.read_chunk(h, 64)  // advance cursor
/// let assert Ok(_)     = handle.seek(h, start)     // restore position
/// ```
pub fn tell(handle: FileHandle) -> Result(Int, FioError) {
  io.tell(handle.inner)
}
