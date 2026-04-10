/// Fio error types (POSIX-like and semantic errors).
import gleam/option.{type Option}

/// All possible errors from fio operations.
pub type FioError {

  // --- POSIX errors (BEAM ecosystem compatible) ---
  /// Permission denied
  Eacces
  /// Resource temporarily unavailable
  Eagain
  /// Bad file descriptor
  Ebadf
  /// Bad message
  Ebadmsg
  /// File busy
  Ebusy
  /// Resource deadlock avoided
  Edeadlk
  /// Disk quota exceeded
  Edquot
  /// File already exists
  Eexist
  /// Bad address in system call argument
  Efault
  /// File too large
  Efbig
  /// Interrupted system call
  Eintr
  /// Invalid argument
  Einval
  /// I/O error
  Eio
  /// Illegal operation on a directory
  Eisdir
  /// Too many levels of symbolic links
  Eloop
  /// Too many open files
  Emfile
  /// Too many links
  Emlink
  /// Filename too long
  Enametoolong
  /// File table overflow
  Enfile
  /// No such device
  Enodev
  /// No such file or directory
  Enoent
  /// Not enough memory
  Enomem
  /// No space left on device
  Enospc
  /// Function not implemented
  Enosys
  /// Block device required
  Enotblk
  /// Not a directory
  Enotdir
  /// Operation not supported
  Enotsup
  /// No such device or address
  Enxio
  /// Directory not empty
  Enotempty
  /// Value too large to be stored in data type
  Eoverflow
  /// Not owner / Operation not permitted
  Eperm
  /// Broken pipe
  Epipe
  /// Result too large
  Erange
  /// Read-only file system
  Erofs
  /// Invalid seek
  Espipe
  /// No such process
  Esrch
  /// Stale remote file handle
  Estale
  /// Text file busy
  Etxtbsy
  /// Cross-domain link
  Exdev

  // --- fio-specific semantic errors ---
  /// File content is not valid UTF-8
  NotUtf8(path: String)
  /// Path traversal attempt blocked
  PathTraversal(path: String)
  /// Path is outside allowed base directory
  OutsideBase(path: String, base: String)
  /// Invalid path format
  InvalidPath(path: String, reason: String)
  /// Atomic operation failed
  AtomicFailed(operation: String, reason: String)
  /// Temp file/directory creation failed
  TempFailed(reason: String)
  /// Unknown / unmapped error
  Unknown(inner: String, context: Option(String))
}

/// Convert a FioError to a human-readable description.
pub fn describe(error: FioError) -> String {
  case error {
    Eacces -> "Permission denied"
    Eagain -> "Resource temporarily unavailable"
    Ebadf -> "Bad file descriptor"
    Ebadmsg -> "Bad message"
    Ebusy -> "File busy"
    Edeadlk -> "Resource deadlock avoided"
    Edquot -> "Disk quota exceeded"
    Eexist -> "File already exists"
    Efault -> "Bad address in system call argument"
    Efbig -> "File too large"
    Eintr -> "Interrupted system call"
    Einval -> "Invalid argument"
    Eio -> "I/O error"
    Eisdir -> "Illegal operation on a directory"
    Eloop -> "Too many levels of symbolic links"
    Emfile -> "Too many open files"
    Emlink -> "Too many links"
    Enametoolong -> "Filename too long"
    Enfile -> "File table overflow"
    Enodev -> "No such device"
    Enoent -> "No such file or directory"
    Enomem -> "Not enough memory"
    Enospc -> "No space left on device"
    Enosys -> "Function not implemented"
    Enotblk -> "Block device required"
    Enotdir -> "Not a directory"
    Enotsup -> "Operation not supported"
    Enxio -> "No such device or address"
    Enotempty -> "Directory not empty"
    Eoverflow -> "Value too large to be stored in data type"
    Eperm -> "Operation not permitted"
    Epipe -> "Broken pipe"
    Erange -> "Result too large"
    Erofs -> "Read-only file system"
    Espipe -> "Invalid seek"
    Esrch -> "No such process"
    Estale -> "Stale remote file handle"
    Etxtbsy -> "Text file busy"
    Exdev -> "Cross-domain link"
    NotUtf8(path) -> "File is not valid UTF-8: " <> path
    PathTraversal(path) -> "Path traversal attempt blocked: " <> path
    OutsideBase(path, base) ->
      "Path " <> path <> " is outside base directory " <> base
    InvalidPath(path, reason) -> "Invalid path " <> path <> ": " <> reason
    AtomicFailed(op, reason) -> "Atomic " <> op <> " failed: " <> reason
    TempFailed(reason) -> "Temp file operation failed: " <> reason
    Unknown(inner, context) ->
      case context {
        option.None -> "Unknown error: " <> inner
        option.Some(ctx) -> "Unknown error: " <> inner <> " (" <> ctx <> ")"
      }
  }
}
