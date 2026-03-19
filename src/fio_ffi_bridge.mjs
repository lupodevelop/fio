// Bridge: maps raw FFI errors/types to Gleam constructors
import {
  Eacces, Eagain, Ebadf, Ebadmsg, Ebusy, Edeadlk, Edquot, Eexist,
  Efault, Efbig, Eintr, Einval, Eio, Eisdir, Eloop, Emfile, Emlink,
  Enametoolong, Enfile, Enodev, Enoent, Enomem, Enospc, Enosys,
  Enotblk, Enotdir, Enotempty, Enotsup, Enxio, Eoverflow, Eperm, Epipe, Erange,
  Erofs, Espipe, Esrch, Estale, Etxtbsy, Exdev, NotUtf8, AtomicFailed, Unknown,
} from "./fio/error.mjs";
import { FileInfo } from "./fio/types.mjs";
import { None } from "../gleam_stdlib/gleam/option.mjs";

const ERROR_MAP = {
  eacces: () => new Eacces(),
  eagain: () => new Eagain(),
  ebadf: () => new Ebadf(),
  ebadmsg: () => new Ebadmsg(),
  ebusy: () => new Ebusy(),
  edeadlk: () => new Edeadlk(),
  edquot: () => new Edquot(),
  eexist: () => new Eexist(),
  efault: () => new Efault(),
  efbig: () => new Efbig(),
  eintr: () => new Eintr(),
  einval: () => new Einval(),
  eio: () => new Eio(),
  eisdir: () => new Eisdir(),
  eloop: () => new Eloop(),
  emfile: () => new Emfile(),
  emlink: () => new Emlink(),
  enametoolong: () => new Enametoolong(),
  enfile: () => new Enfile(),
  enodev: () => new Enodev(),
  enoent: () => new Enoent(),
  enomem: () => new Enomem(),
  enospc: () => new Enospc(),
  enosys: () => new Enosys(),
  enotblk: () => new Enotblk(),
  enotdir: () => new Enotdir(),
  enotempty: () => new Enotempty(),
  enotsup: () => new Enotsup(),
  enxio: () => new Enxio(),
  eoverflow: () => new Eoverflow(),
  eperm: () => new Eperm(),
  epipe: () => new Epipe(),
  erange: () => new Erange(),
  erofs: () => new Erofs(),
  espipe: () => new Espipe(),
  esrch: () => new Esrch(),
  estale: () => new Estale(),
  etxtbsy: () => new Etxtbsy(),
  exdev: () => new Exdev(),
};

export function map_error(err) {
  // JS FFI returns { type: "enoent" } style objects
  if (err && typeof err === "object" && err.type) {
    if (err.type === "not_utf8") {
      return new NotUtf8(err.path || "");
    }
    if (err.type === "atomic_failed") {
      return new AtomicFailed(err.operation || "", err.reason || "");
    }
    if (err.type === "unknown") {
      return new Unknown(err.inner || "", new None());
    }
    const factory = ERROR_MAP[err.type];
    if (factory) return factory();
    return new Unknown(String(err.type), new None());
  }
  return new Unknown(String(err), new None());
}

export function map_file_info(raw) {
  // raw is an array: [size, mode, nlinks, inode, uid, gid, dev, atime, mtime, ctime]
  return new FileInfo(
    raw[0], raw[1], raw[2], raw[3], raw[4],
    raw[5], raw[6], raw[7], raw[8], raw[9]
  );
}
