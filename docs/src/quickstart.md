# Quick Start

This quick start gets you from zero to your first query using the real API used throughout the codebase and examples.

Prerequisites
- Follow Installation to set up OCaml, dependencies, and start Neo4j.
- Ensure env vars are set, or rely on defaults from `Config.of_env ()`.

Minimal program
Creates a label-scoped person, fetches it, prints results, and cleans up.

```ocaml
open Neo4j_eio

let () =
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in
    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        let label = Printf.sprintf "QS_%d" (Random.int 1_000_000) in

        (* Create a node *)
        let _ = Query_builder.execute_unit
          (Query_builder.create_node (Printf.sprintf "(p:%s {name: 'Alice', age: 30})" label))
          session in

        (* Query it back *)
        let result = Query_builder.execute
          (Query_builder.match_ (Printf.sprintf "(p:%s {name: 'Alice'})" label)
           |> Query_builder.return ["p.name AS name"; "p.age AS age"]) session in

        (match result with
         | Ok [record] ->
             (match Record.at_text record "name", Record.at_int record "age" with
              | Ok name, Ok age -> Printf.printf "Found %s age %Ld\n" name age
              | _ -> Printf.printf "Unexpected record shape\n")
         | Ok _ -> Printf.printf "No record matched\n"
         | Error e -> Printf.eprintf "Query failed: %s\n" (Error.to_string e));

        (* Cleanup *)
        let _ = Query_builder.execute_unit
          (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
           |> Query_builder.detach_delete ["n"]) session in
        Ok ()
      ) with
      | Ok () -> ()
      | Error e -> Printf.eprintf "Session failed: %s\n" (Error.to_string e)
```

Run it (from `ocaml/`):
- Save as `quickstart.ml`
- Add a simple dune file (or use examples as reference):

```
(executable
 (name quickstart)
 (modules quickstart)
 (libraries neo4j_eio eio eio_main))
```

- Build and run: `dune exec quickstart.exe`

Parameters and safety
- Build parameters with `Query_builder.with_params`:

```ocaml
let res = Query_builder.execute
  (Query_builder.raw "RETURN $x + 1 AS y"
   |> Query_builder.with_params ["x", Value.Int 41L])
  session
```

- Decode fields with `Record.at_*` accessors for precise typing (`at_text`, `at_int`, `at_bool`, etc.).

Streaming and transactions (pointers)
- For large results, use `Session.run_stream` or `Session.run_stream_records` and `stream_to_list`/`record_stream_to_list`.
- For multi-step logic and robust error handling, see the Transaction DSL in examples (`ocaml/examples/simple_queries.ml`).

