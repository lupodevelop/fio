-module(fio_ffi_bridge).
-export([map_error/1, map_file_info/1]).

map_error(eacces) -> eacces;
map_error(eagain) -> eagain;
map_error(ebadf) -> ebadf;
map_error(ebadmsg) -> ebadmsg;
map_error(ebusy) -> ebusy;
map_error(edeadlk) -> edeadlk;
map_error(edquot) -> edquot;
map_error(eexist) -> eexist;
map_error(efault) -> efault;
map_error(efbig) -> efbig;
map_error(eintr) -> eintr;
map_error(einval) -> einval;
map_error(eio) -> eio;
map_error(eisdir) -> eisdir;
map_error(eloop) -> eloop;
map_error(emfile) -> emfile;
map_error(emlink) -> emlink;
map_error(enametoolong) -> enametoolong;
map_error(enfile) -> enfile;
map_error(enodev) -> enodev;
map_error(enoent) -> enoent;
map_error(enomem) -> enomem;
map_error(enospc) -> enospc;
map_error(enosys) -> enosys;
map_error(enotblk) -> enotblk;
map_error(enotdir) -> enotdir;
map_error(enotempty) -> enotempty;
map_error(enotsup) -> enotsup;
map_error(enxio) -> enxio;
map_error(eoverflow) -> eoverflow;
map_error(eperm) -> eperm;
map_error(epipe) -> epipe;
map_error(erange) -> erange;
map_error(erofs) -> erofs;
map_error(espipe) -> espipe;
map_error(esrch) -> esrch;
map_error(estale) -> estale;
map_error(etxtbsy) -> etxtbsy;
map_error(exdev) -> exdev;
map_error({not_utf8, Path}) -> {not_utf8, Path};
map_error({atomic_failed, Op, Reason}) -> {atomic_failed, Op, Reason};
map_error({unknown, Msg}) -> {unknown, Msg, none};
map_error(Other) when is_atom(Other) -> {unknown, atom_to_binary(Other, utf8), none};
map_error(Other) -> {unknown, list_to_binary(io_lib:format("~p", [Other])), none}.

map_file_info({Size, Mode, Nlinks, Inode, Uid, Gid, Dev, Atime, Mtime, Ctime}) ->
    {file_info, Size, Mode, Nlinks, Inode, Uid, Gid, Dev, Atime, Mtime, Ctime}.
