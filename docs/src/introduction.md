# neo4j_eio — OCaml Neo4j Driver (Eio)

neo4j_eio is a modern, effects-based Neo4j driver for OCaml 5+. It implements the Bolt protocol and uses Eio for safe, concurrent I/O. The library focuses on type safety, predictable errors, and approachable APIs for both simple queries and advanced graph workflows.

- Eio-first design: safe concurrency, no blocking Unix calls in library code
- Bolt protocol support: v5 (primary), v4, v3 negotiation
- Strong typing: explicit `('a, Error.t) result` across the surface
- Complete value coverage: all PackStream and Neo4j v2 temporal/spatial types
- Transactions: explicit BEGIN/COMMIT/ROLLBACK and a Transaction DSL
- Streaming: consume large result sets incrementally
- Query Builder: fluent Cypher construction with parameters
- Record decoding: ergonomic, typed accessors

Compatibility
- Neo4j 5.x: Bolt v5
- Neo4j 4.x: Bolt v4
- Neo4j 3.5+: Bolt v3

Core Modules Overview
- `Config`: Build configuration or read from environment (`Config.of_env`) with `NEO4J_URI`, `NEO4J_USER`, `NEO4J_PASSWORD`.
- `Session`: Create and use a single Bolt session. Serializes requests (one in-flight per session). Key operations:
  - `with_session ~sw ~net cfg (fun s -> ...)`
  - `run` / `run_stream` / `run_stream_records`
  - `begin_transaction`, `commit`, `rollback`, `transact`
  - `stream_to_list`, `record_stream_to_list`, `reset`, `close`
- `Record`: Safe field access from returned rows
  - `at_text`, `at_int`, `at_bool`, etc.; `maybe_at_*` variants
- `Value`: All PackStream and graph entity types (Node, Relationship, Path, Point2D/3D, Duration, Date/Time variants, ...)
- `Query_builder`: Fluent, composable Cypher with parameters and helpers to execute against a `Session`
- `Transaction_dsl`: A composable monadic DSL that sequences queries with clear error handling; includes `run`, `return`, `let*`, `and+`, `catch`, `when_`, and helpers like `exec_query_builder`/`exec_query_builder_unit`
- Additional advanced modules: `Protocol`, `Connection`, `Packstream`, `Lens`, `Traversal`, `Extract`, `Result_ops`

Hello, Neo4j (Minimal Example)
This example mirrors the public API used throughout the repository’s examples and tests.

```ocaml
open Neo4j_eio

let () =
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in
    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        (* Build and run a simple query *)
        let open Transaction_dsl in
        let tx =
          let* rows = exec_query_builder
            (Query_builder.raw "RETURN 1 AS num, 'hello' AS text") in
          match rows with
          | [r] ->
              (match Record.at_int r "num", Record.at_text r "text" with
               | Ok n, Ok s ->
                   Printf.printf "num=%Ld text=%s\n" n s;
                   return ()
               | _ -> fail (Error.Protocol "Decode error"))
          | _ -> fail (Error.Protocol "Unexpected result"))
        in
        Transaction_dsl.run tx session
      ) with
      | Ok () -> ()
      | Error e -> Printf.eprintf "Session failed: %s\n" (Error.to_string e)
```

Design Notes
- Sessions are single-connection and serialize requests using a mutex. For parallel workloads, create multiple sessions (e.g., within the same `Eio.Switch`).
- On server `FAILURE`, the driver resets the session (outside of active transactions) to mirror behavior expected by other drivers and keep error recovery predictable.
- Field names come from the `RUN` metadata; `run_stream_records` preserves them for typed decoding via `Record`.

Where to Go Next
- Installation and setup: coming up in “Installation” (Phase 1.2)
- Quick start: see “Quick Start” (Phase 1.3) for a guided flow
- Explore examples in the repo under `ocaml/examples`:
  - `simple_queries.ml` — core patterns, parameters, error handling
  - `query_builder_dsl.ml` — fluent query construction
  - `transactions.ml` and `transaction_dsl.ml` — transaction control and the DSL
  - `streaming.ml` — streaming large result sets
  - `record_extraction.ml` — decoding values safely
  - `temporal_spatial.ml` — working with v2 temporal/spatial types

API Accuracy Checklist (This intro reflects)
- Session lifecycle: `with_session`, `run`/`run_stream`, transactions, `reset`
- Query Builder usage with `exec_query_builder`/`exec_query_builder_unit`
- Record accessors `Record.at_*` and `maybe_at_*`
- Error surface with `('a, Error.t) result` and `Error.to_string`
- Compatibility with Bolt v5/v4/v3

If you spot any mismatch between this guide and the code in `ocaml/src`, examples, or tests, please open an issue—accuracy is a hard requirement for this documentation.

