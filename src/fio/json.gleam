/// Convenience helpers for reading and writing JSON files.
///
/// This module does not include a JSON parser or encoder — encoding and
/// decoding are the caller's responsibility (use `gleam_json` or any other
/// library). What this module provides is ergonomic I/O wrappers that compose
/// cleanly with decoder/encoder functions.
///
/// ## Example
///
/// ```gleam
/// import fio/json as fjson
/// import gleam_json
///
/// // Read and decode
/// let result = fjson.read_json("config.json", gleam_json.decode_string)
///
/// // Encode and write atomically
/// let assert Ok(_) = fjson.write_json_atomic("config.json", my_value, encode_fn)
/// ```
import fio
import fio/error.{type FioError}

// ---------------------------------------------------------------------------
// Error type
// ---------------------------------------------------------------------------

/// Error returned by `read_json` when either the file I/O fails or the
/// caller-supplied decoder rejects the content.
pub type JsonError(decode_err) {
  /// The file could not be read (e.g. missing, permission denied).
  IoError(error: FioError)
  /// The file was read successfully but the decoder rejected the content.
  ParseError(error: decode_err)
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

/// Read a file and decode its content with `decoder`.
///
/// Returns `Error(IoError(_))` on I/O failure and
/// `Error(ParseError(_))` when the decoder rejects the content.
///
/// ```gleam
/// fjson.read_json("settings.json", my_decoder)
/// // Ok(settings) | Error(IoError(Enoent)) | Error(ParseError(...))
/// ```
pub fn read_json(
  path: String,
  decoder: fn(String) -> Result(a, e),
) -> Result(a, JsonError(e)) {
  case fio.read(path) {
    Error(e) -> Error(IoError(e))
    Ok(content) ->
      case decoder(content) {
        Error(e) -> Error(ParseError(e))
        Ok(value) -> Ok(value)
      }
  }
}

/// Encode `value` with `encoder` and write the result atomically to `path`.
///
/// Uses `fio.write_atomic` under the hood, so readers never observe
/// partial content.
///
/// ```gleam
/// fjson.write_json_atomic("settings.json", settings, my_encoder)
/// ```
pub fn write_json_atomic(
  path: String,
  value: a,
  encoder: fn(a) -> String,
) -> Result(Nil, FioError) {
  fio.write_atomic(path, encoder(value))
}
