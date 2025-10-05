(** Query Builder DSL Examples

    This demonstrates the declarative query builder DSL that allows
    composing Cypher queries in a fluent, type-safe manner.
*)

open Neo4j_eio

let run_examples env =
  let open Eio in
  Switch.run @@ fun sw ->

    (* Create a test configuration *)
    let cfg = Config.of_env () in

    match Session.with_session ~sw ~net:env#net cfg (fun session ->

      (* Example 1: Basic MATCH and RETURN *)
      Format.printf "\n=== Example 1: Basic Query ===\n%!";
      let query1 = Query_builder.match_ "(p:Person)"
                   |> Query_builder.return ["p.name AS name"; "p.age AS age"]
                   |> Query_builder.limit 5 in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query1);

      (match Query_builder.execute query1 session with
       | Ok records ->
           List.iter (fun record ->
             match Record.at_text record "name", Record.at_int record "age" with
             | Ok name, Ok age -> Format.printf "  - %s (age %Ld)\n%!" name age
             | _ -> ()
           ) records
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 2: CREATE with parameters *)
      Format.printf "\n=== Example 2: Create with Parameters ===\n%!";
      let test_label = Printf.sprintf "QB_%d" (Random.int 1000000) in
      let name_param = ("name", Value.Text "Bob Builder") in
      let age_param = ("age", Value.Int 42L) in

      let query2 = Query_builder.create_node
                     (Printf.sprintf "(p:%s {name: $name, age: $age})" test_label)
                   |> Query_builder.with_params [name_param; age_param]
                   |> Query_builder.return ["p.name AS name"] in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query2);

      (match Query_builder.execute query2 session with
       | Ok [record] ->
           (match Record.at_text record "name" with
            | Ok name -> Format.printf "Created: %s\n%!" name
            | Error e -> Format.eprintf "Decode error: %a\n%!" Record.pp_decode_error e)
       | Ok _ -> Format.printf "Unexpected result count\n%!"
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 3: WHERE with AND conditions *)
      Format.printf "\n=== Example 3: WHERE Conditions ===\n%!";
      let query3 = Query_builder.match_ (Printf.sprintf "(p:%s)" test_label)
                   |> Query_builder.where "p.age >= 18"
                   |> Query_builder.and_where "p.age < 65"
                   |> Query_builder.return ["p.name AS name"; "p.age AS age"] in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query3);

      (match Query_builder.execute query3 session with
       | Ok records ->
           Format.printf "Found %d matching records\n%!" (List.length records)
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 4: ORDER BY and LIMIT *)
      Format.printf "\n=== Example 4: Ordering and Limiting ===\n%!";
      let query4 = Query_builder.match_ "(p:Person)"
                   |> Query_builder.return ["p.name AS name"; "p.age AS age"]
                   |> Query_builder.order_by_desc "p.age"
                   |> Query_builder.order_by "p.name"
                   |> Query_builder.limit 10
                   |> Query_builder.skip 0 in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query4);

      (* Example 5: SET to update properties *)
      Format.printf "\n=== Example 5: UPDATE Properties ===\n%!";
      let query5 = Query_builder.match_ (Printf.sprintf "(p:%s {name: 'Bob Builder'})" test_label)
                   |> Query_builder.set ["p.age = 43"; "p.updated = true"]
                   |> Query_builder.return ["p.name AS name"; "p.age AS age"] in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query5);

      (match Query_builder.execute query5 session with
       | Ok records ->
           Format.printf "Updated %d records\n%!" (List.length records)
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 6: UNWIND for batch operations *)
      Format.printf "\n=== Example 6: UNWIND for Batch ===\n%!";
      let items = [1; 2; 3; 4; 5] in
      let items_value = Value.List (List.map (fun i -> Value.Int (Int64.of_int i)) items) in

      let query6 = Query_builder.unwind "$items" "x"
                   |> Query_builder.with_params [("items", items_value)]
                   |> Query_builder.create (Printf.sprintf "(n:%s {value: x})" test_label)
                   |> Query_builder.return ["n.value AS value"] in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query6);

      (match Query_builder.execute query6 session with
       | Ok records ->
           Format.printf "Created %d nodes from batch\n%!" (List.length records)
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 7: MERGE (create or match) *)
      Format.printf "\n=== Example 7: MERGE ===\n%!";
      let query7 = Query_builder.merge (Printf.sprintf "(p:%s {name: 'Unique Bob'})" test_label)
                   |> Query_builder.return ["p.name AS name"] in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query7);

      (* Run twice to show it only creates once *)
      (match Query_builder.execute query7 session with
       | Ok _ -> Format.printf "First MERGE complete\n%!"
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (match Query_builder.execute query7 session with
       | Ok _ -> Format.printf "Second MERGE complete (node already existed)\n%!"
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 8: OPTIONAL MATCH *)
      Format.printf "\n=== Example 8: OPTIONAL MATCH ===\n%!";
      let query8 = Query_builder.optional_match (Printf.sprintf "(p:%s)" test_label)
                   |> Query_builder.return ["count(p) AS total"] in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query8);

      (match Query_builder.execute query8 session with
       | Ok [record] ->
           (match Record.at_int record "total" with
            | Ok count -> Format.printf "Total nodes: %Ld\n%!" count
            | Error e -> Format.eprintf "Decode error: %a\n%!" Record.pp_decode_error e)
       | Ok _ -> Format.printf "Unexpected result\n%!"
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 9: WITH clause for chaining *)
      Format.printf "\n=== Example 9: WITH Clause ===\n%!";
      let query9 = Query_builder.match_ (Printf.sprintf "(p:%s)" test_label)
                   |> Query_builder.with_ ["p"; "p.value AS val"]
                   |> Query_builder.where "val IS NOT NULL"
                   |> Query_builder.return ["sum(val) AS total"] in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query9);

      (match Query_builder.execute query9 session with
       | Ok [record] ->
           (match Record.at_int record "total" with
            | Ok sum -> Format.printf "Sum of values: %Ld\n%!" sum
            | Error _ -> Format.printf "No numeric values found\n%!")
       | Ok _ -> Format.printf "Unexpected result\n%!"
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Example 10: DISTINCT results *)
      Format.printf "\n=== Example 10: DISTINCT ===\n%!";
      let query10 = Query_builder.match_ "(p:Person)"
                    |> Query_builder.return_distinct ["p.age AS age"]
                    |> Query_builder.order_by "age"
                    |> Query_builder.limit 5 in

      Format.printf "Query: %s\n%!" (Query_builder.to_string query10);

      (match Query_builder.execute query10 session with
       | Ok records ->
           Format.printf "Found %d distinct ages\n%!" (List.length records)
       | Error e -> Format.eprintf "Error: %s\n%!" (Error.to_string e));

      (* Cleanup *)
      Format.printf "\n=== Cleanup ===\n%!";
      let cleanup = Query_builder.match_ (Printf.sprintf "(n:%s)" test_label)
                    |> Query_builder.detach_delete ["n"] in

      (match Query_builder.execute_unit cleanup session with
       | Ok () -> Format.printf "Cleanup complete\n%!"
       | Error e -> Format.eprintf "Cleanup error: %s\n%!" (Error.to_string e));

      Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Format.eprintf "Session error: %s\n%!" (Error.to_string e)

let () =
  Random.self_init ();
  Eio_main.run (fun env ->
    run_examples env
  )
