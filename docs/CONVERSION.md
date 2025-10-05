**Hasbolt → OCaml Eio Neo4j Driver: Conversion Plan**

This document defines a concrete, multi‑phase plan to translate the Haskell Neo4j client in `hasbolt/` into a production‑quality OCaml library that uses Eio for effects‑based I/O. It includes a master checklist, design details, and how to build and test against the provided Docker Compose Neo4j service.

**Master Checklist**

- Phase 1 — Scope & Audit
  - Task 1.1: Inventory hasbolt features and public API
  - Task 1.2: Map hasbolt types to OCaml Eio design
  - Task 1.3: Confirm protocol compatibility with Neo4j 5 (Bolt v4/v5)
- Phase 2 — Project Scaffolding
  - Task 2.1: Create Dune workspace and library skeleton
  - Task 2.2: Pin dependencies for Eio + parsing/bytes
  - Task 2.3: Establish CI/test runner basics
- Phase 3 — PackStream Encoding/Decoding
  - Task 3.1: Define core `Value` types (incl. v2 types)
  - Task 3.2: Implement encoder (OCaml → PackStream)
  - Task 3.3: Implement decoder (PackStream → OCaml)
  - Task 3.4: Unit tests for round‑trips
- Phase 4 — Bolt Framing & Handshake
  - Task 4.1: Frame boundaries, message codes, version negotiation
  - Task 4.2: HELLO/LOGON/GOODBYE auth flows
  - Task 4.3: SUCCESS/RECORD/FAILURE/SUMMARY decode
- Phase 5 — Eio Connection Layer
  - Task 5.1: TCP/TLS flows via Eio
  - Task 5.2: Request/response pipeline + backpressure
  - Task 5.3: Error handling and reset
- Phase 6 — High‑Level API Parity
  - Task 6.1: `query`, `query_p`, `query_`, params helpers
  - Task 6.2: Record decoding (`at`, `exact`, `maybe_exact`)
  - Task 6.3: Config struct + sensible defaults
- Phase 7 — Transactions
  - Task 7.1: Explicit `BEGIN`/`COMMIT`/`ROLLBACK`
  - Task 7.2: `transact` helper (function style)
  - Task 7.3: Streaming `PULL` with fetch size
- Phase 8 — Integration Tests
  - Task 8.1: Docker Compose wiring and env config
  - Task 8.2: Query/params/values/tx/error coverage
  - Task 8.3: Idempotent data setup/teardown
- Phase 9 — Documentation & Examples
  - Task 9.1: README and examples
  - Task 9.2: API docs and usage notes
- Phase 10 — Polish & Release Prep
  - Task 10.1: API stability pass
  - Task 10.2: Performance sanity checks

**Phase 1 — Scope & Audit**

- Task 1.1: Inventory hasbolt features and public API
  - Inputs: `hasbolt/src/Database/Bolt.hs`, `hasbolt/src/Database/Bolt/*`, `hasbolt/test/*`.
  - Identify surface: connection config, `connect/close/reset`, `run/runE`, `query/queryP/query_`, transactions, `Record` accessors (`at`, `exact`, `maybeAt`), values (nodes/relationships/paths), new types (v2: Point2D/3D, Duration, Date/Time variants).
  - Acceptance: Complete API list with signatures and behavior notes captured in this plan.
- Task 1.2: Map hasbolt types to OCaml Eio design
  - Select OCaml representations for all hasbolt Value/Record types, preserving semantics and totality.
  - Choose error modeling via polymorphic variants or regular variants and a unified `('a, error) result`.
  - Acceptance: Mapping table finalized; no ambiguous or lossy conversions.
- Task 1.3: Confirm protocol compatibility with Neo4j 5 (Bolt v4/v5)
  - Neo4j image in `docker-compose.yml` is `neo4j:5` exposing Bolt `7687`.
  - Plan to negotiate `[5, 4, 3, 2, 1]`, handle v4/v5 message set while preserving hasbolt v1/v2 features via a unified API.
  - Acceptance: Documented negotiation strategy and message set for v4/v5 (HELLO/LOGON, RUN, PULL, DISCARD, BEGIN/COMMIT/ROLLBACK, RESET, GOODBYE).

