(** {1 Error Handling}

    This module defines the unified error type used throughout the Neo4j driver.
    All fallible operations return [(result_type, Error.t) result] rather than
    raising exceptions, making error handling explicit and predictable.

    {2 Error Philosophy}

    The driver follows these principles:
    - No exceptions for normal error conditions
    - Explicit error types for pattern matching
    - Preserve server error codes and messages
    - Distinguish transient (retryable) from permanent errors
*)

(** Unified error type for all driver operations.

    All driver functions return [('a, t) result] for recoverable errors.
    Exceptions are reserved for truly exceptional conditions (bugs, resource
    exhaustion, etc.).

    {2 Error Categories}

    Errors are categorized by origin and severity:
    - {b I/O errors}: Network and connection failures
    - {b Protocol errors}: Bolt protocol violations
    - {b Auth errors}: Authentication and authorization failures
    - {b Database errors}: Server-side query/constraint failures (permanent)
    - {b Transient errors}: Temporary server issues (retryable)
    - {b Client errors}: Driver misuse or decoding failures
*)
type t =
  | Io of string
    (** Local I/O error during connection or communication.

        Examples: Connection refused, connection reset, socket timeout.
        These typically indicate network issues or that the server is unavailable. *)

  | Protocol of string
    (** Bolt protocol framing or decoding error.

        Examples: Invalid handshake, malformed PackStream, unexpected message type.
        These indicate protocol version mismatch or implementation bugs. *)

  | Auth of string
    (** Authentication or authorization failure.

        Examples: Invalid credentials, insufficient permissions, expired token.
        Retry with corrected credentials may succeed. *)

  | Database of { code: string; message: string }
    (** Server-side database error (permanent failure).

        Examples: Syntax error in Cypher query, constraint violation, type mismatch.
        The [code] field contains the Neo4j error code (e.g., ["Neo.ClientError.Statement.SyntaxError"]).
        These errors will not succeed if retried without changing the query or data. *)

  | Transient of { code: string; message: string }
    (** Retryable server-side error.

        Examples: Deadlock, transient lock failure, leader change in cluster.
        The [code] field contains the Neo4j error code (e.g., ["Neo.TransientError.Transaction.DeadlockDetected"]).
        These may succeed if retried after a brief delay. *)

  | ClientError of { code: string; message: string }
    (** Client-side error from driver misuse or decoding failure.

        Examples: Record field not found, type mismatch when decoding, invalid parameter.
        The [code] field is typically driver-generated or from server client error responses.
        Fix the client code to resolve these errors. *)

(** Convert an error to a human-readable string.

    Formats the error for display to users or in logs. Includes error codes
    and messages for server-originated errors.

    {2 Example}

    {[
      match Session.run_records session ~statement:"MATCH (n) RETURN n" () with
      | Ok records -> process_records records
      | Error e ->
          Printf.eprintf "Query failed: %s\\n" (Error.to_string e)
    ]}

    @return String representation suitable for logging or display
    @since 0.1.0
*)
val to_string : t -> string

(** Parse a server FAILURE message into a typed error.

    The Bolt protocol sends errors as FAILURE messages containing metadata maps
    with [code] and [message] fields. This function classifies the error based
    on the Neo4j error code prefix:
    - [Neo.ClientError.*] → {!ClientError}
    - [Neo.TransientError.*] → {!Transient}
    - [Neo.DatabaseError.*] → {!Database}
    - Others → {!Database} by default

    This is primarily used internally by the driver when receiving FAILURE responses.

    @param failure_map Metadata map from a Bolt FAILURE message
    @return Classified error with code and message extracted
    @since 0.1.0
*)
val from_failure_map : Value.value Value.StringMap.t -> t
