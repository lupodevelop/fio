import fio
import fio/error
import fio/path
import gleam/list
import gleeunit/should

// ============================================================================
// Recursive Operations
// ============================================================================

pub fn recursive_list_test() {
  let root = "_test_recursive_list"
  let _ = fio.delete_all(root)
  let assert Ok(Nil) = fio.create_directory(root)
  let assert Ok(Nil) = fio.create_directory(path.join(root, "a"))
  let assert Ok(Nil) = fio.write(path.join(root, "f1.txt"), "content")
  let assert Ok(Nil) = fio.write(path.join(root, "a/f2.txt"), "content")

  let assert Ok(items) = fio.list_recursive(root)

  let assert True = list.contains(items, "f1.txt")
  let assert True = list.contains(items, "a")
  let assert True = list.contains(items, "a/f2.txt")

  let _ = fio.delete_all(root)
}

pub fn recursive_copy_test() {
  let src = "_test_copy_src"
  let dest = "_test_copy_dest"
  let _ = fio.delete_all(src)
  let _ = fio.delete_all(dest)

  // Setup src
  let assert Ok(Nil) = fio.create_directory(src)
  let assert Ok(Nil) = fio.create_directory(path.join(src, "sub"))
  let assert Ok(Nil) = fio.write(path.join(src, "file.txt"), "hello")
  let assert Ok(Nil) = fio.write(path.join(src, "sub/inner.txt"), "world")

  // Copy
  let assert Ok(Nil) = fio.copy_directory(src, dest)

  // Verify dest
  let assert Ok(True) = fio.is_directory(dest)
  let assert Ok(True) = fio.is_directory(path.join(dest, "sub"))
  let assert Ok(True) = fio.is_file(path.join(dest, "file.txt"))
  let assert Ok(True) = fio.is_file(path.join(dest, "sub/inner.txt"))

  let assert Ok("hello") = fio.read(path.join(dest, "file.txt"))
  let assert Ok("world") = fio.read(path.join(dest, "sub/inner.txt"))

  let _ = fio.delete_all(src)
  let _ = fio.delete_all(dest)
}

pub fn symlink_loop_test() {
  // create a circular symlink a -> root
  let root = "_test_loop"
  let _ = fio.delete_all(root)
  let assert Ok(Nil) = fio.create_directory(root)
  let dir1 = root <> "/a"
  let assert Ok(Nil) = fio.create_directory(dir1)
  case fio.create_symlink(target: "..", link: dir1 <> "/back") {
    Ok(_) -> {
      let assert Ok(items) = fio.list_recursive(root)
      // loop should not cause infinite recursion; entries should include
      // the symlink itself but not repeat indefinitely
      let assert True = list.contains(items, "a")
      let assert True = list.contains(items, "a/back")
      Nil
    }
    Error(_) ->
      // symlink creation may be restricted on some platforms; ignore
      Nil
  }
  let _ = fio.delete_all(root)
}

pub fn list_recursive_loop_detection_dev_inode_test() {
  // Ensure list_recursive relies on the (dev,inode) key and not just a path string.
  // This only works on platforms where `dev` is non-zero.
  let root = "_test_loop_dev"
  let _ = fio.delete_all(root)
  let assert Ok(Nil) = fio.create_directory(root)
  let dir1 = root <> "/a"
  let assert Ok(Nil) = fio.create_directory(dir1)

  case fio.create_symlink(target: "..", link: dir1 <> "/back") {
    Ok(_) -> {
      let assert Ok(root_info) = fio.file_info(root)
      let assert Ok(back_info) = fio.file_info(path.join(root, "a/back"))

      case root_info.dev {
        0 ->
          // dev is 0 on some platforms (e.g. Windows); fall back to a no-op.
          Nil
        _ -> {
          root_info.dev |> should.equal(back_info.dev)
          root_info.inode |> should.equal(back_info.inode)

          let assert Ok(entries) = fio.list_recursive(root)
          entries |> should.equal(["a", "a/back"])
        }
      }

      Nil
    }
    Error(_) -> {
      // symlink creation may be restricted on some platforms; ignore
      Nil
    }
  }

  let _ = fio.delete_all(root)
}

pub fn delete_recursive_symlink_safe_test() {
  // Ensure delete_all doesn't follow a symlink to an external directory.
  let root = "_test_delete_symlink_root"
  let external = "_test_delete_symlink_external"
  let _ = fio.delete_all(root)
  let _ = fio.delete_all(external)
  let assert Ok(Nil) = fio.create_directory(root)
  let assert Ok(Nil) = fio.create_directory(external)
  let assert Ok(Nil) = fio.write(path.join(external, "marker.txt"), "safe")
  case fio.create_symlink(target: external, link: path.join(root, "link")) {
    Ok(_) -> {
      let assert Ok(Nil) = fio.delete_all(root)
      fio.exists(external) |> should.equal(True)
      let assert Ok(_) = fio.delete_all(external)
      Nil
    }
    Error(_) -> {
      // symlink creation may be restricted on some platforms; ignore
      let _ = fio.delete_all(root)
      let _ = fio.delete_all(external)
      Nil
    }
  }
}

pub fn enotempty_test() {
  let p = "_test_enotempty_dir"
  let _ = fio.delete_all(p)
  let assert Ok(Nil) = fio.create_directory(p)
  let assert Ok(Nil) = fio.write(path.join(p, "file"), "")

  // Try to delete directory (non-recursive)
  let res = fio.delete_directory(p)

  // Expect Enotempty (or map to it)
  case res {
    Error(error.Enotempty) -> Nil
    Error(error.Eexist) -> Nil
    // Tolerated
    _unexpected -> {
      should.fail()
      Nil
    }
  }

  let _ = fio.delete_all(p)
}
