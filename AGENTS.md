Agent Policies and Development Requirements

Scope
- Applies to the entire repository unless a more deeply nested AGENTS.md overrides it.
- OCaml driver work resides under `ocaml/neo4j_eio/` unless otherwise agreed.

Hard Requirements
- Eio‑only I/O: All networking, concurrency, and file I/O must use Eio (`eio`, `eio_main`). Do not use Lwt, Async, or Unix blocking APIs in library code.
- Full implementations only: No TODOs, stubs, or placeholder functions. All public functions must be implemented and either tested or explicitly internal.
- Type safety: Prefer precise algebraic data types and `('a, error) result` for recoverable errors. Avoid exceptions for control flow. Use `int64` for Bolt IDs and integer values to prevent overflow.
- Functional style: Favor pure functions and immutability. Side effects must be explicit and contained within Eio contexts.
- Parity: Feature parity with `hasbolt` is mandatory (queries, parameters, transactions, values including v2 types, record accessors, reset, error mapping).

Security & Protocol
- Authentication is provided by user/password; never embed secrets in source. Read credentials from configuration and/or environment.
- TLS: Support TLS for `bolt+s` via `tls` + `tls-eio`. Validate certificates by default; allow an explicit, opt‑in insecure mode for local development only.
- Protocol negotiation: Offer `[5,4,3,2,1]` and select the highest common version. Implement HELLO/LOGON/GOODBYE, RUN, PULL, DISCARD, BEGIN/COMMIT/ROLLBACK, RESET.

Error Handling
- Introduce a unified error type (e.g., `Io | Protocol | Pack | Server | Auth`). All public APIs return `('a, error) result`.
- Convert server `FAILURE` into typed errors carrying code and message. Include context (message type, query) where safe.

Concurrency
- One in‑flight exchange per connection. Guard with `Eio.Mutex` to serialize concurrent fibers.
- Clean resource management via `Eio.Switch` and `with_connection` helpers.

Testing
- Use `Alcotest` for unit and integration tests.
- Integration tests must connect to the Neo4j service defined in `docker-compose.yml` (service `neo4j`, Bolt `7687`).
- Tests must be idempotent and leave the database clean. Prefer wrapping mutating tests in transactions with rollback.
- Environment variables: `NEO4J_URI` (default `bolt://localhost:7687`), `NEO4J_USER` (default `neo4j`), `NEO4J_PASSWORD` (default `test`).
- No sleeps or flaky timing. Use deterministic assertions and explicit cleanup.

Dependencies & Build
- Use `dune` as the build system.
- Keep dependencies minimal: `eio`, `eio_main`, `angstrom`, `cstruct`, `bigstringaf`, `tls`, `tls-eio`, `x509`, `alcotest`.
- Do not introduce heavy frameworks if a small, direct solution exists.

Code Organization
- Top‑level library: `neo4j_eio` with modules: `Value`, `Packstream`, `Protocol`, `Connection`, `Record`, `Transaction`, `Client`.
- Public module interfaces should expose minimal, stable APIs. Avoid leaking internal constructors when not necessary.
- Keep functions small and single‑purpose. Document invariants and assumptions where non‑obvious.

Style & Tooling
- Use `ocamlformat` for formatting. No dead code, commented‑out blocks, or `failwith "todo"`.
- No polymorphic comparison on complex values. Provide explicit comparators if needed for tests.

Documentation
- Update `CONVERSION.md` as tasks complete. Keep README examples accurate and minimal.
- Provide inline docstrings for public functions and types.

Acceptance Criteria
- All tests green against the Neo4j Docker service.
- No TODOs/stubs. Interfaces are type‑safe and documented.
- Eio‑only I/O with correct resource cleanup and error propagation.

