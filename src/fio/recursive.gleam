import fio/error.{type FioError, Enotdir}
import fio/internal/io
import fio/path.{join}
import fio/types.{type FileInfo}
import gleam/int
import gleam/list
import gleam/result
import gleam/set.{type Set}

// Build a stable visited-set key from a FileInfo.
// On Windows stat returns inode 0 for all files; fall back to the full path
// string so we still detect cycles without relying on inode numbers.
fn inode_key(info: FileInfo, fallback_path: String) -> String {
  case info.inode {
    0 -> fallback_path
    _ ->
      "dev:"
      <> int.to_string(info.dev)
      <> ";ino:"
      <> int.to_string(info.inode)
  }
}

/// Recursively list files and directories (paths relative to `path`).
///
/// Uses a flat string accumulator for O(n) traversal.
///
/// **Symlink loop safety**: before descending into any directory, its real
/// `(dev, inode)` pair (obtained via `stat`, which follows symlinks) is
/// checked against the `visited` set. If already seen, the entry is listed
/// but not descended into, breaking any A->B->A or deeper circular chains.
pub fn list_recursive(path: String) -> Result(List(String), FioError) {
  use is_dir <- result.try(io.is_directory(path))
  case is_dir {
    True -> {
      use root_info <- result.try(io.file_info(path))
      let visited = set.from_list([inode_key(root_info, path)])
      use acc <- result.try(do_list_recursive(path, "", visited, []))
      Ok(list.reverse(acc))
    }
    False -> Error(Enotdir)
  }
}

// `visited`     - set of inode keys already entered, prevents loops.
// `current_rel` - relative path of the directory being scanned.
// `acc`         - reverse accumulator; reversed once at the call site.
fn do_list_recursive(
  root: String,
  current_rel: String,
  visited: Set(String),
  acc: List(String),
) -> Result(List(String), FioError) {
  let current_dir = case current_rel {
    "" -> root
    rel -> join(root, rel)
  }

  use items <- result.try(io.list_directory(current_dir))

  list.try_fold(items, acc, fn(inner_acc, item) {
    let item_rel = case current_rel {
      "" -> item
      rel -> join(rel, item)
    }
    let full_path = join(root, item_rel)

    use is_dir <- result.try(io.is_directory(full_path))

    case is_dir {
      False -> Ok([item_rel, ..inner_acc])
      True -> {
        use info <- result.try(io.file_info(full_path))
        let key = inode_key(info, full_path)
        case set.contains(visited, key) {
          // Already visited: list the entry but do not descend.
          True -> Ok([item_rel, ..inner_acc])
          False ->
            do_list_recursive(root, item_rel, set.insert(visited, key), [
              item_rel,
              ..inner_acc
            ])
        }
      }
    }
  })
}

/// Recursively copy `src` directory into `dest` (creates parents).
///
/// **Symlink loop safety**: directory symlinks whose resolved inode has
/// already been visited are skipped silently rather than followed forever.
pub fn copy_directory(src: String, dest: String) -> Result(Nil, FioError) {
  use is_dir <- result.try(io.is_directory(src))
  case is_dir {
    False -> Error(Enotdir)
    True -> {
      use root_info <- result.try(io.file_info(src))
      let visited = set.from_list([inode_key(root_info, src)])
      do_copy_directory(src, dest, visited)
    }
  }
}

fn do_copy_directory(
  src: String,
  dest: String,
  visited: Set(String),
) -> Result(Nil, FioError) {
  use _ <- result.try(io.create_directory_all(dest))
  use items <- result.try(io.list_directory(src))

  list.try_each(items, fn(item) {
    let src_path = join(src, item)
    let dest_path = join(dest, item)

    use is_dir_item <- result.try(io.is_directory(src_path))
    case is_dir_item {
      False -> io.copy_file(src_path, dest_path)
      True -> {
        use info <- result.try(io.file_info(src_path))
        let key = inode_key(info, src_path)
        case set.contains(visited, key) {
          True -> Ok(Nil)
          False ->
            do_copy_directory(src_path, dest_path, set.insert(visited, key))
        }
      }
    }
  })
}
