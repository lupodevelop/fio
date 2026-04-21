/// fio_dev — Development example for fio, runnable via `gleam dev`.
///
/// All output is written into `dev/output/`. After running, inspect that
/// directory to see exactly what each fio operation produced.
///
/// Destructive operations (delete, rename) work on dedicated files inside
/// `dev/output/destructive/` so the rest of the output stays intact.
import fio
import fio/error
import fio/path
import fio/types
import gleam/list
import gleam/set
import gleam/string
import woof

const out = "dev/output"

pub fn main() -> Nil {
  woof.set_format(woof.Text)
  woof.info("fio dev example started", [])

  // ── Prepare output directory ────────────────────────────────────────
  let _ = fio.delete_all(out)
  case fio.create_directory_all(out) {
    Ok(_) -> woof.info("Output directory ready", [woof.str("path", out)])
    Error(e) -> {
      woof.error("Cannot create output directory, aborting", [
        woof.str("error", error.describe(e)),
      ])
      panic as "Cannot create output directory"
    }
  }

  // ── 1. Write a text file ────────────────────────────────────────────
  let greeting = path.join(out, "greeting.txt")
  case fio.write(greeting, "Ciao dal mondo fio!\n") {
    Ok(_) -> woof.info("Text file written", [woof.str("file", greeting)])
    Error(e) ->
      woof.error("Write failed", [woof.str("error", error.describe(e))])
  }

  // ── 2. Read it back ─────────────────────────────────────────────────
  case fio.read(greeting) {
    Ok(content) ->
      woof.info("Text file read", [
        woof.str("file", greeting),
        woof.str("content", string.trim(content)),
        woof.int("length", string.length(content)),
      ])
    Error(e) ->
      woof.error("Read failed", [woof.str("error", error.describe(e))])
  }

  // ── 3. Append ───────────────────────────────────────────────────────
  case fio.append(greeting, "Questa riga è stata aggiunta con append.\n") {
    Ok(_) -> woof.info("Appended to file", [woof.str("file", greeting)])
    Error(e) ->
      woof.error("Append failed", [woof.str("error", error.describe(e))])
  }

  // ── 4. Binary I/O ──────────────────────────────────────────────────
  let bin_file = path.join(out, "data.bin")
  let bin_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
  // PNG magic bytes — just to show binary write
  case fio.write_bits(bin_file, bin_data) {
    Ok(_) ->
      woof.info("Binary file written", [
        woof.str("file", bin_file),
        woof.int("bytes", byte_size(bin_data)),
      ])
    Error(e) ->
      woof.error("Binary write failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  case fio.read_bits(bin_file) {
    Ok(bits) ->
      woof.info("Binary file read back", [
        woof.str("file", bin_file),
        woof.int("bytes", byte_size(bits)),
      ])
    Error(e) ->
      woof.error("Binary read failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 5. Nested directories ──────────────────────────────────────────
  let nested = path.join(out, "dirs/a/b/c")
  case fio.create_directory_all(nested) {
    Ok(_) ->
      woof.info("Nested directories created", [woof.str("path", nested)])
    Error(e) ->
      woof.error("create_directory_all failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  let deep_file = path.join(nested, "deep.txt")
  case fio.write(deep_file, "File nel percorso profondo.\n") {
    Ok(_) -> woof.info("Deep file written", [woof.str("file", deep_file)])
    Error(e) ->
      woof.error("Deep write failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 6. Existence & type checks ─────────────────────────────────────
  woof.info("Existence checks", [
    woof.bool("greeting_exists", fio.exists(greeting)),
    woof.bool("missing_exists", fio.exists(path.join(out, "nope.txt"))),
  ])

  case fio.is_file(greeting) {
    Ok(yes) ->
      woof.info("Type check", [
        woof.str("path", greeting),
        woof.bool("is_file", yes),
      ])
    Error(e) ->
      woof.warning("is_file failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  case fio.is_directory(path.join(out, "dirs")) {
    Ok(yes) ->
      woof.info("Type check", [
        woof.str("path", path.join(out, "dirs")),
        woof.bool("is_directory", yes),
      ])
    Error(e) ->
      woof.warning("is_directory failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 7. File info & permissions ─────────────────────────────────────
  case fio.file_info(greeting) {
    Ok(info) -> {
      let ft = types.file_info_type(info)
      let octal = types.file_info_permissions_octal(info)
      woof.info("File metadata", [
        woof.str("file", greeting),
        woof.int("size", info.size),
        woof.str("type", file_type_label(ft)),
        woof.int("permissions_octal", octal),
      ])
    }
    Error(e) ->
      woof.error("file_info failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // Write a script file with specific permissions
  let script = path.join(out, "script.sh")
  case fio.write(script, "#!/bin/sh\necho 'hello from fio'\n") {
    Ok(_) -> {
      let rwx_perms =
        types.FilePermissions(
          user: set.from_list([types.Read, types.Write, types.Execute]),
          group: set.from_list([types.Read, types.Execute]),
          other: set.from_list([types.Read]),
        )
      case fio.set_permissions(script, rwx_perms) {
        Ok(_) ->
          woof.info("Permissions set", [
            woof.str("file", script),
            woof.int("mode_octal", 0o754),
          ])
        Error(e) ->
          woof.warning("set_permissions failed", [
            woof.str("error", error.describe(e)),
          ])
      }
    }
    Error(e) ->
      woof.error("Script write failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 8. Copy ─────────────────────────────────────────────────────────
  let greeting_copy = path.join(out, "greeting_copy.txt")
  case fio.copy(greeting, greeting_copy) {
    Ok(_) ->
      woof.info("File copied", [
        woof.str("src", greeting),
        woof.str("dest", greeting_copy),
      ])
    Error(e) ->
      woof.error("Copy failed", [woof.str("error", error.describe(e))])
  }

  // ── 9. Symlink ──────────────────────────────────────────────────────
  let link = path.join(out, "greeting_link.txt")
  case fio.create_symlink(target: "greeting.txt", link: link) {
    Ok(_) -> {
      woof.info("Symlink created", [
        woof.str("target", "greeting.txt"),
        woof.str("link", link),
      ])
      case fio.is_symlink(link) {
        Ok(yes) ->
          woof.info("Symlink verified", [woof.bool("is_symlink", yes)])
        Error(e) ->
          woof.warning("is_symlink failed", [
            woof.str("error", error.describe(e)),
          ])
      }
      case fio.read(link) {
        Ok(content) ->
          woof.info("Read through symlink", [
            woof.str("content", string.trim(content)),
          ])
        Error(e) ->
          woof.warning("Read via symlink failed", [
            woof.str("error", error.describe(e)),
          ])
      }
    }
    Error(e) ->
      woof.warning("Symlink not supported on this platform", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 10. List directory ──────────────────────────────────────────────
  case fio.list(out) {
    Ok(entries) ->
      woof.info("Directory listing", [
        woof.str("path", out),
        woof.int("count", list.length(entries)),
        woof.str("entries", string.join(entries, ", ")),
      ])
    Error(e) ->
      woof.error("List failed", [woof.str("error", error.describe(e))])
  }

  // ── 11. Destructive operations (isolated sandbox) ──────────────────
  //    These use a dedicated sub-directory so the rest of output/ stays intact.
  let sandbox = path.join(out, "destructive")
  case fio.create_directory_all(sandbox) {
    Ok(_) ->
      woof.info("Destructive sandbox created", [woof.str("path", sandbox)])
    Error(e) ->
      woof.error("Sandbox creation failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // 11a. Rename demo
  let rename_src = path.join(sandbox, "before_rename.txt")
  let rename_dst = path.join(sandbox, "after_rename.txt")
  case fio.write(rename_src, "Questo file verrà rinominato.\n") {
    Ok(_) -> Nil
    Error(e) ->
      woof.error("Write for rename demo failed", [
        woof.str("error", error.describe(e)),
      ])
  }
  case fio.rename(rename_src, rename_dst) {
    Ok(_) ->
      woof.info("Rename demo", [
        woof.str("from", rename_src),
        woof.str("to", rename_dst),
        woof.bool("old_exists", fio.exists(rename_src)),
        woof.bool("new_exists", fio.exists(rename_dst)),
      ])
    Error(e) ->
      woof.error("Rename failed", [woof.str("error", error.describe(e))])
  }

  // 11b. Delete file demo
  let delete_target = path.join(sandbox, "to_be_deleted.txt")
  case fio.write(delete_target, "Questo file verrà eliminato.\n") {
    Ok(_) -> Nil
    Error(e) ->
      woof.error("Write for delete demo failed", [
        woof.str("error", error.describe(e)),
      ])
  }
  woof.info("Delete demo — before", [
    woof.bool("exists", fio.exists(delete_target)),
  ])
  case fio.delete(delete_target) {
    Ok(_) ->
      woof.info("Delete demo — after", [
        woof.str("file", delete_target),
        woof.bool("exists", fio.exists(delete_target)),
      ])
    Error(e) ->
      woof.error("Delete failed", [woof.str("error", error.describe(e))])
  }

  // 11c. Recursive delete demo
  let del_tree = path.join(sandbox, "tree_to_delete")
  case fio.create_directory_all(path.join(del_tree, "nested")) {
    Ok(_) -> {
      let _ = fio.write(path.join(del_tree, "a.txt"), "a\n")
      let _ = fio.write(path.join(del_tree, "nested/b.txt"), "b\n")
      Nil
    }
    Error(e) ->
      woof.error("Tree setup failed", [
        woof.str("error", error.describe(e)),
      ])
  }
  woof.info("Recursive delete demo — before", [
    woof.bool("tree_exists", fio.exists(del_tree)),
  ])
  case fio.delete_all(del_tree) {
    Ok(_) ->
      woof.info("Recursive delete demo — after", [
        woof.str("path", del_tree),
        woof.bool("tree_exists", fio.exists(del_tree)),
      ])
    Error(e) ->
      woof.error("Recursive delete failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 12. Path operations (pure, no I/O) ──────────────────────────────
  woof.info("Path operations", [
    woof.str("join", path.join("src", "main.gleam")),
    woof.str("base_name", path.base_name("/usr/local/bin/gleam")),
    woof.str("directory_name", path.directory_name("/usr/local/bin/gleam")),
    woof.str("extension", string.inspect(path.extension("main.gleam"))),
    woof.str("stem", path.stem("archive.tar.gz")),
    woof.str("with_extension", path.with_extension("main.gleam", "js")),
    woof.bool("is_absolute_usr", path.is_absolute("/usr")),
    woof.str(
      "join_all",
      path.join_all(["src", "fio", "internal", "io.gleam"]),
    ),
  ])

  // ── 13. Touch ────────────────────────────────────────────────────────
  let stamp = path.join(out, "touch_stamp.txt")
  case fio.touch(stamp) {
    Ok(_) ->
      woof.info("Touch created new file", [
        woof.str("file", stamp),
        woof.bool("exists", fio.exists(stamp)),
      ])
    Error(e) ->
      woof.error("Touch failed", [woof.str("error", error.describe(e))])
  }
  // Touch existing file to update mtime
  case fio.touch(greeting) {
    Ok(_) -> woof.info("Touch updated mtime", [woof.str("file", greeting)])
    Error(e) ->
      woof.error("Touch update failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 14. Read link ───────────────────────────────────────────────────
  case fio.read_link(link) {
    Ok(target) ->
      woof.info("Read link target", [
        woof.str("link", link),
        woof.str("target", target),
      ])
    Error(e) ->
      woof.warning("read_link failed (symlinks may not be available)", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 15. Safe relative path ──────────────────────────────────────────
  woof.info("Path safety checks", [
    woof.str("safe_data", string.inspect(path.safe_relative("data/file.txt"))),
    woof.str(
      "unsafe_escape",
      string.inspect(path.safe_relative("../../../etc/passwd")),
    ),
    woof.str(
      "unsafe_absolute",
      string.inspect(path.safe_relative("/usr/bin")),
    ),
  ])

  // ── 16. Utility ─────────────────────────────────────────────────────
  case fio.current_directory() {
    Ok(cwd) -> woof.info("Working directory", [woof.str("cwd", cwd)])
    Error(e) ->
      woof.error("cwd failed", [woof.str("error", error.describe(e))])
  }
  woof.info("Temp directory", [woof.str("tmp_dir", fio.tmp_dir())])

  // ── 17. Error handling ──────────────────────────────────────────────
  case fio.read("this_file_does_not_exist.txt") {
    Ok(_) -> woof.warning("Expected an error but got success", [])
    Error(e) ->
      woof.info("Graceful error handling", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── 18. Recursive Directory Operations (New) ────────────────────────
  let recursive_dir = path.join(out, "recursive_test")
  let _ = fio.create_directory(recursive_dir)
  let _ = fio.create_directory(path.join(recursive_dir, "subdir"))
  let assert Ok(Nil) = fio.write(path.join(recursive_dir, "root.txt"), "root")
  let assert Ok(Nil) =
    fio.write(path.join(recursive_dir, "subdir/nested.txt"), "nested")

  // Copy directory
  case fio.copy_directory(recursive_dir, path.join(out, "recursive_copy")) {
    Ok(Nil) ->
      woof.info("Directory recursively copied", [
        woof.str("src", recursive_dir),
        woof.str("dest", "dev/output/recursive_copy"),
      ])
    Error(e) ->
      woof.error("Recursive copy failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // List recursive
  case fio.list_recursive(recursive_dir) {
    Ok(paths) ->
      woof.info("Recursive list", [woof.int("count", list.length(paths))])
    Error(e) ->
      woof.error("Recursive list failed", [
        woof.str("error", error.describe(e)),
      ])
  }

  // Enotempty check (manual)
  case fio.delete_directory(path.join(recursive_dir, "subdir")) {
    Error(error.Enotempty) -> woof.info("Detected Enotempty correctly", [])
    Error(error.Eexist) ->
      woof.info("Detected Eexist (mapped from ENOTEMPTY on some systems)", [])
    Ok(_) -> woof.warning("Failed to detect non-empty directory!", [])
    Error(e) ->
      woof.error("Unexpected error for delete_directory", [
        woof.str("error", error.describe(e)),
      ])
  }

  // ── Done ────────────────────────────────────────────────────────────
  woof.info("fio dev example finished — inspect dev/output/ for results", [])
}

// ── Helpers ─────────────────────────────────────────────────────────────

fn file_type_label(ft: types.FileType) -> String {
  case ft {
    types.File -> "file"
    types.Directory -> "directory"
    types.Symlink -> "symlink"
    types.Other -> "other"
  }
}

@external(erlang, "erlang", "byte_size")
@external(javascript, "../fio_ffi_dev.mjs", "byte_size")
fn byte_size(bits: BitArray) -> Int
