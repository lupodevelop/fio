# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-04-11

### Added

- `fio.with_opened(path, mode, callback)`: resource-safe handle management via callback, closes the handle automatically.
- `fio.with_writer(path, callback)`: shorthand for writing with a temporary handle and automatic cleanup.
- `fio.write_new(path, content)`: write only when the file does not exist; returns `Error(error.Eexist)` if the file already exists.
- `fio.write_if_changed(path, content)`: write only when the content differs from the existing file; returns `Ok(True)` when written, `Ok(False)` when skipped.
- `fio.read_lines(path)`: read a file and split it into lines.
- `fio.write_lines(path, lines)`: join lines with `"\n"` and write them to a file.
- `fio.stream_bytes(path)`: read file content in raw-byte chunks as `List(BitArray)`.
- `fio.stream(path)`: read file content in UTF-8 string chunks as `List(String)`.
- `fio.explain(error)`: format a `FioError` as a CLI-friendly string.
- `fio.atomic(path, callback)`: write to a temporary path and rename into place on success, with cleanup on failure.

### Changed

- `fio/stream` helpers are implemented on top of existing `read_fold` and `handle.fold_chunks`, preserving compatibility with current `gleam_stdlib` constraints.

## [1.1.0] - 2026-04-10

### Added

- **`fio.ensure_file(path)`**: creates a file if it does not exist; no-op if it
  already does. Useful for initialising config or lock files idempotently.

- **`fio.copy_if_newer(src, dest)`**: copies `src` to `dest` only when `src`
  has a newer `mtime` than `dest` (or when `dest` is absent). Returns
  `Ok(True)` when a copy was performed, `Ok(False)` when it was skipped.

- **`fio.read_fold(path, chunk_size, initial, f)`**: reads a file in chunks
  and folds each chunk into an accumulator. Lets you process arbitrarily large
  files without loading them fully into memory.

- **`handle.fold_chunks(handle, chunk_size, initial, f)`**: same fold primitive
  as `read_fold` but operates on an already-open `FileHandle`. Used internally
  by `read_fold` and available for callers that manage their own handle
  lifecycle.

- **`fio/json` module**: thin I/O wrappers that compose with any
  encoder/decoder function.
  - `read_json(path, decoder)`: reads the file and passes the content to
    `decoder`. Returns `Error(IoError(_))` on I/O failure and
    `Error(ParseError(_))` when the decoder rejects the content.
  - `write_json_atomic(path, value, encoder)`: encodes `value` and writes
    atomically via `fio.write_atomic`.
  - `JsonError(e)` type with `IoError(FioError)` and `ParseError(e)` variants.

- **`fio/observer` module**: structured, extensible observability primitives.
  - `Event` type: carries `op`, `path`, `outcome: Result(Nil, FioError)`, and
    optional `bytes: Option(Int)`. Designed to be consumed by external packages
    without knowing fio internals.
  - `Sink` type alias (`fn(Event) -> Nil`): any package can implement a sink
    (structured logger, metrics counter, test recorder, OpenTelemetry span, …).
  - `emit(result, op, path, bytes, sink)`: core primitive — emits an `Event`
    then returns `result` unchanged.
  - `trace(result, op, path, sink)`: convenience wrapper without byte count.
  - `trace_bytes(result, op, path, sink)`: automatically infers `bytes` from
    a `BitArray` result (e.g. after `fio.read_bits`).
  - `format(event)`: formats an `Event` as a human-readable string for simple
    logging sinks.
  - `fan_out(sink1, sink2)`: combines two sinks into one; both receive every
    event. Enables log-to-stdout AND record-in-test simultaneously.
  - `noop_sink`: discards all events; useful as a default/no-op argument when
    observability is optional.

### Fixed

- **`error.describe` for `Unknown`**: the `context` field is now included in
  the description string when present. Previously it was silently discarded.

- **`recursive.gleam`**: extracted the four copies of the inode-key building
  expression into a single private `inode_key(info, fallback)` helper, removing
  the risk of the four copies diverging in future.

## [1.0.0] - 2026-03-18

