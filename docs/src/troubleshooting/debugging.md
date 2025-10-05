# Debugging Guide

This guide provides practical tips for debugging applications using neo4j_eio, aligned with the current API and behavior.

Verify connectivity first
- Use a minimal program with `Session.with_session ~sw ~net (Config.of_env ()) (fun s -> ...)` and `RETURN 1 AS ok`.
- Ensure environment variables are set (`NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD`).

Reduce and isolate queries
- Reproduce issues with small, self‑contained Cypher. Alias fields (`AS name`) to avoid key mismatches.
- Scope data with randomized labels (e.g., `Label_%d`) and clean up using `DETACH DELETE`.

Inspect errors
- Print `Error.to_string e` and, when relevant, log `code` and `message` (Database/Transient/ClientError).
- For decode issues, pretty‑print `Record.pp_decode_error`.

Reset failed sessions
- After a Cypher failure outside a transaction, the driver auto‑issues `RESET`. Inside a transaction, call `rollback` to clear failed state.

Stream large results
- Prefer `Session.run_stream(_records)` + `~fetch_size` for large result sets; process per chunk to pinpoint problematic rows.

Decode early and explicitly
- Use `Record.at_*` or `Extract` to fail fast on type mismatches. Keep decoders local to the query.

Concurrency checks
- Remember: one in‑flight request per session. If behavior seems racy, ensure separate sessions per concurrent task.

Host/TLS limitations
- Current session path connects to loopback and does not enable TLS. Test locally or via a tunnel; plan accordingly for production networks.
