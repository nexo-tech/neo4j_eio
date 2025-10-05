# Performance Optimization

Guidelines to get good performance with neo4j_eio based on the current API and implementation.

Queries
- Prefer server-side projection and aggregation: return only needed fields with `AS` aliases and compute aggregates in Cypher.
- Use parameters (`$param` + `with_params`) instead of string interpolation; keeps parsing/cache benefits and avoids allocations.

Sessions and concurrency
- One request in flight per session; create multiple sessions (fibers) for parallelism.
- Use an application-level pool for high concurrency (see Pooling). Keep transactions short.

Streaming and batching
- Use `Session.run_stream(_records)` for large results; tune `~fetch_size` to balance latency and memory.
- In pipelines, use `chunk`/`batch`/`sliding_window` to process data in manageable slices.
- Avoid `*_to_list` unless you truly need the entire result in memory.

Pipelines
- Place `extract` early and operate on typed, smaller payloads.
- Prefer `map`/`filter` over repeatedly decoding fields.
- Use `expect_one`/`single` where cardinality is known; it avoids extra list handling later.

Cypher shape
- Favor pattern comprehension and list projections `[ ... | ... ]` when you only need specific attributes.
- Avoid returning full nodes/relationships if props/IDs suffice.

I/O and connection
- Reuse sessions; avoid opening/closing per small operation.
- For higher throughput, create multiple sessions in one `Eio.Switch` and distribute work.
