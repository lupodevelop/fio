/// Observability primitives for fio operations.
///
/// The design is intentionally open: a `Sink` is just a function
/// `fn(Event) -> Nil`, so any package can implement its own sink
/// (structured logger, metrics counter, OpenTelemetry span, test recorder, …)
/// without depending on fio internals.
///
/// ## How it works
///
/// Call `emit` (or the convenience wrapper `trace`) at the end of any fio
/// operation. The result is returned unchanged — the call is fully transparent
/// in a pipeline.
///
/// ```gleam
/// import fio
/// import fio/observer.{type Event, type Sink}
///
/// fn my_sink(event: Event) -> Nil {
///   io.println(observer.format(event))
/// }
///
/// pub fn main() {
///   fio.write("hello.txt", "world")
///   |> observer.trace("write", "hello.txt", my_sink)
/// }
/// ```
///
/// ## Extending with bytes
///
/// Use `emit` directly when you know the byte count:
///
/// ```gleam
/// fio.read_bits("data.bin")
/// |> observer.emit("read_bits", "data.bin", option.Some(expected_size), my_sink)
/// ```
///
/// ## Writing a reusable sink
///
/// Because `Sink` is just `fn(Event) -> Nil`, you can build sinks as closures
/// that capture external state (a logger handle, a metrics counter, etc.):
///
/// ```gleam
/// pub fn make_prefix_sink(prefix: String) -> observer.Sink {
///   fn(event: observer.Event) {
///     io.println(prefix <> observer.format(event))
///   }
/// }
/// ```
import fio/error.{type FioError}
import gleam/bit_array
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A single fio operation event emitted to a sink.
pub type Event {
  Event(
    /// Short operation name: "read", "write", "copy", "delete", etc.
    op: String,
    /// Primary path argument of the operation.
    path: String,
    /// `Ok(Nil)` on success, `Error(e)` on failure.
    /// The actual return value (file content, etc.) is excluded to keep the
    /// event type generic and independent of the operation's return type.
    outcome: Result(Nil, FioError),
    /// Byte count involved, when known.
    /// For read operations: bytes returned.
    /// For write operations: bytes written.
    /// `None` when not applicable (e.g. delete, rename).
    bytes: Option(Int),
  )
}

/// A sink consumes events produced by observed fio operations.
///
/// Implement this type to integrate with any observability backend:
/// structured loggers, metrics systems, test recorders, or custom hooks.
/// A sink receives events synchronously on the same thread/process as the caller.
pub type Sink =
  fn(Event) -> Nil

// ---------------------------------------------------------------------------
// Core primitive
// ---------------------------------------------------------------------------

/// Emit an `Event` to `sink` after `result` is produced, then return `result`
/// unchanged.
///
/// This is the lowest-level building block. Use `trace` when you do not have
/// a byte count to report.
///
/// ```gleam
/// fio.read_bits("data.bin")
/// |> observer.emit("read_bits", "data.bin", option.None, my_sink)
/// ```
pub fn emit(
  result: Result(a, FioError),
  op: String,
  path: String,
  bytes: Option(Int),
  sink: Sink,
) -> Result(a, FioError) {
  let outcome = result.map(result, fn(_) { Nil })
  sink(Event(op:, path:, outcome:, bytes:))
  result
}

// ---------------------------------------------------------------------------
// Convenience wrappers
// ---------------------------------------------------------------------------

/// Like `emit` but without a byte count (`bytes` is always `None`).
///
/// Use this for operations where byte count is not meaningful (delete, rename,
/// touch, create_directory, etc.):
///
/// ```gleam
/// fio.delete("old.txt")
/// |> observer.trace("delete", "old.txt", my_sink)
/// ```
pub fn trace(
  result: Result(a, FioError),
  op: String,
  path: String,
  sink: Sink,
) -> Result(a, FioError) {
  emit(result, op, path, None, sink)
}

/// Like `trace` but automatically infers the byte count from the result when
/// the operation returns a `BitArray` (e.g. `fio.read_bits`).
///
/// ```gleam
/// fio.read_bits("archive.tar.gz")
/// |> observer.trace_bytes("read_bits", "archive.tar.gz", my_sink)
/// ```
pub fn trace_bytes(
  result: Result(BitArray, FioError),
  op: String,
  path: String,
  sink: Sink,
) -> Result(BitArray, FioError) {
  let bytes = case result {
    Ok(data) -> Some(bit_array.byte_size(data))
    Error(_) -> None
  }
  emit(result, op, path, bytes, sink)
}

// ---------------------------------------------------------------------------
// Sink utilities
// ---------------------------------------------------------------------------

/// Format an `Event` as a human-readable string.
/// Useful when building simple logging sinks.
///
/// ```gleam
/// fn log_sink(event: Event) -> Nil {
///   io.println(observer.format(event))
/// }
/// ```
pub fn format(event: Event) -> String {
  let status = case event.outcome {
    Ok(_) -> "ok"
    Error(e) -> "err(" <> error.describe(e) <> ")"
  }
  let bytes_str = case event.bytes {
    None -> ""
    Some(n) -> " bytes=" <> int.to_string(n)
  }
  "[fio] " <> event.op <> " " <> event.path <> " -> " <> status <> bytes_str
}

/// Combine two sinks into one: both receive every event in order.
///
/// Useful for fan-out — log to stdout AND record in a test buffer:
///
/// ```gleam
/// let combined = observer.fan_out(log_sink, test_recorder_sink)
/// fio.write("out.txt", data) |> observer.trace("write", "out.txt", combined)
/// ```
pub fn fan_out(first: Sink, second: Sink) -> Sink {
  fn(event: Event) {
    first(event)
    second(event)
  }
}

/// A no-op sink that discards all events.
/// Useful as a default/placeholder argument when observability is optional.
///
/// ```gleam
/// pub fn copy(src, dest, sink: observer.Sink) {
///   fio.copy(src, dest) |> observer.trace("copy", src, sink)
/// }
/// // caller passes observer.noop_sink when not interested
/// copy("a.txt", "b.txt", observer.noop_sink)
/// ```
pub fn noop_sink(_event: Event) -> Nil {
  Nil
}
