# Query Execution Basics

This page shows the supported ways to execute Cypher queries, the shapes of returned results, and when to use each approach. All APIs here are present in the current code and examples.

Ways to run a query
- Query Builder helpers (recommended): `Query_builder.execute` and `execute_unit`
- Low-level session API: `Session.run` (values) and `Session.run_records` (named fields)
- Streaming APIs: `Session.run_stream` and `Session.run_stream_records`

Query Builder (recommended)
- Build Cypher declaratively and run against a `Session`.

```ocaml
(* Build and run a simple query *)
let res = Query_builder.execute
  (Query_builder.raw "RETURN 1 AS n, 'hi' AS s, true AS b")
  session
(* res : (Record.t list, Error.t) result *)
```

Parameters
```ocaml
let res = Query_builder.execute
  (Query_builder.raw "RETURN $x + 1 AS y, $s AS t"
   |> Query_builder.with_params [
        ("x", Value.Int 41L);
        ("s", Value.Text "hello");
      ])
  session
```

Mutations and cleanup
```ocaml
(* CREATE then DELETE test data *)
let _ = Query_builder.execute_unit
  (Query_builder.create_node "(p:Tmp {name: 'Alice'})") session in
let _ = Query_builder.execute_unit
  (Query_builder.match_ "(p:Tmp)" |> Query_builder.detach_delete ["p"]) session in
```

Decoding results
- `Query_builder.execute` returns `Record.t list`. Use `Record.at_*` to decode fields safely:

```ocaml
match res with
| Ok [r] ->
    (match Record.at_int r "y", Record.at_text r "t" with
     | Ok y, Ok t -> Printf.printf "y=%Ld t=%s\n" y t
     | _ -> Printf.printf "decode error\n")
| Ok _ -> Printf.printf "unexpected row count\n"
| Error e -> Printf.eprintf "error: %s\n" (Error.to_string e)
```

Session API
- `Session.run ~statement ?parameters ?fetch_size ()` returns a list of value lists (positional values per row). Use when you don’t need field names.
- `Session.run_records ~statement ?parameters ?fetch_size ()` returns `Record.t list` with field names from the `RUN` metadata.

```ocaml
let params =
  [ ("a", Value.Int 7L); ("b", Value.Int 6L) ]
  |> List.fold_left (fun acc (k,v) -> Value.StringMap.add k v acc) Value.StringMap.empty in

let rows = Session.run_records session
  ~statement:"RETURN $a + $b AS sum, $a * $b AS product"
  ~parameters:params ()
```

Streaming
- Use streaming when results may be large and you want to process them in chunks.
- Values stream: `Session.run_stream ~statement ?parameters ~fetch_size:100L ()`
- Records stream: `Session.run_stream_records ~statement ?parameters ~fetch_size:100L ()`
- Convert a stream to a list with `Session.stream_to_list` or `Session.record_stream_to_list`.

```ocaml
match Session.run_stream_records session ~statement:"UNWIND range(1, 10) AS n RETURN n" ~fetch_size:3L () with
| Error e -> Printf.eprintf "stream start failed: %s\n" (Error.to_string e)
| Ok s ->
    let rec loop () =
      if s.exhausted then () else
      match s.fetch_next_records () with
      | Error e -> Printf.eprintf "fetch error: %s\n" (Error.to_string e)
      | Ok chunk -> Printf.printf "chunk size %d\n" (List.length chunk); loop ()
    in loop ()
```

Transactions
- Wrap multiple queries with `Session.begin_transaction`/`commit`/`rollback`, or use `Session.transact`.
- Query Builder works inside transactions the same way as outside.

Failure and reset behavior
- On server FAILURE outside a transaction, the session auto-issues RESET and returns an error.
- Inside a transaction, rollback clears failed state.

When to use what
- Quick scripts and examples: `Query_builder.execute/execute_unit`.
- When you need field names: `Session.run_records` or Query Builder (which returns records).
- When you only need positional values: `Session.run`.
- Large results: streaming variants plus `*_to_list` helpers.

Notes
- `~fetch_size` controls records pulled per `PULL`; strict `run/run_records` will loop until all results are fetched.
- Parameters are maps of `string -> Value.value`. Build via `Value.StringMap` or Query Builder’s `with_params`.

