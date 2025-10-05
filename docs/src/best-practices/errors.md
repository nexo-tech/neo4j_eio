# Error Handling Patterns (Best Practices)

neo4j_eio returns `('a, Error.t) result` for all operations. This section complements the core Concepts → Errors.

Handle and classify
- Pattern match on `Error.t` (`Io | Protocol | Auth | Database | Transient | ClientError`).
- Log `code` and `message` for server failures (Database/Transient/ClientError).

Reset semantics
- On server FAILURE outside a transaction, the driver auto-issues `RESET` and leaves session usable.
- Inside transactions, call `rollback` to clear failed state.

Retries
- Consider targeted retries for `Transient` errors around idempotent operations.
- Implement retry loops at application level (e.g., exponential backoff); the session API does not include retries.

Pipelines and DSL
- Use `Cypher.catch`/`recover` or `Transaction_dsl.catch` to implement fallback logic.
- Prefer `expect_one`/`single` to surface cardinality errors early.
