# fio Documentation

This document provides a full reference for `fio`’s public API, helpers,
file-handle abstractions, and platform notes.

## API Overview

### Reading and Writing

| Function | Description |
|---|---|
| `fio.read(path)` | Read file as UTF-8 string |
| `fio.read_bits(path)` | Read file as raw bytes |
| `fio.write(path, content)` | Write string (creates/overwrites) |
| `fio.write_bits(path, bytes)` | Write bytes (creates/overwrites) |
| `fio.write_atomic(path, content)` | Write string atomically (temp + rename) |
| `fio.write_bits_atomic(path, bytes)` | Write bytes atomically (temp + rename) |
| `fio.append(path, content)` | Append string |
| `fio.append_bits(path, bytes)` | Append bytes |

### High-level Helpers

| Function | Description |
|---|---|
| `fio.ensure_file(path)` | Create file if it does not exist; no-op otherwise |
| `fio.copy_if_newer(src, dest)` | Copy only when `src` is newer than `dest`; returns `Bool` |
| `fio.write_new(path, content)` | Write only if the file does not exist; returns `Eexist` if it does |
| `fio.write_if_changed(path, content)` | Write only when content differs; returns `Bool` |
| `fio.read_lines(path)` | Read a file and split it into lines |
| `fio.write_lines(path, lines)` | Join lines with newline and write to a file |
| `fio.atomic(path, callback)` | Atomically write via a temporary path then rename |
| `fio.stream(path)` | Read a file in chunks of UTF-8 strings |
| `fio.stream_bytes(path)` | Read a file in chunks of raw bytes |
| `fio.read_fold(path, chunk_size, acc, f)` | Fold over file chunks without loading it all into memory |

### Context helpers

| Function | Description |
|---|---|
| `fio.with_opened(path, mode, callback)` | Open a handle, run the callback, close automatically |
| `fio.with_writer(path, callback)` | Open a write handle, run the callback, close automatically |

### File Operations

| Function | Description |
|---|---|
| `fio.copy(src, dest)` | Copy a file |
| `fio.copy_directory(src, dest)` | Copy a directory recursively |
| `fio.rename(src, dest)` | Rename/move file or directory |
| `fio.delete(path)` | Delete a file |
| `fio.delete_directory(path)` | Delete an empty directory |
| `fio.delete_all(path)` | Delete recursively (idempotent) |
| `fio.touch(path)` | Create file or update modification time |
| `fio.list_recursive(path)` | List all files in a directory recursively |

> **Note:** `delete_all` does **not** follow directory symlinks. A symlink itself is deleted but its target is left untouched.

### Querying

| Function | Description |
|---|---|
| `fio.exists(path)` | Check if path exists (files, directories, symlinks) |
| `fio.is_file(path)` | Check if path is a regular file |
| `fio.is_directory(path)` | Check if path is a directory |
| `fio.is_symlink(path)` | Check if path is a symbolic link |
| `fio.file_info(path)` | Get file metadata (follows symlinks) |
| `fio.link_info(path)` | Get metadata without following symlinks |

### Error helpers

| Function | Description |
|---|---|
| `fio.explain(error)` | Format a `FioError` as a CLI-friendly string |

### Symlinks and Links

| Function | Description |
|---|---|
| `fio.create_symlink(target:, link:)` | Create a symbolic link |
| `fio.create_hard_link(target:, link:)` | Create a hard link |
| `fio.read_link(path)` | Read symlink target path |

### Permissions

| Function | Description |
|---|---|
| `fio.set_permissions(path, perms)` | Set permissions (type-safe) |
| `fio.set_permissions_octal(path, mode)` | Set permissions (octal integer) |

### Directories

| Function | Description |
|---|---|
| `fio.create_directory(path)` | Create a directory |
| `fio.create_directory_all(path)` | Create directory and parents |
| `fio.list(path)` | List directory contents |

### Utility

| Function | Description |
|---|---|
| `fio.current_directory()` | Get working directory |
| `fio.tmp_dir()` | Get system temp directory |

## File Handles (`fio/handle`)

For large files or streaming scenarios where loading the entire content into memory is not acceptable, use the `fio/handle` module.