**Phase 2 — Project Scaffolding**

- Task 2.1: Create Dune workspace and library skeleton
  - Create `ocaml/neo4j_eio/` with `dune-project`, `src/`, `test/`.
  - Library name: `neo4j_eio`. Public modules: `Connection`, `Protocol`, `Packstream`, `Value`, `Record`, `Transaction`, `Client`.
  - Acceptance: `dune build` succeeds (no stubs; buildable placeholders kept minimal but real).
- Task 2.2: Pin dependencies for Eio + parsing/bytes
  - Dependencies: `eio`, `eio_main`, `angstrom`, `cstruct`, `bigstringaf`, `tls`, `tls-eio` (bridge), `x509`, `alcotest`.
  - Rationale: Eio networking/flows; TLS via ocaml‑tls + eio; Angstrom for binary parsing; Cstruct for efficient bytes; BigstringAF base; Alcotest for tests.
  - Acceptance: `opam install` of exact set works on OCaml ≥ 5.1.
- Task 2.3: Establish CI/test runner basics
  - Local first: `dune runtest` assumes Docker Neo4j running.
  - Provide a test helper that skips with a clear message if Bolt is unreachable.
  - Acceptance: Tests discover and attempt connection to `localhost:7687`.

**Phase 3 — PackStream Encoding/Decoding**

- Task 3.1: Define core `Value` types (incl. v2 types)
  - Implement OCaml variants mirroring hasbolt: primitives, lists, maps, structures; graph entities: Node, Relationship, UnboundRelationship, Path; new types: Point2D/3D, Duration, Date, Time, LocalTime, LocalDateTime, ZonedDateTime (offset and zone‑name variants).
  - Ensure integer width safety (`int64`), and exact mapping for doubles and text.
  - Acceptance: Exhaustive type definitions with derived printers for debugging.
- Task 3.2: Implement encoder (OCaml → PackStream)
  - Encode scalars, maps, lists, and structures according to PackStream rules, including tiny forms and markers.
  - Encode all structure signatures for values and graph types.
  - Acceptance: Golden tests for multiple samples match hasbolt semantics.
- Task 3.3: Implement decoder (PackStream → OCaml)
  - Angstrom parsers for markers, lengths, ints, floats, text (UTF‑8), lists, maps, and structures.
  - Map signatures to value constructors; produce descriptive errors on unknown signatures.
  - Acceptance: Round‑trip property tests for representative values.
- Task 3.4: Unit tests for round‑trips
  - Arbitrary generators for values; check encode→decode and decode→encode invariants where defined.
  - Acceptance: 100% of covered constructors exercised.

**Phase 4 — Bolt Framing & Handshake**

- Task 4.1: Frame boundaries, message codes, version negotiation
  - Implement chunked message framing per Bolt spec; support chunking limits and message boundaries.
  - Negotiate highest supported protocol in `[5,4,3,2,1]` using the magic `0x6060B017` preface.
  - Acceptance: Handshake unit tests that validate negotiation results from a mocked server flow.
- Task 4.2: HELLO/LOGON/GOODBYE auth flows
  - Implement both HELLO with inline credentials (v4) and HELLO+LOGON (v5) paths; basic scheme only initially; optional TLS via `tls-eio` when configured (`bolt+s`).
  - Acceptance: Real connection to `neo4j:5` succeeds with `NEO4J_AUTH` from compose (`neo4j/test`).
- Task 4.3: SUCCESS/RECORD/FAILURE/SUMMARY decode
  - Implement message structs for `RUN`, `PULL`, `DISCARD`, `BEGIN`, `COMMIT`, `ROLLBACK`, `RESET`, `GOODBYE` and decode of `SUCCESS`, `RECORD`, `FAILURE` with metadata.
  - Acceptance: Integration test verifies one `RUN`/`PULL` cycle with at least one record.

