-module(fio_ffi).
-export([
    read_file/1,
    read_file_bits/1,
    write_file/2,
    write_file_bits/2,
    append_file/2,
    append_file_bits/2,
    delete_file/1,
    delete_directory/1,
    delete_directory_recursive/1,
    file_exists/1,
    file_info/1,
    link_info/1,
    is_directory/1,
    is_file/1,
    is_symlink/1,
    make_directory/1,
    make_directory_p/1,
    list_directory/1,
    copy_file/2,
    rename_file/2,
    create_symlink/2,
    create_hard_link/2,
    set_permissions/2,
    current_directory/0,
    get_tmp_dir/0,
    touch/1,
    read_link/1,
    checksum/2,
    write_file_atomic/2,
    write_file_bits_atomic/2,
    open_handle/2,
    close_handle/1,
    read_chunk/2,
    write_handle/2,
    write_handle_bits/2,
    seek_handle/2,
    tell_handle/1,
    unique_name/1
]).

%% --- Error mapping ---

map_error(Reason) ->
    case Reason of
        eacces -> {error, eacces};
        eagain -> {error, eagain};
        ebadf -> {error, ebadf};
        ebadmsg -> {error, ebadmsg};
        ebusy -> {error, ebusy};
        edeadlk -> {error, edeadlk};
        edquot -> {error, edquot};
        eexist -> {error, eexist};
        efault -> {error, efault};
        efbig -> {error, efbig};
        eintr -> {error, eintr};
        einval -> {error, einval};
        eio -> {error, eio};
        eisdir -> {error, eisdir};
        eloop -> {error, eloop};
        emfile -> {error, emfile};
        emlink -> {error, emlink};
        enametoolong -> {error, enametoolong};
        enfile -> {error, enfile};
        enodev -> {error, enodev};
        enoent -> {error, enoent};
        enomem -> {error, enomem};
        enospc -> {error, enospc};
        enosys -> {error, enosys};
        enotblk -> {error, enotblk};
        enotdir -> {error, enotdir};
        enotsup -> {error, enotsup};
        enxio -> {error, enxio};
        eoverflow -> {error, eoverflow};
        eperm -> {error, eperm};
        epipe -> {error, epipe};
        erange -> {error, erange};
        erofs -> {error, erofs};
        espipe -> {error, espipe};
        esrch -> {error, esrch};
        estale -> {error, estale};
        etxtbsy -> {error, etxtbsy};
        exdev -> {error, exdev};
        Other when is_atom(Other) -> {error, {unknown, atom_to_binary(Other, utf8)}};
        Other -> {error, {unknown, list_to_binary(io_lib:format("~p", [Other]))}}
    end.

%% --- File I/O ---

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Bin} ->
            case unicode:characters_to_binary(Bin) of
                {error, _, _} -> {error, {not_utf8, Path}};
                {incomplete, _, _} -> {error, {not_utf8, Path}};
                Str when is_binary(Str) -> {ok, Str}
            end;
        {error, Reason} -> map_error(Reason)
    end.

read_file_bits(Path) ->
    case file:read_file(Path) of
        {ok, Bin} -> {ok, Bin};
        {error, Reason} -> map_error(Reason)
    end.

write_file(Path, Content) ->
    case file:write_file(Path, Content) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

write_file_bits(Path, Content) ->
    case file:write_file(Path, Content) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

%% Atomic write: write to a sibling temp file, then rename(2).
%% The temp lives in the same directory (same fs mount) so rename(2)
%% is guaranteed to be atomic on POSIX. The unique suffix prevents
%% collisions under concurrent writers.
write_file_atomic(Path, Content) ->
    Dir = filename:dirname(Path),
    Unique = integer_to_binary(erlang:unique_integer([positive, monotonic])),
    TmpPath = filename:join(Dir, <<".__fio_tmp_", Unique/binary>>),
    case file:write_file(TmpPath, Content) of
        ok ->
            case file:rename(TmpPath, Path) of
                ok ->
                    {ok, nil};
                {error, Reason} ->
                    _ = file:delete(TmpPath), % Best-effort cleanup upon rename failure
                    {error, {atomic_failed, <<"rename">>, atom_to_binary(Reason, utf8)}}
            end;
        {error, Reason} ->
            {error, {atomic_failed, <<"write_temp">>, atom_to_binary(Reason, utf8)}}
    end.

