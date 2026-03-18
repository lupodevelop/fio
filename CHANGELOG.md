# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
