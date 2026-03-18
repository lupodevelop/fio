
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import * as crypto from "node:crypto";
import { Ok, Error } from "./gleam.mjs";
import { toList, BitArray } from "../prelude.mjs";
import { Some, None } from "../gleam_stdlib/gleam/option.mjs";


function mapError(error) {
  const code = error.code || error.name || "UNKNOWN";
  switch (code) {
    case "EACCES": return new Error({ type: "eacces" });
    case "EAGAIN": return new Error({ type: "eagain" });
    case "EBADF": return new Error({ type: "ebadf" });
    case "EBUSY": return new Error({ type: "ebusy" });
    case "EEXIST": return new Error({ type: "eexist" });
    case "EFAULT": return new Error({ type: "efault" });
    case "EFBIG": return new Error({ type: "efbig" });
    case "EINTR": return new Error({ type: "eintr" });
    case "EINVAL": return new Error({ type: "einval" });
    case "EIO": return new Error({ type: "eio" });
    case "EISDIR": return new Error({ type: "eisdir" });
    case "ELOOP": return new Error({ type: "eloop" });
    case "EMFILE": return new Error({ type: "emfile" });
    case "EMLINK": return new Error({ type: "emlink" });
    case "ENAMETOOLONG": return new Error({ type: "enametoolong" });
    case "ENFILE": return new Error({ type: "enfile" });
    case "ENODEV": return new Error({ type: "enodev" });
    case "ENOENT": return new Error({ type: "enoent" });
    case "ENOMEM": return new Error({ type: "enomem" });
    case "ENOSPC": return new Error({ type: "enospc" });
    case "ENOSYS": return new Error({ type: "enosys" });
    case "ENOTDIR": return new Error({ type: "enotdir" });
    case "ENOTSUP": return new Error({ type: "enotsup" });
    case "ENOTEMPTY": return new Error({ type: "enotempty" });
    case "ENXIO": return new Error({ type: "enxio" });
    case "EOVERFLOW": return new Error({ type: "eoverflow" });
    case "EPERM": return new Error({ type: "eperm" });
    case "EPIPE": return new Error({ type: "epipe" });
    case "ERANGE": return new Error({ type: "erange" });
    case "EROFS": return new Error({ type: "erofs" });
    case "ESPIPE": return new Error({ type: "espipe" });
    case "ESRCH": return new Error({ type: "esrch" });
    case "ESTALE": return new Error({ type: "estale" });
    case "ETXTBSY": return new Error({ type: "etxtbsy" });
    case "EXDEV": return new Error({ type: "exdev" });
    default: return new Error({ type: "unknown", inner: String(error.message || code) });
  }
}


export function read_file(filePath) {
  try {
    const buf = fs.readFileSync(filePath);
    try {
      const decoder = new TextDecoder("utf-8", { fatal: true });
      return new Ok(decoder.decode(buf));
    } catch (_) {
      return new Error({ type: "not_utf8", path: filePath });
    }
  } catch (error) {
    return mapError(error);
  }
}

export function read_file_bits(filePath) {
  try {
    const buf = fs.readFileSync(filePath);
    return new Ok(toBitArray(buf));
  } catch (error) {
    return mapError(error);
  }
}