write_file_bits_atomic(Path, Content) ->
    write_file_atomic(Path, Content).

append_file(Path, Content) ->
    case file:write_file(Path, Content, [append]) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

append_file_bits(Path, Content) ->
    case file:write_file(Path, Content, [append]) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

%% --- Delete ---

delete_file(Path) ->
    case file:delete(Path) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

delete_directory(Path) ->
    case file:del_dir(Path) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

delete_directory_recursive(Path) ->
    %% Do not follow symlinks: if Path is a symlink, remove it rather than
    %% recursing into its target (prevents accidental deletion outside root).
    case file:read_link_info(Path, [{time, posix}]) of
        {ok, {file_info, _, symlink, _, _, _, _, _, _, _, _, _, _, _}} ->
            delete_file(Path);
        {ok, {file_info, _, directory, _, _, _, _, _, _, _, _, _, _, _}} ->
            case file:list_dir(Path) of
                {ok, Entries} ->
                    Results = lists:map(fun(Entry) ->
                        FullPath = filename:join(Path, Entry),
                        delete_directory_recursive(FullPath)
                    end, Entries),
                    case lists:filter(fun({error, _}) -> true; (_) -> false end, Results) of
                        [] -> delete_directory(Path);
                        [FirstError | _] -> FirstError
                    end;
                {error, Reason} -> map_error(Reason)
            end;
        {ok, _} ->
            %% Not a directory (regular file, device, etc.)
            delete_file(Path);
        {error, enoent} ->
            {ok, nil};
        {error, Reason} ->
            map_error(Reason)
    end.

%% --- File info ---

file_exists(Path) ->
    case file:read_file_info(Path) of
        {ok, _} -> true;
        {error, enoent} -> false;
        _ -> false
    end.

file_info(Path) ->
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, {file_info, Size, _Type, _Access, Atime, Mtime, Ctime,
                         Mode, Nlinks, MajDev, MinDev, Inode, Uid, Gid}} ->
            Dev = (MajDev bsl 16) bor MinDev,
            {ok, {Size, Mode, Nlinks, Inode, Uid, Gid, Dev, Atime, Mtime, Ctime}};
        {error, Reason} -> map_error(Reason)
    end.

link_info(Path) ->
    case file:read_link_info(Path, [{time, posix}]) of
        {ok, {file_info, Size, _Type, _Access, Atime, Mtime, Ctime,
                         Mode, Nlinks, MajDev, MinDev, Inode, Uid, Gid}} ->
            Dev = (MajDev bsl 16) bor MinDev,
            {ok, {Size, Mode, Nlinks, Inode, Uid, Gid, Dev, Atime, Mtime, Ctime}};
        {error, Reason} -> map_error(Reason)
    end.

is_directory(Path) ->
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, {file_info, _, directory, _, _, _, _, _, _, _, _, _, _, _}} -> {ok, true};
        {ok, _} -> {ok, false};
        {error, Reason} -> map_error(Reason)
    end.

is_file(Path) ->
    case file:read_file_info(Path, [{time, posix}]) of
        {ok, {file_info, _, regular, _, _, _, _, _, _, _, _, _, _, _}} -> {ok, true};
        {ok, _} -> {ok, false};
        {error, Reason} -> map_error(Reason)
    end.

is_symlink(Path) ->
    case file:read_link_info(Path, [{time, posix}]) of
        {ok, {file_info, _, symlink, _, _, _, _, _, _, _, _, _, _, _}} -> {ok, true};
        {ok, _} -> {ok, false};
        {error, Reason} -> map_error(Reason)
    end.

%% --- Directory operations ---

make_directory(Path) ->
    case file:make_dir(Path) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

make_directory_p(Path) ->
    case filelib:ensure_dir(filename:join(Path, "dummy")) of
        ok ->
            case file:make_dir(Path) of
                ok -> {ok, nil};
                {error, eexist} -> {ok, nil};
                {error, Reason} -> map_error(Reason)
            end;
        {error, Reason} -> map_error(Reason)
    end.

list_directory(Path) ->
    case file:list_dir(Path) of
        {ok, Entries} ->
            {ok, lists:map(fun(E) -> unicode:characters_to_binary(E) end, Entries)};
        {error, Reason} -> map_error(Reason)
    end.

%% --- Copy & Rename ---

copy_file(Src, Dest) ->
    case file:copy(Src, Dest) of
        {ok, _BytesCopied} -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