```gleam
import fio/handle

// Read a large log file chunk by chunk (64 KiB at a time)
pub fn count_bytes(path: String) -> Result(Int, error.FioError) {
  use h <- handle.with(path, handle.ReadOnly)
  handle.fold_chunks(h, 65_536, 0, fn(acc, chunk) {
    acc + bit_array.byte_size(chunk)
  })
}

// Write to a file with explicit lifecycle control
pub fn write_lines(path: String, lines: List(String)) -> Result(Nil, error.FioError) {
  use h <- handle.with(path, handle.WriteOnly)
  list.try_each(lines, fn(line) { handle.write(h, line <> "\n") })
}
```

| Function | Description |
|---|---|
| `handle.open(path, mode)` | Open a file (`ReadOnly`, `WriteOnly`, `AppendOnly`) |
| `handle.close(handle)` | Close the handle, release the OS file descriptor |
| `handle.with(path, mode, callback)` | Open, run callback, always close (recommended) |
| `handle.read_chunk(handle, size)` | Read up to `size` bytes; `Ok(None)` at EOF |
| `handle.read_all_bits(handle)` | Read all remaining bytes as `BitArray` |
| `handle.read_all(handle)` | Read all remaining content as UTF-8 `String` |
| `handle.fold_chunks(handle, size, acc, f)` | Fold over all remaining chunks |
| `handle.write(handle, content)` | Write a UTF-8 string |
| `handle.write_bits(handle, bytes)` | Write raw bytes |
| `handle.seek(handle, offset)` | Move cursor to byte offset from start |
| `handle.tell(handle)` | Return current byte offset |

> **Note**: `FileHandle` is intentionally opaque. Always call `close` when done, or use `handle.with` which closes automatically.

## JSON Helpers (`fio/json`)

`fio/json` provides I/O wrappers that compose cleanly with any encoder/decoder function. It does not bundle a JSON parser; bring your own (e.g. `gleam_json`).

```gleam
import fio/json as fjson
import gleam_json

// Read and decode
case fjson.read_json("config.json", gleam_json.decode_string) {
  Ok(config) -> use_config(config)
  Error(fjson.IoError(e)) -> io.println("I/O failed: " <> error.describe(e))
  Error(fjson.ParseError(e)) -> io.println("Bad JSON: " <> e)
}

// Encode and write atomically
fjson.write_json_atomic("config.json", my_value, encode_fn)
```

| Function | Description |
|---|---|
| `fjson.read_json(path, decoder)` | Read file and run `decoder` on contents |
| `fjson.write_json_atomic(path, value, encoder)` | Encode and write atomically |

The `JsonError(e)` type has two variants: `IoError(FioError)` and `ParseError(e)`.

## Observability (`fio/observer`)

Instrument any fio call without restructuring your code.

```gleam
import fio
import fio/observer
import gleam/io

fn log_sink(event: observer.Event) -> Nil {
  io.println(observer.format(event))
}

pub fn main() {
  fio.read("config.json")
  |> observer.trace("read", "config.json", log_sink)
}
```

For byte-oriented operations such as `read_bits`, use `trace_bytes` to infer the byte count automatically.

```gleam
fio.read_bits("archive.bin")
|> observer.trace_bytes("read_bits", "archive.bin", log_sink)
```

| Function | Description |
|---|---|
| `observer.emit(result, op, path, bytes, sink)` | Emit a structured `Event` and return `result` unchanged |
| `observer.trace(result, op, path, sink)` | Emit an event with `bytes = None` |
| `observer.trace_bytes(result, op, path, sink)` | Emit an event and infer `bytes` from `BitArray` results |
| `observer.format(event)` | Format an event as a human-readable string |
| `observer.fan_out(first, second)` | Combine two sinks so both receive every event |
| `observer.noop_sink` | Sink that discards all events |

## Path Operations (`fio/path`)

| Function | Description |
|---|---|
| `path.join(a, b)` | Join two path segments |
| `path.join_all(segments)` | Join a list of segments |
| `path.split(path)` | Split path into segments |
| `path.base_name(path)` | Get filename portion |
| `path.directory_name(path)` | Get directory portion |
| `path.extension(path)` | Get file extension |
| `path.stem(path)` | Get filename without extension |
| `path.with_extension(path, ext)` | Change extension |
| `path.strip_extension(path)` | Remove extension |
| `path.is_absolute(path)` | Check if path is absolute |
| `path.expand(path)` | Normalize `.` and `..` segments |
| `path.safe_relative(path)` | Validate path does not escape via `..` |

