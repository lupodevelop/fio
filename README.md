
<p align="center">
  <img src="assets/img/fio.png" width="256" height="256" alt="fio logo">
</p>

# fio

[![Package Version](https://img.shields.io/hexpm/v/fio)](https://hex.pm/packages/fio)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/fio/)


**"Complete", safe, ergonomic file operations for all Gleam targets.**

A single import for everything you need: read, write, copy, delete, symlinks,
permissions, paths, atomic writes, file handles, and more. It comes with rich
error types and cross-platform consistency.

All functionality is available via **`import fio`** (no need for submodule imports).

## Features

- **Unified API** — One `import fio` for all file operations. No juggling multiple packages.
- **Cross-platform** — Works identically on Erlang, Node.js, Deno, and Bun.
- **Rich errors** — POSIX-style error codes + semantic types like `NotUtf8(path)`. Pattern match precisely.
- **Atomic writes** — `write_atomic` / `write_bits_atomic` guarantee readers never see partial content. Temporary files are cleaned up even if the rename fails.
- **Random-access file handles** — `seek` and `tell` let you jump to arbitrary byte offsets.
- **File handles** — `fio/handle` exposes `open`, `close`, `read_chunk`, `write` for large-file and
  streaming scenarios; `with` helper prevents leaks.
- **Type-safe permissions** — `FilePermissions` with `Set(Permission)`, not magic integers.
- **Path operations** — `join`, `split`, `expand`, `safe_relative`, and more — built in.
- **Symlinks & hard links** — Create, detect, read link targets.
- **Symlink loop safety** — Recursive operations track `(dev, inode)` pairs; circular symlinks
  are listed but never descended into. On Windows, where `inode` may be zero, the
  full path string is used as a fallback key.
- **FFI safety** — Erlang bindings map hash‑algorithm strings with a closed set,
  preventing atom table exhaustion.
- **Touch** — Create files or update timestamps, like Unix `touch`.
- **Idempotent deletes** — `delete_all` succeeds silently on non-existent paths.

## Installation

```sh
gleam add fio
```

## Quick Start

```gleam
import fio
import fio/error

pub fn main() {
  // Write and read
  let assert Ok(_) = fio.write("hello.txt", "Ciao, mondo!")
  let assert Ok(content) = fio.read("hello.txt")
  // content == "Ciao, mondo!"

  // Graceful error handling
  case fio.read("missing.txt") {
    Ok(text) -> use_text(text)
    Error(error.Enoent) -> use_defaults()
    Error(e) -> panic as { "Error: " <> error.describe(e) }
  }

  // Path safety (via the same `fio` facade)
  let safe = fio.safe_relative("../../../etc/passwd")
  // safe == Error(Nil) — blocked!
}
```

## API Overview

### Reading & Writing

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

> **Note:** `delete_all` does **not** follow directory symlinks. A symlink itself is deleted but its target is left untouched.
| `fio.list_recursive(path)` | List all files in a directory recursively |

### Querying

| Function | Description |
|---|---|
| `fio.exists(path)` | Check if path exists (files, directories, symlinks) |
| `fio.is_file(path)` | Check if path is a regular file |
| `fio.is_directory(path)` | Check if path is a directory |
| `fio.is_symlink(path)` | Check if path is a symbolic link |
| `fio.file_info(path)` | Get file metadata (follows symlinks) |
| `fio.link_info(path)` | Get metadata without following symlinks |

### Symlinks & Links

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

## Cross-platform behavior notes

Some behavior differs between BEAM (Erlang/OTP) and JavaScript runtimes (Node/Deno/Bun). The library aims to keep the API consistent, but underlying platform differences can affect:

- **Synchronous I/O**: The JS implementation uses synchronous filesystem calls (`fs.readFileSync`, `fs.writeFileSync`, etc.). This is appropriate for many Gleam apps, but it blocks the event loop. If you target Deno/Bun, the runtime may still work (they provide Node compatibility layers) but the operations remain blocking.
- **Permissions**: POSIX-style `chmod`/`stat` behavior is only meaningful on Unix-like platforms. On Windows, permissions queries/changes may be no-ops or behave differently, and `set_permissions` may return `Eperm`/`Enotsup`.
- **Symlink creation**: Some platforms (notably Windows) require elevated privileges to create symlinks; when symlink creation fails, the library surfaces the OS error.
- **Path normalization**: The `fio/path` module delegates to `filepath` (BEAM) or Node’s `path` (JS). Windows paths may use backslashes (`\\`) and drive letters; `safe_relative` normalizes backslashes to forward slashes to ensure consistent behavior.

  For example, on Node.js (macOS host) the output of `path.join("C:\\foo", "bar")` is `C:\foo/bar`, while `path.win32.join` yields `C:\foo\\bar`. On BEAM, `fio/path.join` currently yields `C:\foo/bar` (mixing separators) and `path.split("C:\\foo\\bar")` returns a single segment `"C:\\foo\\bar"`.

  You can inspect runtime behavior across targets using:

  ```sh
  node dev/path_behavior.js
  # (or deno run dev/path_behavior.js, bun dev/path_behavior.js if available)
  ```

- **File handles**: On Node.js, append mode is enforced by the OS only when write calls use a `null` position; `fio/handle` tracks position and forces `null` when in append mode to preserve POSIX semantics.

> Tip: If you rely on strict POSIX behavior (permissions, symlink semantics, dev/inode metadata), prefer running on Erlang/OTP where those semantics are stable.

### File Handles (`fio/handle`)

For large files or streaming scenarios where loading the entire content into
memory is not acceptable, use the `fio/handle` module:

```gleam
import fio/handle
import gleam/result

// Read a large log file chunk by chunk (64 KiB at a time)
pub fn count_bytes(path: String) -> Result(Int, error.FioError) {
  use h <- result.try(handle.open(path, handle.ReadOnly))
  let assert Ok(bits) = handle.read_all_bits(h)
  let _ = handle.close(h)
  Ok(bit_array.byte_size(bits))
}

// Write to a file with explicit lifecycle control
pub fn write_lines(path: String, lines: List(String)) -> Result(Nil, error.FioError) {
  use h <- result.try(handle.open(path, handle.WriteOnly))
  let result = list.try_each(lines, fn(line) { handle.write(h, line <> "\n") })
  let _ = handle.close(h)
  result
}
```

| Function | Description |
|---|---|
| `handle.open(path, mode)` | Open a file (`ReadOnly`, `WriteOnly`, `AppendOnly`) |
| `handle.close(handle)` | Close the handle, release the OS file descriptor |
| `handle.read_chunk(handle, size)` | Read up to `size` bytes; `Ok(None)` at EOF |
| `handle.read_all_bits(handle)` | Read all remaining bytes as `BitArray` |
| `handle.read_all(handle)` | Read all remaining content as UTF-8 `String` |
| `handle.write(handle, content)` | Write a UTF-8 string |
| `handle.write_bits(handle, bytes)` | Write raw bytes |

> **Note**: `FileHandle` is intentionally opaque. Always call `close` when done —
> the OS file descriptor is not automatically released.

### Path Operations (`fio/path`)

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
| `path.safe_relative(path)` | Validate path doesn't escape via `..` |

## Atomic Writes

`write_atomic` and `write_bits_atomic` implement the write-to-temp-then-rename
pattern, which is the standard POSIX-safe way to update files:

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

Use plain `write` for scratch files, logs, or temporary output where
partial writes are acceptable.

## Error Handling

fio uses `FioError`: 39 POSIX-style error constructors plus 7 semantic variants; each error has a human-readable description available via `error.describe`:

```gleam
import fio
import fio/error.{type FioError, Enoent, Eacces, NotUtf8}

case fio.read("data.bin") {
  Ok(text) -> use(text)
  Error(Enoent) -> io.println("Not found")
  Error(Eacces) -> io.println("Permission denied")
  Error(NotUtf8(path)) -> {
    // File exists but isn't valid UTF-8 — use read_bits instead
    let assert Ok(bytes) = fio.read_bits(path)
    use_bytes(bytes)
  }
  Error(e) -> io.println(error.describe(e))
}
```

Every error has a human-readable description via `error.describe`.

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

### Development

Run the complete test suite locally across targets with the helper script:

```sh
./bin/test          # Erlang + JavaScript
./bin/test erlang   # Erlang only
./bin/test javascript # Node.js only
```

This mirrors the CI matrix without needing to publish the package.

## Platform Support

| Target | Runtime | Status |
|---|---|---|
| Erlang | OTP | Full support |
| JavaScript | Node.js | Full support |
| JavaScript | Deno | Full support |
| JavaScript | Bun | Full support |
### Platform Notes & Limitations

Some behaviours vary by OS or filesystem. The library strives for consistency
but there are edge cases you should be aware of:

* **Windows differences** – permission‑setting functions are no‑ops and
  `%o` octal permissions are ignored by the OS. Atomic rename may fail if the
  destination already exists (a Windows API restriction); a failure returns
  `AtomicFailed("rename", reason)` and the temp file is removed.  Recursive
  traversal uses inode numbers when available; on Windows `ino` is typically
  zero, so the code falls back to a visited path string.  Tests for Windows
  behaviour run conditionally and the README makes these caveats explicit.

* **Atomic write caveats** – `write_atomic`/`write_bits_atomic` implement
  write‑to‑temp‑then‑rename.  This guarantees readers never see a partial file
  on POSIX filesystems, but does *not* protect you from:
  - crashes that occur **between** the temp write and the rename (a `.tmp`
    sibling may be left behind),
  - non‑POSIX mounts (SMB, NFS with strange semantics) where rename may not be
    atomic.  Always clean up temp files periodically if you run on untrusted
    filesystems.

* **Recursive read/write** – `handle.read_all_bits` now uses an iterative loop
  to avoid stack overflow on extremely large files.  The previous recursive
  implementation worked but could blow the call stack for multi‑gigabyte reads.

* **Path utilities** – `path.join_all([])` returns `"."` (previously `""`)
  which better matches user expectations.  `path.safe_relative` detects and
  blocks Windows drive letters as well as Unix absolute paths; it still simply
  normalises `..` segments, so be cautious when operating on network shares.

* **Error mapping** – the FFI bridge maps all known POSIX errors; if a new
  platform error is received it becomes `Unknown(inner, _)`. Add new cases to
  `fio_ffi_bridge` when extending the error set.

* **No async/watch support** – all APIs are synchronous.  Reading very large
  files will block the BEAM scheduler or the JavaScript event loop; use
  `fio/handle` with small chunks or move heavy I/O off the main thread.

These notes are intentionally broad; see the module docs for more details on
individual functions.
### Cross-Platform Notes

- **`NotUtf8` detection** is consistent across Erlang and JavaScript.
- **`delete_all`** is idempotent: succeeds silently if the path doesn't exist.
- **Symlink** functions may require elevated privileges on Windows.
- **Permissions** functions (`set_permissions`, `set_permissions_octal`) have no effect on Windows.


## License

MIT

---

Made with Gleam 💜
