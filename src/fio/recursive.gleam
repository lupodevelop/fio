import fio/error.{type FioError, Enotdir}
import fio/internal/io
import fio/path.{join}
import gleam/int
import gleam/list
import gleam/result
import gleam/set.{type Set}

/// Recursively list files and directories (paths relative to `path`).
///
/// Uses a flat string accumulator for O(n) traversal.
///
/// **Symlink loop safety**: before descending into any directory, its real
/// `(dev, inode)` pair (obtained via `stat`, which follows symlinks) is
/// checked against the `visited` set. If already seen, the entry is listed
/// but not descended into — breaking any A→B→A or deeper circular chains.
pub fn list_recursive(path: String) -> Result(List(String), FioError) {
  use is_dir <- result.try(io.is_directory(path))
  case is_dir {
    True -> {
      // Seed the visited set with the root's real (dev, inode) so we
      // never re-enter it via a symlink.  We store the key as a string
      // because later we may fall back to using the path when inodes are
      // unreliable (e.g. Windows).
      use root_info <- result.try(io.file_info(path))
      let root_key = case root_info.inode {
        0 -> path
        _ ->
          "dev:"
          <> int.to_string(root_info.dev)
          <> ";ino:"
          <> int.to_string(root_info.inode)
      }
      let visited = set.from_list([root_key])
      use acc <- result.try(do_list_recursive(path, "", visited, []))
      Ok(list.reverse(acc))
    }
    False -> Error(Enotdir)
  }
}

// `visited` — set of (dev, inode) pairs already entered, prevents loops.
// `current_rel` — relative path of the directory being scanned.
// `acc` — reverse accumulator; reversed once at the call site.
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
        // Resolve the real inode (stat follows symlinks) to detect loops.
        use info <- result.try(io.file_info(full_path))
        // Windows/stat may return inode 0 for all files; fall back to using
        // the (full) path string in that case so we still avoid infinite
        // recursion.  We store everything as strings for simplicity.
        let key = case info.inode {
          0 -> full_path
          _ ->
            "dev:"
            <> int.to_string(info.dev)
            <> ";ino:"
            <> int.to_string(info.inode)
        }
        case set.contains(visited, key) {
          // Already visited: list the entry but do not descend.
          True -> Ok([item_rel, ..inner_acc])
          False -> {
            let new_visited = set.insert(visited, key)
            do_list_recursive(root, item_rel, new_visited, [
              item_rel,
              ..inner_acc
            ])
          }
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
      let root_key = case root_info.inode {
        0 -> src
        _ ->
          "dev:"
          <> int.to_string(root_info.dev)
          <> ";ino:"
          <> int.to_string(root_info.inode)
      }
      let visited = set.from_list([root_key])
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
        let key = case info.inode {
          0 -> src_path
          _ ->
            "dev:"
            <> int.to_string(info.dev)
            <> ";ino:"
            <> int.to_string(info.inode)
        }
        case set.contains(visited, key) {
          True -> Ok(Nil)
          False ->
            do_copy_directory(src_path, dest_path, set.insert(visited, key))
        }
      }
    }
  })
}