**Phase 5 — Eio Connection Layer**

- Task 5.1: TCP/TLS flows via Eio
  - Use `Eio.Net.connect` to `host:port`; wrap with `Tls_eio.client_of_flow` when TLS is enabled; configure SNI and certs when provided.
  - Provide `with_connection` to ensure proper resource cleanup via `Eio.Switch`.
  - Acceptance: Clean close on normal and exceptional paths (GOODBYE + socket close).
- Task 5.2: Request/response pipeline + backpressure
  - Single‑connection, fiber‑safe queue guarded by `Eio.Mutex`; serialize request→response exchanges; streaming `RECORD`s via a pull loop with configurable fetch size.
  - Acceptance: Concurrent query attempts are serialized; no interleaving corruption.
- Task 5.3: Error handling and reset
  - Map server `FAILURE` to typed errors; implement `RESET` to clear failed states; propagate errors as `('a, error) result`.
  - Acceptance: Failure test recovers after `RESET` and succeeds on next query.

**Phase 6 — High‑Level API Parity**

- Task 6.1: `query`, `query_p`, `query_`, params helpers
  - Provide functions that mirror hasbolt: return list of records (strict), and underscore variants that ignore results.
  - Parameter helpers like `props` and `=:` to build PackStream maps ergonomically in OCaml.
  - Acceptance: Example queries from `hasbolt/README.md` reproduced in OCaml.
- Task 6.2: Record decoding (`at`, `exact`, `maybe_exact`)
  - Implement a `Record` abstraction (ordered key→Value map) with typed getters mirroring `at`/`exact` behavior.
  - Acceptance: Type‑directed decoders return expected OCaml types with precise errors.
- Task 6.3: Config struct + sensible defaults
  - Config fields: `uri`, `user`, `password`, `user_agent`, `fetch_size`, `use_tls`, `tls_ca`, `log_level`, `protocols`.
  - Acceptance: Default config matches compose (bolt, no TLS, fetch_size=1000).

**Phase 7 — Transactions**

- Task 7.1: Explicit `BEGIN`/`COMMIT`/`ROLLBACK`
  - Implement transactional contexts that carry bookmarks and metadata; return a transaction handle for `RUN` within tx.
  - Acceptance: Create→Match→Rollback leaves database unchanged; Create→Commit persists.
- Task 7.2: `transact` helper (function style)
  - High‑level `transact (fun tx -> ...)` that commits on success, rolls back on error.
  - Acceptance: Exceptions or error results lead to rollback reliably.
- Task 7.3: Streaming `PULL` with fetch size
  - Support both strict materialization and iterator‑style consumption (pull until done) with a consistent API.
  - Acceptance: Large result sets retrieve in chunks without OOM.

**Phase 8 — Integration Tests**

- Task 8.1: Docker Compose wiring and env config
  - Use container from `docker-compose.yml` with `NEO4J_AUTH=neo4j/test`, ports `7474`, `7687`.
  - Env vars: `NEO4J_URI` (default `bolt://localhost:7687`), `NEO4J_USER`, `NEO4J_PASSWORD`.
  - Acceptance: Test harness tries to connect and bails with a clear skip if unavailable.
- Task 8.2: Query/params/values/tx/error coverage
  - Tests for: simple match, parameters substitution, Node/Relationship/Path decode, v2 value types, wrong field name error, type mismatch, syntax error mapping, transaction success/rollback, reset after failure.
  - Acceptance: All scenarios green against Neo4j 5.
- Task 8.3: Idempotent data setup/teardown
  - Wrap mutating tests in transactions with rollback or clean up explicitly with `DETACH DELETE`.
  - Acceptance: Re‑running test suite leaves DB in a clean state.

**Phase 9 — Documentation & Examples**

- Task 9.1: README and examples
  - Provide minimal examples mirroring hasbolt README scenarios: simple queries, parameters, decoding to typed values, transactions.
  - Acceptance: Examples compile and run against local container.
