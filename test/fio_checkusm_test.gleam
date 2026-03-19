import fio
import fio/error
import fio/types
import gleeunit/should

pub fn with_temp_file_test() {
  let content = "temp file content"
  use path <- fio.with_temp_file()

  // File should not exist initially
  fio.exists(path) |> should.be_false

  // Write and read
  fio.write(path, content) |> should.be_ok
  fio.read(path) |> should.equal(Ok(content))

  // After the block, the file should be deleted (handled by with_temp_file)
  Ok(Nil)
}

pub fn with_temp_directory_test() {
  use path <- fio.with_temp_directory()

  // Directory should exist (created by with_temp_directory)
  fio.is_directory(path) |> should.equal(Ok(True))

  let file_path = path <> "/test.txt"
  fio.write(file_path, "hello") |> should.be_ok

  // After the block, directory and its contents should be gone
  Ok(Nil)
}

pub fn checksum_test() {
  use path <- fio.with_temp_file()
  let content = "gleam is awesome"
  fio.write(path, content) |> should.be_ok

  // Test SHA-256
  let assert Ok(sha1) = fio.checksum(path, types.Sha256)
  sha1 |> should.not_equal("")
  fio.verify_checksum(path, sha1, types.Sha256) |> should.equal(Ok(True))

  // Test MD5
  let assert Ok(md5) = fio.checksum(path, types.Md5)
  md5 |> should.not_equal("")
  fio.verify_checksum(path, md5, types.Md5) |> should.equal(Ok(True))

  // Test Sha512
  let assert Ok(sha512) = fio.checksum(path, types.Sha512)
  sha512 |> should.not_equal("")
  fio.verify_checksum(path, sha512, types.Sha512) |> should.equal(Ok(True))

  Ok(Nil)
}

pub fn checksum_not_found_test() {
  fio.checksum("non_existent_file.txt", types.Sha256)
  |> should.equal(Error(error.Enoent))
}
