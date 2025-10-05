(** Transaction DSL Examples

    This demonstrates the monadic transaction DSL that provides composable
    transaction workflows with automatic commit/rollback handling.
*)

open Neo4j_eio

let run_examples env =
  let open Eio in
  Switch.run @@ fun sw ->

    (* Create a test configuration *)
    let cfg = Config.of_env () in

    match Session.with_session ~sw ~net:env#net cfg (fun session ->

      let test_label = Printf.sprintf "TX_%d" (Random.int 1000000) in

      (* Example 1: Basic transaction with automatic commit *)
      Format.printf "\n=== Example 1: Basic Transaction ===\n%!";
      let open Transaction_dsl in

      let tx1 = let* () = exec_query_builder_unit
                    (Query_builder.create_node
                       (Printf.sprintf "(p:%s {name: 'Alice', age: 30})" test_label)) in
                let* records = exec_query_builder
                    (Query_builder.match_ (Printf.sprintf "(p:%s)" test_label)
                     |> Query_builder.return ["count(p) AS cnt"]) in
                match records with
                | [record] ->
                    (match Record.at_int record "cnt" with
                     | Ok count ->
                         Format.printf "Created %Ld nodes\n%!" count;
                         return ()
                     | Error e -> fail (Error.Protocol (Format.asprintf "%a" Record.pp_decode_error e)))
                | _ -> fail (Error.Protocol "Unexpected result") in

      (match run tx1 session with
       | Ok () -> Format.printf "Transaction succeeded (auto-committed)\n%!"
       | Error e -> Format.eprintf "Transaction failed: %s\n%!" (Error.to_string e));

      (* Example 2: Explicit commit *)
      Format.printf "\n=== Example 2: Explicit Commit ===\n%!";

      let tx2 = let* () = exec_query_builder_unit
                    (Query_builder.create_node
                       (Printf.sprintf "(p:%s {name: 'Bob', age: 40})" test_label)) in
                let* () = commit in
                return () in

      (match run tx2 session with
       | Ok () -> Format.printf "Transaction explicitly committed\n%!"
       | Error e -> Format.eprintf "Transaction failed: %s\n%!" (Error.to_string e));

      (* Example 3: Explicit rollback *)
      Format.printf "\n=== Example 3: Explicit Rollback ===\n%!";

      let tx3 = let* () = exec_query_builder_unit
                    (Query_builder.create_node
                       (Printf.sprintf "(p:%s {name: 'Charlie', age: 50})" test_label)) in
                (* Decide to rollback instead of commit *)
                let* () = rollback in
                return () in

      (match run tx3 session with
       | Ok () ->
           Format.printf "Transaction rolled back\n%!";
           (* Verify node doesn't exist *)
           (match Query_builder.execute
                    (Query_builder.match_ (Printf.sprintf "(p:%s {name: 'Charlie'})" test_label)
                     |> Query_builder.return ["count(p) AS cnt"])
                    session with
            | Ok [record] ->
                (match Record.at_int record "cnt" with
                 | Ok 0L -> Format.printf "Verified: Charlie node doesn't exist (rollback worked)\n%!"
                 | Ok n -> Format.printf "Unexpected: Found %Ld Charlie nodes\n%!" n
                 | Error _ -> ())
            | _ -> ())
       | Error e -> Format.eprintf "Transaction failed: %s\n%!" (Error.to_string e));

      (* Example 4: Monadic composition with let* *)
      Format.printf "\n=== Example 4: Monadic Composition ===\n%!";

      let create_person name age =
        exec_query_builder
          (Query_builder.create_node
             (Printf.sprintf "(p:%s {name: '%s', age: %d})" test_label name age)
           |> Query_builder.return ["id(p) AS id"])
      in

      let tx4 = let* records1 = create_person "Dave" 25 in
                let* records2 = create_person "Eve" 28 in
                match records1, records2 with
                | [r1], [r2] ->
                    (match Record.at_int r1 "id", Record.at_int r2 "id" with
                     | Ok id1, Ok id2 ->
                         Format.printf "Created Dave (id=%Ld) and Eve (id=%Ld)\n%!" id1 id2;
                         return ()
                     | _ -> fail (Error.Protocol "Failed to get IDs"))
                | _ -> fail (Error.Protocol "Unexpected result") in

      (match run tx4 session with
       | Ok () -> Format.printf "Composition succeeded\n%!"
       | Error e -> Format.eprintf "Composition failed: %s\n%!" (Error.to_string e));

      (* Example 5: Applicative composition with and+ *)
      Format.printf "\n=== Example 5: Applicative Composition ===\n%!";

      let tx5 = let+ r1 = exec_query_builder
                            (Query_builder.match_ (Printf.sprintf "(p:%s {name: 'Alice'})" test_label)
                             |> Query_builder.return ["p.age AS age"])
                and+ r2 = exec_query_builder
                            (Query_builder.match_ (Printf.sprintf "(p:%s {name: 'Bob'})" test_label)
                             |> Query_builder.return ["p.age AS age"]) in
                match r1, r2 with
                | [rec1], [rec2] ->
                    (match Record.at_int rec1 "age", Record.at_int rec2 "age" with
                     | Ok age1, Ok age2 ->
                         Format.printf "Alice: %Ld, Bob: %Ld\n%!" age1 age2
                     | _ -> ())
                | _ -> () in

      (match run tx5 session with
       | Ok () -> Format.printf "Applicative composition succeeded\n%!"
       | Error e -> Format.eprintf "Applicative failed: %s\n%!" (Error.to_string e));

      (* Example 6: Error handling with catch *)
      Format.printf "\n=== Example 6: Error Handling ===\n%!";

      let tx6 = catch
                  (exec_query_builder_unit
                     (Query_builder.raw "INVALID CYPHER SYNTAX"))
                  (fun err ->
                     Format.printf "Caught error: %s\n%!" (Error.to_string err);
                     (* Create a fallback node instead *)
                     exec_query_builder_unit
                       (Query_builder.create_node
                          (Printf.sprintf "(p:%s {name: 'Fallback'})" test_label))) in

      (match run tx6 session with
       | Ok () -> Format.printf "Error handler succeeded\n%!"
       | Error e -> Format.eprintf "Error handler failed: %s\n%!" (Error.to_string e));

      (* Example 7: Conditional execution with when_ *)
      Format.printf "\n=== Example 7: Conditional Execution ===\n%!";

      let should_create = true in
      let tx7 = let* () = when_ should_create
                            (exec_query_builder_unit
                               (Query_builder.create_node
                                  (Printf.sprintf "(p:%s {name: 'Conditional'})" test_label))) in
                return () in

      (match run tx7 session with
       | Ok () -> Format.printf "Conditional execution succeeded\n%!"
       | Error e -> Format.eprintf "Conditional failed: %s\n%!" (Error.to_string e));

      (* Example 8: Iteration with iter *)
      Format.printf "\n=== Example 8: Iteration ===\n%!";

      let names = ["Grace"; "Heidi"; "Ivan"] in
      let tx8 = iter (fun name ->
                  exec_query_builder_unit
                    (Query_builder.create_node
                       (Printf.sprintf "(p:%s {name: '%s'})" test_label name))
                ) names in

      (match run tx8 session with
       | Ok () ->
           Format.printf "Created %d nodes via iteration\n%!" (List.length names)
       | Error e -> Format.eprintf "Iteration failed: %s\n%!" (Error.to_string e));

      (* Example 9: Mapping with map *)
      Format.printf "\n=== Example 9: Mapping ===\n%!";

      let ids_to_fetch = [1; 2; 3] in
      let tx9 = map (fun id ->
                  exec_query_builder
                    (Query_builder.match_ (Printf.sprintf "(p:%s)" test_label)
                     |> Query_builder.where (Printf.sprintf "id(p) = %d" id)
                     |> Query_builder.return ["p.name AS name"])
                ) ids_to_fetch in

      (match run tx9 session with
       | Ok results ->
           Format.printf "Mapped %d queries\n%!" (List.length results)
       | Error e -> Format.eprintf "Mapping failed: %s\n%!" (Error.to_string e));

      (* Example 10: Sequence operations *)
      Format.printf "\n=== Example 10: Sequence ===\n%!";

      let operations = [
        exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(p:%s {name: 'Seq1'})" test_label));
        exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(p:%s {name: 'Seq2'})" test_label));
        exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(p:%s {name: 'Seq3'})" test_label));
      ] in

      let tx10 = sequence_ operations in

      (match run tx10 session with
       | Ok () -> Format.printf "Sequence of %d operations succeeded\n%!" (List.length operations)
       | Error e -> Format.eprintf "Sequence failed: %s\n%!" (Error.to_string e));

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