- Task 9.2: API docs and usage notes
  - Explain protocol negotiation, TLS options, error taxonomy, fetch size semantics, concurrency rules (one in‑flight exchange per connection).
  - Acceptance: Docs answer common “how do I?” questions.

**Phase 10 — Polish & Release Prep**

- Task 10.1: API stability pass
  - Ensure names, modules, and types are consistent and minimal.
  - Acceptance: No breaking rename after this step.
- Task 10.2: Performance sanity checks
  - Bench simple `UNWIND 1..N RETURN n` and large result pulls; confirm no needless allocations in hot paths.
  - Acceptance: Reasonable throughput; no pathological slowdowns.

**OCaml Design Overview**

- Modules
  - `Neo4j_eio.Value`: All PackStream value types and graph entities.
  - `Neo4j_eio.Packstream`: Encoding/decoding primitives and structure signatures.
  - `Neo4j_eio.Protocol`: Bolt messages, frames, handshake, metadata mapping.
  - `Neo4j_eio.Connection`: Eio TCP/TLS flow, send/receive, pipeline guard, reset, goodbye.
  - `Neo4j_eio.Record`: Record abstraction and typed accessors.
  - `Neo4j_eio.Transaction`: Tx lifecycle and helpers.
  - `Neo4j_eio.Client`: High‑level API parity with hasbolt.

- Error Model
  - Use a unified `error` variant (e.g., `Io of exn | Protocol of string | Pack of string | Server of code * msg | Auth of string`).
  - All public functions return `('a, error) result` or raise only on programmer error; provide helpers to lift into exceptions if desired.

- Concurrency Model
  - One connection = one serialized request/response pipeline guarded by `Eio.Mutex` for safety with multiple fibers.
  - Recommend per‑fiber connections or a simple pool if needed later; keep API synchronous over Eio effects for clarity.

- Type Mapping Highlights (Hasbolt → OCaml)
  - `Value`: map to OCaml variant with `Int of int64`, `Float of float`, `Bool of bool`, `Null`, `Text of string`, `List of value list`, `Map of (string * value) list`, etc.
  - `Node/Relationship/URelationship/Path`: record types with ids as `int64`, labels/types as `string list`, props as `Map`.
  - New v2 types: dedicated constructors ensuring no data loss.
  - Records: `Record` as an ordered `string -> value` map plus positional vector.

**Dependency Choices From OCaml Ecosystem (Eio‑Compatible)**

- `eio`, `eio_main`: Effects‑based networking and fibers.
- `tls`, `tls-eio`, `x509`: TLS client over Eio flows when `bolt+s` is requested.
- `angstrom`: Fast parser combinators for binary PackStream and Bolt frames.
- `cstruct`, `bigstringaf`: Efficient byte buffers for encode/decode.
- `alcotest`: Test framework; integrates cleanly with `Eio_main.run`.

**How To Build And Test**

- Prereqs
  - Install OCaml ≥ 5.1 and opam.
  - Start Neo4j via compose: `docker compose up -d neo4j` (file: `docker-compose.yml`).

- Setup
  - Create local switch: `opam switch create . 5.2.1` then `eval $(opam env)`.
  - Install tooling: `opam install dune ocamlformat`.
  - Install deps: `opam install eio eio_main angstrom cstruct bigstringaf tls tls-eio x509 alcotest`.

- Build
  - From `ocaml/neo4j_eio/`: `dune build`.

- Test
  - Ensure env: `export NEO4J_URI=bolt://localhost:7687 NEO4J_USER=neo4j NEO4J_PASSWORD=test`.
  - Run: `dune runtest`.
  - Tests connect to the compose Neo4j, create temporary data in transactions, and clean up.

**Acceptance Criteria Summary**

- All hasbolt functionality is present with equivalent semantics.
- I/O is implemented with Eio only (no Lwt/Async).
- PackStream and Bolt framing fully implemented; no placeholders or TODOs.
- Integration tests exercise real Neo4j over Bolt from Docker Compose.
- Clear docs and examples; type‑safe API with total decoders where possible.

