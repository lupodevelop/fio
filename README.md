
<p align="center">
  <img src="https://raw.githubusercontent.com/lupodevelop/fio/main/assets/img/fio.png" width="256" height="256" alt="fio logo">
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

- **Unified API**: One `import fio` for all file operations. No juggling multiple packages.
- **Cross-platform**: Works identically on Erlang, Node.js, Deno, and Bun.
- **Rich errors**: POSIX-style error codes plus semantic types like `NotUtf8(path)`. Pattern match precisely.
- **Atomic writes**: `write_atomic` / `write_bits_atomic` guarantee readers never see partial content. Temporary files are cleaned up even if the rename fails.
- **Atomic helper**: `fio.atomic(path, fn(tmp_path) { ... })` makes temporary-file writes explicit and ergonomic. The temp file lands in the same directory as the target and uses the `.__fio_tmp_*` prefix, consistent with `write_atomic`.
- **Streaming**: `read_fold`, `stream`, `stream_bytes`, and `handle.fold_chunks` let you process files chunk by chunk without loading them fully into memory.
- **Context helpers**: `with_opened` and `with_writer` provide resource-safe file-handle callbacks.
- **High-level helpers**: `ensure_file`, `copy_if_newer`, `write_new`, `write_if_changed`, `read_lines` (normalises `\r\n` and `\n`), `write_lines`, and `fio/json` for common workflows.
- **Error UX**: `fio.explain(error)` returns a CLI-friendly description string.
- **Type-safe permissions**: `FilePermissions` with `Set(Permission)`, not magic integers.
- **Path operations**: `join`, `split`, `expand`, `safe_relative`, and more, built in.
- **Symlinks and hard links**: Create, detect, read link targets.
- **Symlink loop safety**: Recursive operations track `(dev, inode)` pairs. Circular symlinks are listed but never descended into. On Windows, where `inode` may be zero, the full path string is used as a fallback key.
- **FFI safety**: Erlang bindings map hash algorithm strings with a closed set, preventing atom table exhaustion.
- **Touch**: Create files or update timestamps, like Unix `touch`.
- **Idempotent deletes**: `delete_all` succeeds silently on non-existent paths.
- **Observability**: `fio/observer` provides structured event sinks and transparent wrappers to instrument any fio call without restructuring your code.

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
  // safe == Error(Nil) -- blocked!
}
```

## Documentation

A full reference for `fio` is available in the documentation:

- [Usage and API reference](docs/usage.md)