### Added

- **Recursive operations**: `list_recursive`, `copy_directory`
- **Core file I/O**: `read`, `read_bits`, `write`, `write_bits`, `append`, `append_bits`
- **Atomic writes**: `write_atomic`, `write_bits_atomic` — write to a sibling temp file
  then atomically rename into place via a single `rename(2)` syscall. Readers never
  observe partial content. Returns `AtomicFailed` on error.
- **File handle API** (`fio/handle`): resource-safe `FileHandle` type with `open`,
  `close`, `read_chunk`, `read_all`, `read_all_bits`, `write`, `write_bits`.
  Foundation for streaming I/O over arbitrarily large files.
- **Random access on handles**: `seek` and `tell` let callers reposition the file
  cursor; works on both Erlang and JavaScript (JS handle tracks `{fd,pos,isAppend}`).
- **Append-mode correctness**: JS handles now preserve `'a'` behaviour when seeking;
  fixed regression where `handle.append` wrote at tracked position instead of EOF.
- **Utility script**: `bin/test` runs the Gleam suite locally on Erlang and JS targets.
- **File operations**: `copy`, `rename`, `delete`, `delete_directory`, `delete_all`
- **Querying**: `exists`, `is_file`, `is_directory`, `is_symlink`, `file_info`, `link_info`
- **Symlinks & links**: `create_symlink`, `create_hard_link`, `read_link`
- **Permissions**: `set_permissions` (type-safe with `FilePermissions`), `set_permissions_octal`
- **Directories**: `create_directory`, `create_directory_all`, `list`
- **Utility**: `current_directory`, `tmp_dir`, `touch`
- **Path operations** (`fio/path`): `join`, `join_all`, `split`, `base_name`, `directory_name`,
  `extension`, `stem`, `with_extension`, `strip_extension`, `is_absolute`, `expand`, `safe_relative`
- **Rich error types**: 43 POSIX codes + 7 semantic types (`NotUtf8`, `PathTraversal`,
  `OutsideBase`, `InvalidPath`, `AtomicFailed`, `TempFailed`, `Unknown`)
- Human-readable error descriptions via `error.describe`
- Type-safe file permissions with `FilePermissions` and `Set(Permission)`
- Full cross-platform support: Erlang/OTP, Node.js, Deno, Bun
- Consistent `NotUtf8` detection across all targets (uses `TextDecoder` with
  `fatal: true` on JavaScript)
- Idempotent `delete_all` — succeeds on non-existent paths
- 54 tests covering all operations on both Erlang and JavaScript targets

### Changed

- **`list_recursive` / `copy_directory`**: rewritten with a flat string accumulator
  instead of `List(String)` segments. Complexity drops from O(n²) (repeated
  `list.append` + `list.flatten` on depth-proportional lists) to **O(n)** in the
  number of filesystem entries. No API change.

### Fixed

- **Symlink loop protection** in `list_recursive` and `copy_directory`: each
  directory's real `(dev, inode)` pair (resolved via `stat`, which follows
  symlinks) is tracked in a `Set`. Circular chains (`A → B → A`) and deeper
  cycles are broken silently — the entry is listed but not descended into.
  Prevents infinite recursion and stack overflows on adversarial or
  misconfigured filesystems.

- **Atomic write cleanup**: when a `write_atomic` rename fails, the Erlang FFI
  now explicitly performs a best‑effort `file:delete/1` on the temporary file
  before returning the error. Node.js already had this behaviour; the change
  prevents orphaned `.__fio_tmp_*` files on failure.

- **Hash algorithm safety**: the Erlang FFI stopped converting arbitrary
  binaries to atoms. A fixed mapping from accepted algorithm strings
  (`"sha256"`, `"sha512"`, `"md5"`) to existing atoms is now used, closing
  the risk of exhausting the BEAM atom table.

- **Cross‑platform inode fallback**: the recursive traversal code already
  fell back to using the full path string when `stat` returned `inode == 0`
  (common on Windows). This is documented more clearly, and the behaviour is
  now noted in README.
