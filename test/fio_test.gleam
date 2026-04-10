import fio
import fio/error.{Enoent, NotUtf8}
import fio/handle
import fio/json as fjson
import fio/observer
import fio/path
import fio/types
import gleam/bit_array
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/set
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// ============================================================================
// Read / Write
// ============================================================================

pub fn write_and_read_test() {
  let p = "_test_rw.txt"
  let assert Ok(_) = fio.write(p, "hello fio")
  fio.read(p) |> should.equal(Ok("hello fio"))
  let assert Ok(_) = fio.delete(p)
}

pub fn write_bits_and_read_bits_test() {
  let p = "_test_bits.bin"
  let data = <<0, 1, 2, 255>>
  let assert Ok(_) = fio.write_bits(p, data)
  fio.read_bits(p) |> should.equal(Ok(data))
  let assert Ok(_) = fio.delete(p)
}

pub fn append_test() {
  let p = "_test_append.txt"
  let assert Ok(_) = fio.write(p, "line1")
  let assert Ok(_) = fio.append(p, "\nline2")
  fio.read(p) |> should.equal(Ok("line1\nline2"))
  let assert Ok(_) = fio.delete(p)
}

pub fn write_atomic_test() {
  let p = "_test_atomic.txt"
  let assert Ok(_) = fio.write_atomic(p, "atomic content")
  fio.read(p) |> should.equal(Ok("atomic content"))
  // Overwrite atomically: readers never see partial state
  let assert Ok(_) = fio.write_atomic(p, "updated atomically")
  fio.read(p) |> should.equal(Ok("updated atomically"))
  let assert Ok(_) = fio.delete(p)
}

pub fn write_bits_atomic_test() {
  let p = "_test_atomic_bits.bin"
  let data = <<0xDE, 0xAD, 0xBE, 0xEF>>
  let assert Ok(_) = fio.write_bits_atomic(p, data)
  fio.read_bits(p) |> should.equal(Ok(data))
  let assert Ok(_) = fio.delete(p)
}

pub fn read_nonexistent_test() {
  case fio.read("_nonexistent_file_fio_test.txt") {
    Error(Enoent) -> Nil
    _other -> {
      should.fail()
    }
  }
}

// ============================================================================
// Exists
// ============================================================================

pub fn exists_test() {
  let p = "_test_exists.txt"
  fio.exists(p) |> should.equal(False)
  let assert Ok(_) = fio.write(p, "x")
  fio.exists(p) |> should.equal(True)
  let assert Ok(_) = fio.delete(p)
}

pub fn exists_directory_test() {
  let d = "_test_exists_dir"
  let assert Ok(_) = fio.create_directory(d)
  fio.exists(d) |> should.equal(True)
  let assert Ok(_) = fio.delete_directory(d)
}

// ============================================================================
// Delete
// ============================================================================

pub fn delete_test() {
  let p = "_test_del.txt"
  let assert Ok(_) = fio.write(p, "x")
  fio.exists(p) |> should.equal(True)
  let assert Ok(_) = fio.delete(p)
  fio.exists(p) |> should.equal(False)
}

pub fn delete_all_test() {
  let dir = "_test_del_all"
  let assert Ok(_) = fio.create_directory_all(dir <> "/sub")
  let assert Ok(_) = fio.write(dir <> "/sub/file.txt", "deep")
  let assert Ok(_) = fio.delete_all(dir)
  fio.exists(dir) |> should.equal(False)
}

// ============================================================================
// File info
// ============================================================================

pub fn file_info_test() {
  let p = "_test_info.txt"
  let assert Ok(_) = fio.write(p, "hello")
  let assert Ok(info) = fio.file_info(p)
  info.size |> should.equal(5)
  types.file_info_type(info) |> should.equal(types.File)
  let assert Ok(_) = fio.delete(p)
}

pub fn file_info_dev_nonzero_test() {
  // Ensure `dev` is meaningful so list_recursive can use it for loop detection.
  let p = "_test_info_dev.txt"
  let assert Ok(_) = fio.write(p, "hello")
  let assert Ok(info) = fio.file_info(p)
  { info.dev != 0 } |> should.equal(True)
  let assert Ok(_) = fio.delete(p)
}

