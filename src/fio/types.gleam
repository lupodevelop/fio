/// Shared types used by `fio` (FileInfo, permissions, helpers).
import gleam/set.{type Set}

/// File metadata information.
/// Represents the intersection of info available from Erlang and JavaScript.
pub type FileInfo {
  FileInfo(
    /// File size in bytes
    size: Int,
    /// File mode (type + permissions encoded as 16-bit int)
    mode: Int,
    /// Number of hard links
    nlinks: Int,
    /// Inode number
    inode: Int,
    /// User ID of the file's owner
    user_id: Int,
    /// Group ID of the file's group
    group_id: Int,
    /// Device ID
    dev: Int,
    /// Last access time (Unix timestamp seconds)
    atime_seconds: Int,
    /// Last modification time (Unix timestamp seconds)
    mtime_seconds: Int,
    /// Last change time (Unix timestamp seconds)
    ctime_seconds: Int,
  )
}

/// File type enumeration.
pub type FileType {
  /// A regular file
  File
  /// A directory
  Directory
  /// A symbolic link
  Symlink
  /// Another special file type (socket, device, etc.)
  Other
}

/// Hashing algorithms for file checksums.
pub type HashAlgorithm {
  Sha256
  Sha512
  Md5
}

/// A single file permission.
pub type Permission {
  Read
  Write
  Execute
}

/// File permissions for user, group, and other.
pub type FilePermissions {
  FilePermissions(
    user: Set(Permission),
    group: Set(Permission),
    other: Set(Permission),
  )
}

/// Extract the file type from a FileInfo value.
pub fn file_info_type(info: FileInfo) -> FileType {
  // https://github.com/nodejs/node/blob/main/typings/internalBinding/constants.d.ts#L147
  let masked = int_bitwise_and(info.mode, 0o170000)
  case masked {
    0o100000 -> File
    0o40000 -> Directory
    0o120000 -> Symlink
    _ -> Other
  }
}

/// Extract permissions octal from FileInfo.
pub fn file_info_permissions_octal(info: FileInfo) -> Int {
  int_bitwise_and(info.mode, 0o777)
}

/// Extract FilePermissions from FileInfo.
pub fn file_info_permissions(info: FileInfo) -> FilePermissions {
  octal_to_file_permissions(file_info_permissions_octal(info))
}

/// Convert octal permissions integer to FilePermissions.
pub fn octal_to_file_permissions(octal: Int) -> FilePermissions {
  let user = integer_to_permissions(int_shift_right(octal, 6))
  let group =
    integer_to_permissions(int_shift_right(int_bitwise_and(octal, 0o70), 3))
  let other = integer_to_permissions(int_bitwise_and(octal, 0o7))
  FilePermissions(user:, group:, other:)
}

/// Convert FilePermissions to octal integer.
pub fn file_permissions_to_octal(permissions: FilePermissions) -> Int {
  let user = permissions_to_integer(permissions.user)
  let group = permissions_to_integer(permissions.group)
  let other = permissions_to_integer(permissions.other)
  int_shift_left(user, 6) + int_shift_left(group, 3) + other
}

// --- Internal helpers ---

fn permissions_to_integer(perms: Set(Permission)) -> Int {
  let r = case set.contains(perms, Read) {
    True -> 0o4
    False -> 0
  }
  let w = case set.contains(perms, Write) {
    True -> 0o2
    False -> 0
  }
  let x = case set.contains(perms, Execute) {
    True -> 0o1
    False -> 0
  }
  r + w + x
}

fn integer_to_permissions(n: Int) -> Set(Permission) {
  let base = set.new()
  let base = case int_bitwise_and(n, 0o4) > 0 {
    True -> set.insert(base, Read)
    False -> base
  }
  let base = case int_bitwise_and(n, 0o2) > 0 {
    True -> set.insert(base, Write)
    False -> base
  }
  case int_bitwise_and(n, 0o1) > 0 {
    True -> set.insert(base, Execute)
    False -> base
  }
}

// Gleam doesn't have bitwise ops in stdlib for Int,
// we use external functions
@external(erlang, "erlang", "band")
@external(javascript, "../fio_ffi.mjs", "bitwise_and")
fn int_bitwise_and(a: Int, b: Int) -> Int

@external(erlang, "erlang", "bsr")
@external(javascript, "../fio_ffi.mjs", "bitwise_shift_right")
fn int_shift_right(a: Int, b: Int) -> Int

@external(erlang, "erlang", "bsl")
@external(javascript, "../fio_ffi.mjs", "bitwise_shift_left")
fn int_shift_left(a: Int, b: Int) -> Int
