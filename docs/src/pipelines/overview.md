# Pipeline Overview

neo4j_eio provides a fluent, composable pipeline for Cypher queries via the `Cypher` module. You build a query, optionally attach parameters, decode rows with an `Extract` extractor, apply transformations, and execute with a `Session`.

Core building blocks
- `Cypher.query "..."` / `query_unit "..."` — build a base query
- `Cypher.with_params [ (name, Value.value); ... ]` — bind parameters
- `Cypher.extract Extract.(...)` — decode `Record.t list` to typed values
- Transformations — `map`, `filter`, `take`, `single`, `expect_one`, etc.
- Execution helpers — `run_in session`, `execute session`, `|>> session` (operator), and `_exn` variants

Minimal pipeline
```ocaml
open Neo4j_eio

let q = Cypher.(
  query "RETURN 1 AS n, 'hi' AS s"
  |> extract Extract.(
       let+ n = int "n"
       and+ s = text "s" in (n, s))
  |> expect_one
)

let result = Cypher.run_in session q  (* ('a, Error.t) result *)
```

Execution helpers
- `run_in session q` and `execute session q` both execute a pipeline and return a `('a, Error.t) result`.
- `run_in_exn session q` and `execute_exn session q` raise on error.
- `q |>> session` is an operator alias for `run_in session q`.

Transactions
- Use `Cypher.in_transaction (fun s -> ...)` to wrap multiple pipeline steps in a transaction, using `Session.transact` under the hood.

When to use pipelines
- You prefer typed extraction and post-processing in a single, readable flow.
- You want to apply common sequence operations (map, filter, folds) to results.
- You want reusable components: extractors + parameter builders + transformation blocks.