export function write_file(filePath, content) {
  try {
    fs.writeFileSync(filePath, content, "utf8");
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function write_file_bits(filePath, bits) {
  try {
    fs.writeFileSync(filePath, fromBitArray(bits));
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function append_file(filePath, content) {
  try {
    fs.appendFileSync(filePath, content, "utf8");
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function append_file_bits(filePath, bits) {
  try {
    fs.appendFileSync(filePath, fromBitArray(bits));
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}


export function delete_file(filePath) {
  try {
    fs.unlinkSync(filePath);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function delete_directory(dirPath) {
  try {
    fs.rmdirSync(dirPath);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function delete_directory_recursive(dirPath) {
  try {
    fs.rmSync(dirPath, { recursive: true, force: true });
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}


export function file_exists(filePath) {
  return fs.existsSync(filePath);
}

export function file_info(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return new Ok(statToFileInfo(stat));
  } catch (error) {
    return mapError(error);
  }
}

export function link_info(filePath) {
  try {
    const stat = fs.lstatSync(filePath);
    return new Ok(statToFileInfo(stat));
  } catch (error) {
    return mapError(error);
  }
}

function statToFileInfo(stat) {
  return [
    Number(stat.size),
    stat.mode,
    stat.nlink,
    Number(stat.ino),
    stat.uid,
    stat.gid,
    stat.dev,
    Math.floor(stat.atimeMs / 1000),
    Math.floor(stat.mtimeMs / 1000),
    Math.floor(stat.ctimeMs / 1000),
  ];
}

export function is_directory(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return new Ok(stat.isDirectory());
  } catch (error) {
    return mapError(error);
  }
}

export function is_file(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return new Ok(stat.isFile());
  } catch (error) {
    return mapError(error);
  }
}

export function is_symlink(filePath) {
  try {
    const stat = fs.lstatSync(filePath);
    return new Ok(stat.isSymbolicLink());
  } catch (error) {
    return mapError(error);
  }
}


export function make_directory(dirPath) {
  try {
    fs.mkdirSync(dirPath);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function make_directory_p(dirPath) {
  try {
    fs.mkdirSync(dirPath, { recursive: true });
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function list_directory(dirPath) {
  try {
    const entries = fs.readdirSync(dirPath);
    return new Ok(toList(entries));
  } catch (error) {
    return mapError(error);
  }
}

// --- Copy & Rename ---

export function copy_file(src, dest) {
  try {
    fs.copyFileSync(src, dest);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function rename_file(src, dest) {
  try {
    fs.renameSync(src, dest);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

// --- Symlinks & Links ---

export function create_symlink(target, linkPath) {
  try {
    fs.symlinkSync(target, linkPath);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function create_hard_link(target, linkPath) {
  try {
    fs.linkSync(target, linkPath);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

// --- Permissions ---

export function set_permissions(filePath, mode) {
  try {
    fs.chmodSync(filePath, mode);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

// --- Utility ---

export function current_directory() {
  try {
    return new Ok(process.cwd());
  } catch (error) {
    return mapError(error);
  }
}

export function get_tmp_dir() {
  return os.tmpdir();
}

export function unique_name(prefix) {
  return prefix + Date.now() + Math.random().toString(36).slice(2);
}

// --- Touch & Link reading ---

export function touch(filePath) {
  try {
    try {
      const now = new Date();
      fs.utimesSync(filePath, now, now);
    } catch (e) {
      if (e.code === "ENOENT") {
        fs.writeFileSync(filePath, "");
      } else {
        throw e;
      }
    }
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function read_link(filePath) {
  try {
    const target = fs.readlinkSync(filePath);
    return new Ok(target);
  } catch (error) {
    return mapError(error);
  }
}

export function checksum(filePath, algo) {
  try {
    const hash = crypto.createHash(algo);
    const buf = fs.readFileSync(filePath);
    hash.update(buf);
    return new Ok(hash.digest("hex"));
  } catch (error) {
    return mapError(error);
  }
}

// --- Atomic Write ---

// Writes `content` to a sibling temp file in the same directory, then
// calls fs.renameSync which is atomic on POSIX (same mount point).
// If anything fails the temp file is cleaned up before returning Error.
export function write_file_atomic(filePath, content) {
  const dir = path.dirname(filePath);
  const tmpPath = path.join(
    dir,
    `.__fio_tmp_${Date.now()}_${Math.random().toString(36).slice(2)}`
  );
  try {
    fs.writeFileSync(tmpPath, content, "utf8");
    try {
      fs.renameSync(tmpPath, filePath);
      return new Ok(undefined);
    } catch (renameErr) {
      try { fs.unlinkSync(tmpPath); } catch (_) { }
      return new Error({
        type: "atomic_failed",
        operation: "rename",
        reason: String(renameErr.message),
      });
    }
  } catch (writeErr) {
    return new Error({
      type: "atomic_failed",
      operation: "write_temp",
      reason: String(writeErr.message),
    });
  }
}

export function write_file_bits_atomic(filePath, bits) {
  const dir = path.dirname(filePath);
  const tmpPath = path.join(
    dir,
    `.__fio_tmp_${Date.now()}_${Math.random().toString(36).slice(2)}`
  );
  try {
    fs.writeFileSync(tmpPath, fromBitArray(bits));
    try {
      fs.renameSync(tmpPath, filePath);
      return new Ok(undefined);
    } catch (renameErr) {
      try { fs.unlinkSync(tmpPath); } catch (_) { }
      return new Error({
        type: "atomic_failed",
        operation: "rename",
        reason: String(renameErr.message),
      });
    }
  } catch (writeErr) {
    return new Error({
      type: "atomic_failed",
      operation: "write_temp",
      reason: String(writeErr.message),
    });
  }
}

// --- File Handles ---
//
// The JS handle is { fd, pos, isAppend } so we can:
//   - Track the cursor position explicitly for seek/tell/explicit reads.
//   - Detect append mode so writes use `null` (OS-forced EOF) rather than
//     an explicit position. Node.js ignores the 'a' flag when a numeric
//     position is passed to writeSync, so we must guard against that.
//
// read_chunk returns Ok(Some(BitArray)) for a chunk, Ok(None) on EOF.

export function open_handle(filePath, mode) {
  try {
    const fd = fs.openSync(filePath, mode);
    const isAppend = mode === "a";
    // For append mode seed `pos` at the current EOF so tell() is meaningful.
    let pos = 0;
    if (isAppend) {
      try { pos = fs.fstatSync(fd).size; } catch (_) { }
    }
    return new Ok({ fd, pos, isAppend });
  } catch (error) {
    return mapError(error);
  }
}

export function close_handle(handle) {
  try {
    fs.closeSync(handle.fd);
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function read_chunk(handle, size) {
  try {
    const buf = Buffer.alloc(size);
    const bytesRead = fs.readSync(handle.fd, buf, 0, size, handle.pos);
    if (bytesRead === 0) {
      return new Ok(new None());
    }
    handle.pos += bytesRead;
    return new Ok(new Some(toBitArray(buf.slice(0, bytesRead))));
  } catch (error) {
    return mapError(error);
  }
}

export function write_handle(handle, content) {
  try {
    // In append mode always use null so the OS forces writes to EOF,
    // regardless of our tracked `pos`. Explicit position ignores 'a' flag.
    const position = handle.isAppend ? null : handle.pos;
    const bytesWritten = fs.writeSync(handle.fd, content, position, "utf8");
    handle.pos += bytesWritten;
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function write_handle_bits(handle, bits) {
  try {
    const buf = fromBitArray(bits);
    const position = handle.isAppend ? null : handle.pos;
    const bytesWritten = fs.writeSync(handle.fd, buf, 0, buf.length, position);
    handle.pos += bytesWritten;
    return new Ok(undefined);
  } catch (error) {
    return mapError(error);
  }
}

export function seek_handle(handle, position) {
  // No OS call needed: update our tracked position.
  // In append mode seek affects read_chunk but writes still go to EOF.
  handle.pos = position;
  return new Ok(undefined);
}

export function tell_handle(handle) {
  return new Ok(handle.pos);
}

// --- Bitwise helpers ---

export function bitwise_and(a, b) {
  return a & b;
}

export function bitwise_shift_right(a, b) {
  return a >> b;
}

export function bitwise_shift_left(a, b) {
  return a << b;
}

// --- BitArray helpers ---

function toBitArray(buffer) {
  return new BitArray(new Uint8Array(buffer));
}

function fromBitArray(bitArray) {
  // Optimization: if the bit array is byte-aligned (offset 0 and integral bytes),
  // we can use the raw buffer directly. Buffer.from(Uint8Array) in Node.js is 
  // highly optimized.
  if (bitArray.bitOffset === 0 && bitArray.bitSize % 8 === 0) {
    return Buffer.from(bitArray.rawBuffer);
  }

  // Fallback for unaligned bit arrays: we must copy and shift bits.
  const buf = new Uint8Array(bitArray.byteSize);
  for (let i = 0; i < bitArray.byteSize; i++) {
    buf[i] = bitArray.byteAt(i);
  }
  return Buffer.from(buf);
}