rename_file(Src, Dest) ->
    case file:rename(Src, Dest) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

%% --- Symlinks & Links ---

create_symlink(Target, Link) ->
    case file:make_symlink(Target, Link) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

create_hard_link(Target, Link) ->
    case file:make_link(Target, Link) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

%% --- Permissions ---

set_permissions(Path, Mode) ->
    case file:change_mode(Path, Mode) of
        ok -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

%% --- Utility ---

current_directory() ->
    case file:get_cwd() of
        {ok, Cwd} -> {ok, unicode:characters_to_binary(Cwd)};
        {error, Reason} -> map_error(Reason)
    end.

get_tmp_dir() ->
    Dir = case os:getenv("TMPDIR") of
        false ->
            case os:getenv("TEMP") of
                false ->
                    case os:getenv("TMP") of
                        false -> "/tmp";
                        Val -> Val
                    end;
                Val -> Val
            end;
        Val -> Val
    end,
    unicode:characters_to_binary(Dir).

unique_name(Prefix) ->
    Unique = integer_to_binary(erlang:unique_integer([positive, monotonic])),
    <<Prefix/binary, Unique/binary>>.

%% --- Touch & Link reading ---

touch(Path) ->
    case file:read_file_info(Path) of
        {ok, _} ->
            Now = calendar:local_time(),
            case file:change_time(Path, Now) of
                ok -> {ok, nil};
                {error, Reason} -> map_error(Reason)
            end;
        {error, enoent} ->
            case file:write_file(Path, <<>>) of
                ok -> {ok, nil};
                {error, Reason} -> map_error(Reason)
            end;
        {error, Reason} -> map_error(Reason)
    end.

read_link(Path) ->
    case file:read_link(Path) of
        {ok, Target} -> {ok, unicode:characters_to_binary(Target)};
        {error, Reason} -> map_error(Reason)
    end.

checksum(Path, Algo) ->
    case file:read_file(Path) of
        {ok, Bin} ->
            AlgoAtom = hash_algorithm(Algo),
            Hash = crypto:hash(AlgoAtom, Bin),
            {ok, bin_to_hex(Hash)};
        {error, Reason} -> map_error(Reason)
    end.

hash_algorithm(<<"sha256">>) -> sha256;
hash_algorithm(<<"sha512">>) -> sha512;
hash_algorithm(<<"md5">>)    -> md5;
hash_algorithm(_)            -> erlang:error(badarg).

bin_to_hex(Bin) ->
    list_to_binary([io_lib:format("~2.16.0b", [X]) || X <- binary_to_list(Bin)]).

%% --- File Handles ---
%%
%% open_handle returns the IoDevice pid returned by file:open/2.
%% It is carried as an opaque term through Gleam's RawHandle type.
%%
%% read_chunk returns {ok, {some, Data}} for a chunk or {ok, none} at EOF.
%% Gleam represents Some(x) as {some, x} and None as `none`.

open_handle(Path, Mode) ->
    Flags = case Mode of
        <<"r">> -> [read, binary];
        <<"w">> -> [write, binary];
        <<"a">> -> [append, binary];
        _       -> [read, binary]
    end,
    case file:open(Path, Flags) of
        {ok, Fd}        -> {ok, Fd};
        {error, Reason} -> map_error(Reason)
    end.

close_handle(Fd) ->
    case file:close(Fd) of
        ok              -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

read_chunk(Fd, Size) ->
    case file:read(Fd, Size) of
        {ok, Data}      -> {ok, {some, Data}};
        eof             -> {ok, none};
        {error, Reason} -> map_error(Reason)
    end.

write_handle(Fd, Content) ->
    case file:write(Fd, Content) of
        ok              -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

write_handle_bits(Fd, Content) ->
    case file:write(Fd, Content) of
        ok              -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

%% Move the file cursor to an absolute byte offset from the start of the file.
%% Uses file:position/2 which maps directly to lseek(2) on POSIX systems.
seek_handle(Fd, Position) ->
    case file:position(Fd, {bof, Position}) of
        {ok, _NewPos}   -> {ok, nil};
        {error, Reason} -> map_error(Reason)
    end.

%% Return the current byte offset of the file cursor.
tell_handle(Fd) ->
    case file:position(Fd, cur) of
        {ok, Pos}       -> {ok, Pos};
        {error, Reason} -> map_error(Reason)
    end.