## Atomic Writes

`write_atomic` and `write_bits_atomic` implement the write-to-temp-then-rename pattern, which is the standard POSIX-safe way to update files:

```gleam
import fio
import fio/error

pub fn save_config(path: String, json: String) -> Result(Nil, error.FioError) {
  // Readers always see either the old file or the complete new one.
  // A crash between the write and rename leaves a harmless .tmp sibling.
  fio.write_atomic(path, json)
}
```

Use `write_atomic` whenever:
- The file is read by other processes while it may be updated.
- A crash or power loss must not leave a partially-written file.
- The file is a config, lock, or state file.

Use plain `write` for scratch files, logs, or temporary output where partial writes are acceptable.

## Error Handling

fio uses `FioError`: 39 POSIX-style error constructors plus 7 semantic variants. Each error has a human-readable description via `error.describe`:

```gleam
import fio
import fio/error.{type FioError, Enoent, Eacces, NotUtf8}

case fio.read("data.bin") {
  Ok(text) -> use(text)
  Error(Enoent) -> io.println("Not found")
  Error(Eacces) -> io.println("Permission denied")
  Error(NotUtf8(path)) -> {
    // File exists but is not valid UTF-8 -- use read_bits instead
    let assert Ok(bytes) = fio.read_bits(path)
    use_bytes(bytes)
  }
  Error(e) -> io.println(error.describe(e))
}
```

## Type-Safe Permissions

```gleam
import fio
import fio/types.{FilePermissions, Read, Write, Execute}
import gleam/set

let perms = FilePermissions(
  user: set.from_list([Read, Write, Execute]),
  group: set.from_list([Read, Execute]),
  other: set.from_list([Read]),
)
fio.set_permissions("script.sh", perms)
// -> Ok(Nil)
```

## Platform Support

Run the complete test suite locally across targets with the helper script:

```sh
./bin/test          # Erlang + JavaScript
./bin/test erlang   # Erlang only
./bin/test javascript # Node.js only
```

| Target | Runtime | Status |
|---|---|---|
| Erlang | OTP | Full support |
| JavaScript | Node.js | Full support |
| JavaScript | Deno | Full support |
| JavaScript | Bun | Full support |

### Platform Notes and Limitations

Some behaviours vary by OS or filesystem. The library strives for consistency but there are edge cases you should be aware of:

- **Windows differences**: permission-setting functions are no-ops and octal permissions are ignored by the OS. Atomic rename may fail if the destination already exists (a Windows API restriction); a failure returns `AtomicFailed("rename", reason)` and the temp file is removed. Recursive traversal uses inode numbers when available; on Windows `ino` is typically zero, so the code falls back to a visited path string. Tests for Windows behaviour run conditionally.

- **Synchronous I/O**: The JS implementation uses synchronous filesystem calls (`fs.readFileSync`, `fs.writeFileSync`, etc.). This blocks the event loop. If you target Deno/Bun, the runtime may still work but the operations remain blocking.

- **Permissions**: POSIX-style `chmod`/`stat` behaviour is only meaningful on Unix-like platforms. On Windows, permissions queries/changes may be no-ops or behave differently.

- **Symlink creation**: Some platforms (notably Windows) require elevated privileges to create symlinks.

- **Atomic write caveats**: `write_atomic`/`write_bits_atomic` guarantee readers never see a partial file on POSIX filesystems, but do not protect against crashes between the temp write and the rename, or non-POSIX mounts (SMB, NFS) where rename may not be atomic.

- **Recursive read/write**: `handle.read_all_bits` and `handle.fold_chunks` use iterative loops to avoid stack overflow on extremely large files.

- **Path utilities**: `path.join_all([])` returns `"."`. `path.safe_relative` detects and blocks Windows drive letters as well as Unix absolute paths.

- **Error mapping**: the FFI bridge maps all known POSIX errors. Unknown platform errors become `Unknown(inner, context)`. Add new cases to `fio_ffi_bridge` when extending the error set.

### Cross-Platform Notes

- `NotUtf8` detection is consistent across Erlang and JavaScript.
- `delete_all` is idempotent: succeeds silently if the path does not exist.
- Symlink functions may require elevated privileges on Windows.
- Permissions functions (`set_permissions`, `set_permissions_octal`) have no effect on Windows.