pub fn is_directory_test() {
  let d = "_test_isdir"
  let assert Ok(_) = fio.create_directory(d)
  fio.is_directory(d) |> should.equal(Ok(True))
  fio.is_file(d) |> should.equal(Ok(False))
  let assert Ok(_) = fio.delete_directory(d)
}

pub fn is_file_test() {
  let p = "_test_isfile.txt"
  let assert Ok(_) = fio.write(p, "x")
  fio.is_file(p) |> should.equal(Ok(True))
  fio.is_directory(p) |> should.equal(Ok(False))
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// Copy & Rename
// ============================================================================

pub fn copy_test() {
  let src = "_test_copy_src.txt"
  let dst = "_test_copy_dst.txt"
  let assert Ok(_) = fio.write(src, "copy me")
  let assert Ok(_) = fio.copy(src, dst)
  fio.read(dst) |> should.equal(Ok("copy me"))
  let assert Ok(_) = fio.delete(src)
  let assert Ok(_) = fio.delete(dst)
}

pub fn rename_test() {
  let old = "_test_rename_old.txt"
  let new = "_test_rename_new.txt"
  let assert Ok(_) = fio.write(old, "move me")
  let assert Ok(_) = fio.rename(old, new)
  fio.exists(old) |> should.equal(False)
  fio.read(new) |> should.equal(Ok("move me"))
  let assert Ok(_) = fio.delete(new)
}

// ============================================================================
// Directories
// ============================================================================

pub fn create_directory_all_test() {
  let d = "_test_mkdirp/a/b/c"
  let assert Ok(_) = fio.create_directory_all(d)
  fio.is_directory(d) |> should.equal(Ok(True))
  let assert Ok(_) = fio.delete_all("_test_mkdirp")
}

pub fn list_test() {
  let d = "_test_list"
  let assert Ok(_) = fio.create_directory(d)
  let assert Ok(_) = fio.write(d <> "/a.txt", "a")
  let assert Ok(_) = fio.write(d <> "/b.txt", "b")
  let assert Ok(entries) = fio.list(d)
  let sorted = list_sort(entries)
  sorted |> should.equal(["a.txt", "b.txt"])
  let assert Ok(_) = fio.delete_all(d)
}

// ============================================================================
// Symlinks
// ============================================================================

pub fn create_symlink_test() {
  let target = "_test_sym_target.txt"
  let link = "_test_sym_link.txt"
  let assert Ok(_) = fio.write(target, "linked")
  case fio.create_symlink(target: target, link: link) {
    Ok(_) -> {
      fio.is_symlink(link) |> should.equal(Ok(True))
      fio.read(link) |> should.equal(Ok("linked"))
      let assert Ok(_) = fio.delete(link)
      Nil
    }
    Error(_) -> Nil
  }
  let assert Ok(_) = fio.delete(target)
}

// ============================================================================
// Permissions
// ============================================================================

pub fn permissions_test() {
  let p = "_test_perms.txt"
  let assert Ok(_) = fio.write(p, "x")
  let perms =
    types.FilePermissions(
      user: set.from_list([types.Read, types.Write, types.Execute]),
      group: set.from_list([types.Read, types.Execute]),
      other: set.from_list([types.Read]),
    )

  // On some platforms (notably Windows), chmod/permissions may be a no-op or
  // return `Eperm`/`Enotsup`. We tolerate that to keep tests cross-platform.
  case fio.set_permissions(p, perms) {
    Ok(_) -> {
      let assert Ok(info) = fio.file_info(p)
      types.file_info_permissions_octal(info) |> should.equal(0o754)
      Nil
    }
    Error(error.Eperm) -> Nil
    Error(error.Enotsup) -> Nil
    _ -> should.fail()
  }

  let assert Ok(_) = fio.delete(p)
}

pub fn set_permissions_octal_test() {
  let p = "_test_perms_o.txt"
  let assert Ok(_) = fio.write(p, "x")

  case fio.set_permissions_octal(p, 0o644) {
    Ok(_) -> {
      let assert Ok(info) = fio.file_info(p)
      types.file_info_permissions_octal(info) |> should.equal(0o644)
      Nil
    }
    Error(error.Eperm) -> Nil
    Error(error.Enotsup) -> Nil
    _ -> should.fail()
  }

  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// Path operations
// ============================================================================

pub fn path_join_test() {
  path.join("src", "main.gleam") |> should.equal("src/main.gleam")
}

pub fn path_base_name_test() {
  path.base_name("/usr/local/bin") |> should.equal("bin")
}

pub fn path_directory_name_test() {
  path.directory_name("/usr/local/bin") |> should.equal("/usr/local")
}

pub fn path_extension_test() {
  path.extension("file.gleam") |> should.equal(Ok("gleam"))
}

pub fn path_stem_test() {
  path.stem("main.gleam") |> should.equal("main")
}

pub fn path_with_extension_test() {
  path.with_extension("main.gleam", "js") |> should.equal("main.js")
}

pub fn path_is_absolute_test() {
  path.is_absolute("/usr") |> should.equal(True)
  path.is_absolute("src") |> should.equal(False)
}

pub fn path_join_all_test() {
  path.join_all(["src", "fio", "internal"]) |> should.equal("src/fio/internal")
}

pub fn path_join_all_empty_test() {
  // empty list now returns "." rather than empty string
  path.join_all([]) |> should.equal(".")
}

pub fn path_expand_test() {
  path.expand("src/../lib") |> should.equal(Ok("lib"))
}

pub fn path_split_test() {
  path.split("src/fio/main.gleam")
  |> should.equal(["src", "fio", "main.gleam"])
}

pub fn windows_style_path_join_split_test() {
  // Ensure windows-style paths (drive letter + backslashes) behave predictably
  // on BEAM. We do not assume that separators are normalized to `/`.
  let joined = path.join("C:\\foo", "bar")
  joined |> should.equal("C:\\foo/bar")

  let parts = path.split("C:\\foo\\bar")
  parts |> should.equal(["C:\\foo\\bar"])
}

// ============================================================================
// Utility
// ============================================================================

pub fn current_directory_test() {
  let assert Ok(cwd) = fio.current_directory()
  { string.length(cwd) > 0 } |> should.equal(True)
}

pub fn tmp_dir_test() {
  let tmp = fio.tmp_dir()
  { string.length(tmp) > 0 } |> should.equal(True)
}

// ============================================================================
// Error describe
// ============================================================================

pub fn error_describe_test() {
  error.describe(error.Enoent) |> should.equal("No such file or directory")
  error.describe(error.Eacces) |> should.equal("Permission denied")
}

// ============================================================================
// Types helpers
// ============================================================================

pub fn octal_to_file_permissions_test() {
  let perms = types.octal_to_file_permissions(0o755)
  set.contains(perms.user, types.Read) |> should.equal(True)
  set.contains(perms.user, types.Write) |> should.equal(True)
  set.contains(perms.user, types.Execute) |> should.equal(True)
  set.contains(perms.group, types.Read) |> should.equal(True)
  set.contains(perms.group, types.Write) |> should.equal(False)
  set.contains(perms.group, types.Execute) |> should.equal(True)
  set.contains(perms.other, types.Read) |> should.equal(True)
  set.contains(perms.other, types.Write) |> should.equal(False)
  set.contains(perms.other, types.Execute) |> should.equal(True)
}

pub fn file_permissions_roundtrip_test() {
  let perms = types.octal_to_file_permissions(0o644)
  types.file_permissions_to_octal(perms) |> should.equal(0o644)
}

// ============================================================================
// Touch
// ============================================================================

pub fn touch_creates_new_file_test() {
  let p = "_test_touch_new.txt"
  let assert False = fio.exists(p)
  let assert Ok(_) = fio.touch(p)
  fio.exists(p) |> should.equal(True)
  // File should be empty
  fio.read(p) |> should.equal(Ok(""))
  let assert Ok(_) = fio.delete(p)
}

pub fn touch_updates_existing_test() {
  let p = "_test_touch_existing.txt"
  let assert Ok(_) = fio.write(p, "hello")
  let assert Ok(_) = fio.touch(p)
  // Content should be preserved
  fio.read(p) |> should.equal(Ok("hello"))
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// Read link
// ============================================================================

pub fn read_link_test() {
  let target = "_test_readlink_target.txt"
  let link = "_test_readlink_link.txt"
  let assert Ok(_) = fio.write(target, "target content")
  case fio.create_symlink(target: target, link: link) {
    Ok(_) -> {
      fio.read_link(link) |> should.equal(Ok(target))
      let assert Ok(_) = fio.delete(link)
      Nil
    }
    Error(_) -> Nil
  }
  let assert Ok(_) = fio.delete(target)
}

pub fn read_link_not_a_link_test() {
  let p = "_test_readlink_nolink.txt"
  let assert Ok(_) = fio.write(p, "regular file")
  case fio.read_link(p) {
    Error(_) -> Nil
    Ok(_) -> should.fail()
  }
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// Safe relative
// ============================================================================

pub fn safe_relative_valid_test() {
  path.safe_relative("data/file.txt") |> should.equal(Ok("data/file.txt"))
}

pub fn safe_relative_normalizes_test() {
  path.safe_relative("a/b/../c") |> should.equal(Ok("a/c"))
}

pub fn safe_relative_blocks_escape_test() {
  path.safe_relative("../etc/passwd") |> should.equal(Error(Nil))
}

pub fn safe_relative_blocks_absolute_test() {
  path.safe_relative("/usr/bin") |> should.equal(Error(Nil))
}

pub fn safe_relative_blocks_windows_drive_test() {
  // Windows style absolute path must also be blocked
  path.safe_relative("C:\\Windows\\system32") |> should.equal(Error(Nil))
}

pub fn safe_relative_blocks_deep_escape_test() {
  path.safe_relative("a/b/../../../c") |> should.equal(Error(Nil))
}

pub fn safe_relative_blocks_windows_backslashes_test() {
  // Backslashes should not allow escaping the base directory.
  // This is primarily relevant when a Windows-style path is passed on other platforms.
  path.safe_relative("..\\..\\etc\\passwd") |> should.equal(Error(Nil))
}

// ============================================================================
// Delete all idempotent
// ============================================================================

pub fn delete_all_nonexistent_test() {
  // Should succeed silently on non-existent path
  fio.delete_all("_test_nonexistent_dir_12345")
  |> should.equal(Ok(Nil))
}

// ============================================================================
// NotUtf8 detection
// ============================================================================

pub fn read_not_utf8_test() {
  let p = "_test_not_utf8.bin"
  // Write invalid UTF-8 bytes
  let assert Ok(_) = fio.write_bits(p, <<0xFF, 0xFE, 0x80, 0x81, 0x82>>)
  case fio.read(p) {
    Error(NotUtf8(_)) -> Nil
    _other -> should.fail()
  }
  let assert Ok(_) = fio.delete(p)
}

pub fn list_recursive_symlink_loop_test() {
  let base = "_test_recursive_loop"
  let file = base <> "/a.txt"
  let link = base <> "/loop"

  let assert Ok(_) = fio.create_directory_all(base)
  let assert Ok(_) = fio.write(file, "x")

  // If the platform supports symlinks, create a loop and ensure recursion
  // does not run away.
  case fio.create_symlink(target: base, link: link) {
    Ok(_) -> {
      case fio.list_recursive(base) {
        Ok(entries) -> {
          let joined = string.join(entries, "|")
          string.contains(joined, "loop") |> should.equal(True)
          string.contains(joined, "loop/loop") |> should.equal(False)
          Nil
        }
        Error(_) -> Nil
      }
    }
    Error(_) -> Nil
  }

  let assert Ok(_) = fio.delete_all(base)
}

pub fn with_temp_directory_cleanup_on_error_test() {
  let marker = "_test_temp_cleanup_marker.txt"

  // Create a marker inside the temp dir and return an error.
  let result =
    fio.with_temp_directory(fn(dir) {
      let assert Ok(_) = fio.write(dir <> "/" <> marker, "x")
      Error(error.Eio)
    })

  case result {
    Error(error.Eio) -> Nil
    _ -> should.fail()
  }

  // Ensure no temp directory still contains the marker file.
  let tmp = fio.tmp_dir()
  let assert Ok(entries) = fio.list(tmp)
  let tmp_dirs = list_filter(entries, fn(e) { starts_with(e, "fio_tmp_dir_") })

  let _ =
    list.try_each(tmp_dirs, fn(d) {
      let path = tmp <> "/" <> d <> "/" <> marker
      fio.exists(path) |> should.equal(False)
      Ok(Nil)
    })

  Ok(Nil)
}

// --- Internal helpers ---

fn starts_with(s: String, prefix: String) -> Bool {
  case string.length(s) >= string.length(prefix) {
    True -> string.slice(s, 0, string.length(prefix)) == prefix
    False -> False
  }
}

fn list_sort(items: List(String)) -> List(String) {
  case items {
    [] -> []
    [x] -> [x]
    [head, ..tail] -> {
      let smaller =
        list_filter(tail, fn(s) { string.compare(s, head) == order.Lt })
      let greater =
        list_filter(tail, fn(s) { string.compare(s, head) != order.Lt })
      list_append(list_sort(smaller), [head, ..list_sort(greater)])
    }
  }
}

fn list_filter(items: List(a), pred: fn(a) -> Bool) -> List(a) {
  case items {
    [] -> []
    [head, ..tail] ->
      case pred(head) {
        True -> [head, ..list_filter(tail, pred)]
        False -> list_filter(tail, pred)
      }
  }
}

fn list_append(a: List(x), b: List(x)) -> List(x) {
  case a {
    [] -> b
    [head, ..tail] -> [head, ..list_append(tail, b)]
  }
}

// ============================================================================
// FileHandle
// ============================================================================

pub fn handle_read_all_test() {
  let p = "_test_handle_read.txt"
  let assert Ok(_) = fio.write(p, "handle content")
  let assert Ok(h) = handle.open(p, handle.ReadOnly)
  let assert Ok(content) = handle.read_all(h)
  let assert Ok(_) = handle.close(h)
  content |> should.equal("handle content")
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_write_test() {
  let p = "_test_handle_write.txt"
  let assert Ok(h) = handle.open(p, handle.WriteOnly)
  let assert Ok(_) = handle.write(h, "written via handle")
  let assert Ok(_) = handle.close(h)
  fio.read(p) |> should.equal(Ok("written via handle"))
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_append_test() {
  let p = "_test_handle_append.txt"
  let assert Ok(_) = fio.write(p, "first")
  let assert Ok(h) = handle.open(p, handle.AppendOnly)
  let assert Ok(_) = handle.write(h, " second")
  let assert Ok(_) = handle.close(h)
  fio.read(p) |> should.equal(Ok("first second"))
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_read_chunk_test() {
  let p = "_test_handle_chunk.txt"
  let assert Ok(_) = fio.write(p, "abcdefgh")
  let assert Ok(h) = handle.open(p, handle.ReadOnly)
  // First chunk: exactly 4 bytes
  let assert Ok(Some(c1)) = handle.read_chunk(h, 4)
  c1 |> should.equal(<<"abcd":utf8>>)
  // Second chunk: next 4 bytes
  let assert Ok(Some(c2)) = handle.read_chunk(h, 4)
  c2 |> should.equal(<<"efgh":utf8>>)
  // Third read: must be EOF
  let assert Ok(eof) = handle.read_chunk(h, 4)
  eof |> should.equal(None)
  let assert Ok(_) = handle.close(h)
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_open_nonexistent_test() {
  case handle.open("_nonexistent_handle_fio_test.txt", handle.ReadOnly) {
    Error(Enoent) -> Nil
    _ -> should.fail()
  }
}

pub fn handle_bits_roundtrip_test() {
  let p = "_test_handle_bits.bin"
  let data = <<0xCA, 0xFE, 0xBA, 0xBE>>
  let assert Ok(h) = handle.open(p, handle.WriteOnly)
  let assert Ok(_) = handle.write_bits(h, data)
  let assert Ok(_) = handle.close(h)
  let assert Ok(h2) = handle.open(p, handle.ReadOnly)
  let assert Ok(read_back) = handle.read_all_bits(h2)
  let assert Ok(_) = handle.close(h2)
  read_back |> should.equal(data)
  let assert Ok(_) = fio.delete(p)
}

// handle.with — resource-bracket pattern

pub fn handle_with_read_test() {
  let p = "_test_handle_with_read.txt"
  let assert Ok(_) = fio.write(p, "bracket content")
  // handle is always closed even if read_all returns Error
  let result = handle.with(p, handle.ReadOnly, fn(h) { handle.read_all(h) })
  result |> should.equal(Ok("bracket content"))
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_with_write_test() {
  let p = "_test_handle_with_write.txt"
  let result =
    handle.with(p, handle.WriteOnly, fn(h) { handle.write(h, "via bracket") })
  result |> should.equal(Ok(Nil))
  fio.read(p) |> should.equal(Ok("via bracket"))
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_with_use_syntax_test() {
  // Demonstrates idiomatic use-syntax with handle.with
  let p = "_test_handle_with_use.txt"
  let assert Ok(_) = fio.write(p, "use syntax")
  let read_result = {
    use h <- handle.with(p, handle.ReadOnly)
    handle.read_all(h)
  }
  read_result |> should.equal(Ok("use syntax"))
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_with_close_on_error_test() {
  // If the file does not exist, with returns Enoent and nothing leaks
  let result =
    handle.with("_nonexistent_with.txt", handle.ReadOnly, fn(h) {
      handle.read_all(h)
    })
  case result {
    Error(error.Enoent) -> Nil
    _ -> should.fail()
  }
}

// handle.seek / handle.tell

pub fn handle_seek_rewind_test() {
  let p = "_test_seek_rewind.txt"
  let assert Ok(_) = fio.write(p, "abcdefgh")
  let assert Ok(h) = handle.open(p, handle.ReadOnly)
  // Read first 4 bytes, then rewind to 0 and re-read
  let assert Ok(Some(first)) = handle.read_chunk(h, 4)
  first |> should.equal(<<"abcd":utf8>>)
  let assert Ok(_) = handle.seek(h, 0)
  let assert Ok(Some(again)) = handle.read_chunk(h, 4)
  again |> should.equal(<<"abcd":utf8>>)
  let assert Ok(_) = handle.close(h)
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_seek_mid_test() {
  let p = "_test_seek_mid.txt"
  let assert Ok(_) = fio.write(p, "abcdefgh")
  let assert Ok(h) = handle.open(p, handle.ReadOnly)
  // Jump directly to byte 4 and read the second half
  let assert Ok(_) = handle.seek(h, 4)
  let assert Ok(Some(chunk)) = handle.read_chunk(h, 4)
  chunk |> should.equal(<<"efgh":utf8>>)
  let assert Ok(_) = handle.close(h)
  let assert Ok(_) = fio.delete(p)
}

pub fn handle_tell_test() {
  let p = "_test_tell.txt"
  let assert Ok(_) = fio.write(p, "abcdefgh")
  let assert Ok(h) = handle.open(p, handle.ReadOnly)
  // Position at open is 0
  let assert Ok(0) = handle.tell(h)
  // After reading 4 bytes, position is 4
  let assert Ok(Some(_)) = handle.read_chunk(h, 4)
  let assert Ok(4) = handle.tell(h)
  // Seek back to 2, verify tell
  let assert Ok(_) = handle.seek(h, 2)
  let assert Ok(2) = handle.tell(h)
  let assert Ok(_) = handle.close(h)
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// ensure_file
// ============================================================================

pub fn ensure_file_creates_when_missing_test() {
  let p = "_test_ensure_file_new.txt"
  let assert False = fio.exists(p)
  let assert Ok(Nil) = fio.ensure_file(p)
  fio.exists(p) |> should.equal(True)
  fio.read(p) |> should.equal(Ok(""))
  let assert Ok(_) = fio.delete(p)
}

pub fn ensure_file_noop_when_exists_test() {
  let p = "_test_ensure_file_existing.txt"
  let assert Ok(_) = fio.write(p, "preserve me")
  let assert Ok(Nil) = fio.ensure_file(p)
  fio.read(p) |> should.equal(Ok("preserve me"))
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// copy_if_newer
// ============================================================================

pub fn copy_if_newer_copies_when_dest_missing_test() {
  let src = "_test_cin_src.txt"
  let dest = "_test_cin_dest.txt"
  let assert Ok(_) = fio.write(src, "source")
  let assert False = fio.exists(dest)
  fio.copy_if_newer(src, dest) |> should.equal(Ok(True))
  fio.read(dest) |> should.equal(Ok("source"))
  let assert Ok(_) = fio.delete(src)
  let assert Ok(_) = fio.delete(dest)
}

pub fn copy_if_newer_no_error_when_same_mtime_test() {
  let src = "_test_cin_same_src.txt"
  let dest = "_test_cin_same_dest.txt"
  let assert Ok(_) = fio.write(src, "original")
  let assert Ok(_) = fio.write(dest, "destination")
  let assert Ok(_) = fio.touch(dest)
  case fio.copy_if_newer(src, dest) {
    Ok(_) -> Nil
    Error(_) -> should.fail()
  }
  let assert Ok(_) = fio.delete(src)
  let assert Ok(_) = fio.delete(dest)
}

// ============================================================================
// read_fold (streaming)
// ============================================================================

pub fn read_fold_counts_bytes_test() {
  let p = "_test_read_fold.bin"
  let assert Ok(_) = fio.write_bits(p, <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11>>)
  let result =
    fio.read_fold(p, 4, 0, fn(acc, chunk) { acc + bit_array.byte_size(chunk) })
  result |> should.equal(Ok(12))
  let assert Ok(_) = fio.delete(p)
}

pub fn read_fold_collects_chunks_test() {
  let p = "_test_read_fold_collect.txt"
  let assert Ok(_) = fio.write(p, "abcdefgh")
  let result = fio.read_fold(p, 2, [], fn(acc, chunk) { [chunk, ..acc] })
  case result {
    Ok(chunks) -> list.length(chunks) |> should.equal(4)
    Error(_) -> should.fail()
  }
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// handle.fold_chunks
// ============================================================================

pub fn handle_fold_chunks_test() {
  let p = "_test_fold_chunks.bin"
  let assert Ok(_) = fio.write_bits(p, <<10, 20, 30, 40, 50, 60>>)
  let assert Ok(h) = handle.open(p, handle.ReadOnly)
  let result =
    handle.fold_chunks(h, 3, 0, fn(acc, chunk) {
      acc + bit_array.byte_size(chunk)
    })
  let assert Ok(_) = handle.close(h)
  result |> should.equal(Ok(6))
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// fio/json helpers
// ============================================================================

pub fn json_read_json_ok_test() {
  let p = "_test_json_read.json"
  let assert Ok(_) = fio.write(p, "{\"key\":\"value\"}")
  let result = fjson.read_json(p, fn(s) { Ok(s) })
  result |> should.equal(Ok("{\"key\":\"value\"}"))
  let assert Ok(_) = fio.delete(p)
}

pub fn json_read_json_io_error_test() {
  let result = fjson.read_json("_nonexistent_json_fio.json", fn(s) { Ok(s) })
  case result {
    Error(fjson.IoError(Enoent)) -> Nil
    _ -> should.fail()
  }
}

pub fn json_read_json_parse_error_test() {
  let p = "_test_json_parse_err.json"
  let assert Ok(_) = fio.write(p, "not json")
  let result = fjson.read_json(p, fn(_s) { Error("invalid json") })
  case result {
    Error(fjson.ParseError("invalid json")) -> Nil
    _ -> should.fail()
  }
  let assert Ok(_) = fio.delete(p)
}

pub fn json_write_json_atomic_test() {
  let p = "_test_json_write_atomic.json"
  let assert Ok(_) =
    fjson.write_json_atomic(p, "hello", fn(s) { "\"" <> s <> "\"" })
  fio.read(p) |> should.equal(Ok("\"hello\""))
  let assert Ok(_) = fio.delete(p)
}

// ============================================================================
// fio/observer helpers
// ============================================================================

pub fn observer_trace_ok_test() {
  let p = "_test_observer_trace.txt"
  let assert Ok(_) = fio.write(p, "observed")
  let seen = "_test_observer_flag.txt"
  fio.read(p)
  |> observer.trace("read", p, fn(event) {
    case event.outcome {
      Ok(_) -> {
        let assert Ok(_) = fio.write(seen, "ok")
        Nil
      }
      Error(_) -> Nil
    }
  })
  |> should.equal(Ok("observed"))
  fio.exists(seen) |> should.equal(True)
  let assert Ok(_) = fio.delete(p)
  let assert Ok(_) = fio.delete(seen)
}

pub fn observer_trace_error_propagates_test() {
  let flag = "_test_observer_err_flag.txt"
  fio.read("_nonexistent_observer_test.txt")
  |> observer.trace("read", "_nonexistent_observer_test.txt", fn(event) {
    case event.outcome {
      Error(_) -> {
        let assert Ok(_) = fio.write(flag, "error_seen")
        Nil
      }
      Ok(_) -> Nil
    }
  })
  |> should.equal(Error(error.Enoent))
  fio.read(flag) |> should.equal(Ok("error_seen"))
  let assert Ok(_) = fio.delete(flag)
}

pub fn observer_emit_with_bytes_test() {
  let p = "_test_observer_bytes.bin"
  let assert Ok(_) = fio.write_bits(p, <<1, 2, 3, 4>>)
  let recorded = "_test_observer_bytes_flag.txt"
  fio.read_bits(p)
  |> observer.emit("read_bits", p, option.Some(4), fn(event) {
    case event.bytes {
      option.Some(n) -> {
        let assert Ok(_) = fio.write(recorded, "bytes=" <> string.inspect(n))
        Nil
      }
      option.None -> Nil
    }
  })
  |> should.equal(Ok(<<1, 2, 3, 4>>))
  fio.read(recorded) |> should.equal(Ok("bytes=4"))
  let assert Ok(_) = fio.delete(p)
  let assert Ok(_) = fio.delete(recorded)
}

pub fn observer_trace_bytes_infers_size_test() {
  let p = "_test_observer_trace_bytes.bin"
  let assert Ok(_) = fio.write_bits(p, <<10, 20, 30>>)
  let recorded = "_test_obs_tb_flag.txt"
  fio.read_bits(p)
  |> observer.trace_bytes("read_bits", p, fn(event) {
    case event.bytes {
      option.Some(n) -> {
        let assert Ok(_) = fio.write(recorded, string.inspect(n))
        Nil
      }
      option.None -> Nil
    }
  })
  |> should.equal(Ok(<<10, 20, 30>>))
  fio.read(recorded) |> should.equal(Ok("3"))
  let assert Ok(_) = fio.delete(p)
  let assert Ok(_) = fio.delete(recorded)
}

pub fn observer_format_ok_test() {
  let event =
    observer.Event(
      op: "write",
      path: "foo.txt",
      outcome: Ok(Nil),
      bytes: option.None,
    )
  observer.format(event)
  |> should.equal("[fio] write foo.txt -> ok")
}

pub fn observer_format_error_with_bytes_test() {
  let event =
    observer.Event(
      op: "read",
      path: "bar.txt",
      outcome: Error(error.Enoent),
      bytes: option.Some(512),
    )
  let desc = observer.format(event)
  string.contains(desc, "err(") |> should.equal(True)
  string.contains(desc, "bytes=512") |> should.equal(True)
}

pub fn observer_fan_out_test() {
  let flag1 = "_test_fanout_1.txt"
  let flag2 = "_test_fanout_2.txt"
  let sink1 = fn(_e: observer.Event) {
    let assert Ok(_) = fio.write(flag1, "s1")
    Nil
  }
  let sink2 = fn(_e: observer.Event) {
    let assert Ok(_) = fio.write(flag2, "s2")
    Nil
  }
  let combined = observer.fan_out(sink1, sink2)
  fio.write("_test_fanout_src.txt", "x")
  |> observer.trace("write", "_test_fanout_src.txt", combined)
  |> should.equal(Ok(Nil))
  fio.read(flag1) |> should.equal(Ok("s1"))
  fio.read(flag2) |> should.equal(Ok("s2"))
  let assert Ok(_) = fio.delete(flag1)
  let assert Ok(_) = fio.delete(flag2)
  let assert Ok(_) = fio.delete("_test_fanout_src.txt")
}

pub fn observer_noop_sink_test() {
  // noop_sink must not raise or alter the result
  fio.write("_test_noop_sink.txt", "data")
  |> observer.trace("write", "_test_noop_sink.txt", observer.noop_sink)
  |> should.equal(Ok(Nil))
  let assert Ok(_) = fio.delete("_test_noop_sink.txt")
}

// ============================================================================
// error.describe Unknown with context
// ============================================================================

pub fn error_describe_unknown_with_context_test() {
  let e = error.Unknown("raw_error", option.Some("extra context"))
  error.describe(e)
  |> should.equal("Unknown error: raw_error (extra context)")
}

pub fn error_describe_unknown_no_context_test() {
  let e = error.Unknown("raw_error", option.None)
  error.describe(e) |> should.equal("Unknown error: raw_error")
}
