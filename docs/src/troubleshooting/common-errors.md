# Common Errors and Solutions

This section lists frequent errors you may encounter and how to fix them, grounded in the current driver behavior (ocaml/src).

Authentication failed
- Symptom: `Error.Auth "Authentication error: ..."` or server failure on HELLO.
- Fix: Verify `NEO4J_USER`/`NEO4J_PASSWORD` and that Neo4j is running. Check `Config.of_env ()` values.

Handshake/version negotiation
- Symptom: `Error.Protocol "Server returned version 0"` or unexpected handshake response.
- Fix: Ensure you are connecting to a Bolt port (default 7687) and Neo4j is up. Driver proposes [5,4,3,2].

RUN was ignored — session in failed state
- Symptom: `Error.Protocol "RUN was ignored - session in failed state"` after a prior failure.
- Fix: Call `Session.reset` (auto‑issued by the driver outside transactions). Inside a transaction, `rollback` to clear failed state.

Server failures (Cypher errors)
- Symptom: `Error.Database/Transient/ClientError { code; message }`.
- Fix: Inspect `code`/`message`. Correct query syntax or data shape. Retry `Transient` errors when safe.

Decode/type errors (client‑side)
- Symptom: `Record.at_*` returns `Error decode_error` (e.g., `NotText`, `KeyNotFound`), or `Extract` fails with `Client.ExtractionError`.
- Fix: Alias fields (`AS name`), ensure key names match, and decode with the appropriate `Record.at_*` function.

Session is closed
- Symptom: `Error.Protocol "Session is closed"` when reusing a closed handle.
- Fix: Scope work within `Session.with_session`. Do not reuse a session after the function returns.

Materialized result too large / memory pressure
- Symptom: high memory usage or slowdowns.
- Fix: Use `Session.run_stream(_records)` with `~fetch_size`, and process chunks incrementally.

Connection refused / cannot connect
- Symptom: I/O error; cannot reach Neo4j.
- Fix: Ensure Docker/DB is running and port exposed. Current session path connects to loopback (127.0.0.1) — run locally or tunnel as needed.
