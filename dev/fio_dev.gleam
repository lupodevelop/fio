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
    Ok(_) -> woof.info("Output directory ready", [woof.field("path", out)])
    Error(e) -> {
      woof.error("Cannot create output directory, aborting", [
        woof.field("error", error.describe(e)),
      ])
      panic as "Cannot create output directory"
    }
  }

  // ── 1. Write a text file ────────────────────────────────────────────
  let greeting = path.join(out, "greeting.txt")
  case fio.write(greeting, "Ciao dal mondo fio!\n") {
    Ok(_) -> woof.info("Text file written", [woof.field("file", greeting)])
    Error(e) ->
      woof.error("Write failed", [woof.field("error", error.describe(e))])
  }

  // ── 2. Read it back ─────────────────────────────────────────────────
  case fio.read(greeting) {
    Ok(content) ->
      woof.info("Text file read", [
        woof.field("file", greeting),
        woof.field("content", string.trim(content)),
        woof.int_field("length", string.length(content)),
      ])
    Error(e) ->
      woof.error("Read failed", [woof.field("error", error.describe(e))])
  }

  // ── 3. Append ───────────────────────────────────────────────────────
  case fio.append(greeting, "Questa riga è stata aggiunta con append.\n") {
    Ok(_) -> woof.info("Appended to file", [woof.field("file", greeting)])
    Error(e) ->
      woof.error("Append failed", [woof.field("error", error.describe(e))])
  }

  // ── 4. Binary I/O ──────────────────────────────────────────────────
  let bin_file = path.join(out, "data.bin")
  let bin_data = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
  // PNG magic bytes — just to show binary write
  case fio.write_bits(bin_file, bin_data) {
    Ok(_) ->
      woof.info("Binary file written", [
        woof.field("file", bin_file),
        woof.int_field("bytes", byte_size(bin_data)),
      ])
    Error(e) ->
      woof.error("Binary write failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  case fio.read_bits(bin_file) {
    Ok(bits) ->
      woof.info("Binary file read back", [
        woof.field("file", bin_file),
        woof.int_field("bytes", byte_size(bits)),
      ])
    Error(e) ->
      woof.error("Binary read failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 5. Nested directories ──────────────────────────────────────────
  let nested = path.join(out, "dirs/a/b/c")
  case fio.create_directory_all(nested) {
    Ok(_) ->
      woof.info("Nested directories created", [woof.field("path", nested)])
    Error(e) ->
      woof.error("create_directory_all failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  let deep_file = path.join(nested, "deep.txt")
  case fio.write(deep_file, "File nel percorso profondo.\n") {
    Ok(_) -> woof.info("Deep file written", [woof.field("file", deep_file)])
    Error(e) ->
      woof.error("Deep write failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 6. Existence & type checks ─────────────────────────────────────
  woof.info("Existence checks", [
    woof.bool_field("greeting_exists", fio.exists(greeting)),
    woof.bool_field("missing_exists", fio.exists(path.join(out, "nope.txt"))),
  ])

  case fio.is_file(greeting) {
    Ok(yes) ->
      woof.info("Type check", [
        woof.field("path", greeting),
        woof.bool_field("is_file", yes),
      ])
    Error(e) ->
      woof.warning("is_file failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  case fio.is_directory(path.join(out, "dirs")) {
    Ok(yes) ->
      woof.info("Type check", [
        woof.field("path", path.join(out, "dirs")),
        woof.bool_field("is_directory", yes),
      ])
    Error(e) ->
      woof.warning("is_directory failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 7. File info & permissions ─────────────────────────────────────
  case fio.file_info(greeting) {
    Ok(info) -> {
      let ft = types.file_info_type(info)
      let octal = types.file_info_permissions_octal(info)
      woof.info("File metadata", [
        woof.field("file", greeting),
        woof.int_field("size", info.size),
        woof.field("type", file_type_label(ft)),
        woof.int_field("permissions_octal", octal),
      ])
    }
    Error(e) ->
      woof.error("file_info failed", [
        woof.field("error", error.describe(e)),
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
            woof.field("file", script),
            woof.int_field("mode_octal", 0o754),
          ])
        Error(e) ->
          woof.warning("set_permissions failed", [
            woof.field("error", error.describe(e)),
          ])
      }
    }
    Error(e) ->
      woof.error("Script write failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 8. Copy ─────────────────────────────────────────────────────────
  let greeting_copy = path.join(out, "greeting_copy.txt")
  case fio.copy(greeting, greeting_copy) {
    Ok(_) ->
      woof.info("File copied", [
        woof.field("src", greeting),
        woof.field("dest", greeting_copy),
      ])
    Error(e) ->
      woof.error("Copy failed", [woof.field("error", error.describe(e))])
  }

  // ── 9. Symlink ──────────────────────────────────────────────────────
  let link = path.join(out, "greeting_link.txt")
  case fio.create_symlink(target: "greeting.txt", link: link) {
    Ok(_) -> {
      woof.info("Symlink created", [
        woof.field("target", "greeting.txt"),
        woof.field("link", link),
      ])
      case fio.is_symlink(link) {
        Ok(yes) ->
          woof.info("Symlink verified", [woof.bool_field("is_symlink", yes)])
        Error(e) ->
          woof.warning("is_symlink failed", [
            woof.field("error", error.describe(e)),
          ])
      }
      case fio.read(link) {
        Ok(content) ->
          woof.info("Read through symlink", [
            woof.field("content", string.trim(content)),
          ])
        Error(e) ->
          woof.warning("Read via symlink failed", [
            woof.field("error", error.describe(e)),
          ])
      }
    }
    Error(e) ->
      woof.warning("Symlink not supported on this platform", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 10. List directory ──────────────────────────────────────────────
  case fio.list(out) {
    Ok(entries) ->
      woof.info("Directory listing", [
        woof.field("path", out),
        woof.int_field("count", list.length(entries)),
        woof.field("entries", string.join(entries, ", ")),
      ])
    Error(e) ->
      woof.error("List failed", [woof.field("error", error.describe(e))])
  }

  // ── 11. Destructive operations (isolated sandbox) ──────────────────
  //    These use a dedicated sub-directory so the rest of output/ stays intact.
  let sandbox = path.join(out, "destructive")
  case fio.create_directory_all(sandbox) {
    Ok(_) ->
      woof.info("Destructive sandbox created", [woof.field("path", sandbox)])
    Error(e) ->
      woof.error("Sandbox creation failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // 11a. Rename demo
  let rename_src = path.join(sandbox, "before_rename.txt")
  let rename_dst = path.join(sandbox, "after_rename.txt")
  case fio.write(rename_src, "Questo file verrà rinominato.\n") {
    Ok(_) -> Nil
    Error(e) ->
      woof.error("Write for rename demo failed", [
        woof.field("error", error.describe(e)),
      ])
  }
  case fio.rename(rename_src, rename_dst) {
    Ok(_) ->
      woof.info("Rename demo", [
        woof.field("from", rename_src),
        woof.field("to", rename_dst),
        woof.bool_field("old_exists", fio.exists(rename_src)),
        woof.bool_field("new_exists", fio.exists(rename_dst)),
      ])
    Error(e) ->
      woof.error("Rename failed", [woof.field("error", error.describe(e))])
  }

  // 11b. Delete file demo
  let delete_target = path.join(sandbox, "to_be_deleted.txt")
  case fio.write(delete_target, "Questo file verrà eliminato.\n") {
    Ok(_) -> Nil
    Error(e) ->
      woof.error("Write for delete demo failed", [
        woof.field("error", error.describe(e)),
      ])
  }
  woof.info("Delete demo — before", [
    woof.bool_field("exists", fio.exists(delete_target)),
  ])
  case fio.delete(delete_target) {
    Ok(_) ->
      woof.info("Delete demo — after", [
        woof.field("file", delete_target),
        woof.bool_field("exists", fio.exists(delete_target)),
      ])
    Error(e) ->
      woof.error("Delete failed", [woof.field("error", error.describe(e))])
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
        woof.field("error", error.describe(e)),
      ])
  }
  woof.info("Recursive delete demo — before", [
    woof.bool_field("tree_exists", fio.exists(del_tree)),
  ])
  case fio.delete_all(del_tree) {
    Ok(_) ->
      woof.info("Recursive delete demo — after", [
        woof.field("path", del_tree),
        woof.bool_field("tree_exists", fio.exists(del_tree)),
      ])
    Error(e) ->
      woof.error("Recursive delete failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 12. Path operations (pure, no I/O) ──────────────────────────────
  woof.info("Path operations", [
    woof.field("join", path.join("src", "main.gleam")),
    woof.field("base_name", path.base_name("/usr/local/bin/gleam")),
    woof.field("directory_name", path.directory_name("/usr/local/bin/gleam")),
    woof.field("extension", string.inspect(path.extension("main.gleam"))),
    woof.field("stem", path.stem("archive.tar.gz")),
    woof.field("with_extension", path.with_extension("main.gleam", "js")),
    woof.bool_field("is_absolute_usr", path.is_absolute("/usr")),
    woof.field(
      "join_all",
      path.join_all(["src", "fio", "internal", "io.gleam"]),
    ),
  ])

  // ── 13. Touch ────────────────────────────────────────────────────────
  let stamp = path.join(out, "touch_stamp.txt")
  case fio.touch(stamp) {
    Ok(_) ->
      woof.info("Touch created new file", [
        woof.field("file", stamp),
        woof.bool_field("exists", fio.exists(stamp)),
      ])
    Error(e) ->
      woof.error("Touch failed", [woof.field("error", error.describe(e))])
  }
  // Touch existing file to update mtime
  case fio.touch(greeting) {
    Ok(_) -> woof.info("Touch updated mtime", [woof.field("file", greeting)])
    Error(e) ->
      woof.error("Touch update failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 14. Read link ───────────────────────────────────────────────────
  case fio.read_link(link) {
    Ok(target) ->
      woof.info("Read link target", [
        woof.field("link", link),
        woof.field("target", target),
      ])
    Error(e) ->
      woof.warning("read_link failed (symlinks may not be available)", [
        woof.field("error", error.describe(e)),
      ])
  }

  // ── 15. Safe relative path ──────────────────────────────────────────
  woof.info("Path safety checks", [
    woof.field("safe_data", string.inspect(path.safe_relative("data/file.txt"))),
    woof.field(
      "unsafe_escape",
      string.inspect(path.safe_relative("../../../etc/passwd")),
    ),
    woof.field(
      "unsafe_absolute",
      string.inspect(path.safe_relative("/usr/bin")),
    ),
  ])

  // ── 16. Utility ─────────────────────────────────────────────────────
  case fio.current_directory() {
    Ok(cwd) -> woof.info("Working directory", [woof.field("cwd", cwd)])
    Error(e) ->
      woof.error("cwd failed", [woof.field("error", error.describe(e))])
  }
  woof.info("Temp directory", [woof.field("tmp_dir", fio.tmp_dir())])

  // ── 17. Error handling ──────────────────────────────────────────────
  case fio.read("this_file_does_not_exist.txt") {
    Ok(_) -> woof.warning("Expected an error but got success", [])
    Error(e) ->
      woof.info("Graceful error handling", [
        woof.field("error", error.describe(e)),
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
        woof.field("src", recursive_dir),
        woof.field("dest", "dev/output/recursive_copy"),
      ])
    Error(e) ->
      woof.error("Recursive copy failed", [
        woof.field("error", error.describe(e)),
      ])
  }

  // List recursive
  case fio.list_recursive(recursive_dir) {
    Ok(paths) ->
      woof.info("Recursive list", [woof.int_field("count", list.length(paths))])
    Error(e) ->
      woof.error("Recursive list failed", [
        woof.field("error", error.describe(e)),
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
        woof.field("error", error.describe(e)),
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
