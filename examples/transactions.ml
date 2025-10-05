(** Transactions - BETTER_API Edition

    This demonstrates transaction patterns using:
    - Transaction DSL with automatic commit/rollback
    - Query Builder DSL for clean query construction
    - Monadic composition with let* syntax
*)

open Neo4j_eio

(* Example 1: Automatic COMMIT with Transaction DSL *)
let example_automatic_commit session =
  Printf.printf "Example 1: Automatic transaction commit\n";

  let label = Printf.sprintf "TxTest_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    let* records = exec_query_builder
        (Query_builder.create_node (Printf.sprintf "(n:%s {value: 42})" label)
         |> Query_builder.return ["id(n) AS node_id"]) in
    match records with
    | [record] ->
        (match Record.at_int record "node_id" with
         | Ok node_id ->
             Printf.printf "  ✓ Node created in transaction (id: %Ld)\n" node_id;
             return node_id
         | Error _ ->
             fail (Error.Protocol "Decode error"))
    | _ -> fail (Error.Protocol "Unexpected result")
  in

  (match run tx session with
   | Ok _node_id ->
       Printf.printf "  ✓ Transaction committed automatically\n";

       (* Verify node persists *)
       let verify = let* records = exec_query_builder
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.return ["count(n) AS cnt"]) in
         match records with
         | [r] ->
             (match Record.at_int r "cnt" with
              | Ok 1L ->
                  Printf.printf "  ✓ Node persisted after commit\n";
                  (* Cleanup *)
                  exec_query_builder_unit
                    (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
                     |> Query_builder.delete ["n"])
              | Ok n ->
                  Printf.printf "  ✗ Expected 1 node, got %Ld\n" n;
                  return ()
              | Error _ -> return ())
         | _ -> return ()
       in
       let _ = run verify session in ()
   | Error e -> Printf.eprintf "  ✗ Transaction failed: %s\n" (Error.to_string e))

(* Example 2: Explicit ROLLBACK *)
let example_explicit_rollback session =
  Printf.printf "\nExample 2: Explicit ROLLBACK\n";

  let label = Printf.sprintf "RollbackTest_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    let* () = exec_query_builder_unit
        (Query_builder.create_node (Printf.sprintf "(n:%s {value: 99})" label)) in
    Printf.printf "  ✓ Node created in transaction\n";

    (* Explicitly rollback *)
    let* () = rollback in
    Printf.printf "  ✓ Transaction rolled back\n";
    return ()
  in

  (match run tx session with
   | Ok () ->
       (* Verify node doesn't exist *)
       let verify = let* records = exec_query_builder
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.return ["count(n) AS cnt"]) in
         match records with
         | [r] ->
             (match Record.at_int r "cnt" with
              | Ok 0L ->
                  Printf.printf "  ✓ Node rolled back successfully\n";
                  return ()
              | Ok n ->
                  Printf.printf "  ✗ Expected 0 nodes, got %Ld\n" n;
                  return ()
              | Error _ -> return ())
         | _ -> return ()
       in
       let _ = run verify session in ()
   | Error e -> Printf.eprintf "  ✗ Error: %s\n" (Error.to_string e))

(* Example 3: Transaction DSL with automatic commit on success *)
let example_dsl_auto_commit session =
  Printf.printf "\nExample 3: Transaction DSL auto-commit on success\n";

  let label = Printf.sprintf "DslTest_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    Printf.printf "  ✓ Transaction started\n";

    let* records = exec_query_builder
        (Query_builder.create_node (Printf.sprintf "(n:%s {name: 'Alice'})" label)
         |> Query_builder.return ["n.name AS name"]) in
    match records with
    | [record] ->
        (match Record.at_text record "name" with
         | Ok name ->
             Printf.printf "  ✓ Node created: %s\n" name;
             return ()
         | Error e ->
             fail (Error.Protocol (Format.asprintf "Decode error: %a" Record.pp_decode_error e)))
    | _ -> fail (Error.Protocol "Unexpected result")
  in

  (match run tx session with
   | Ok () ->
       Printf.printf "  ✓ Transaction committed automatically\n";

       (* Verify and cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.detach_delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Transaction failed: %s\n" (Error.to_string e))

(* Example 4: Automatic rollback on failure with catch *)
let example_auto_rollback_on_error session =
  Printf.printf "\nExample 4: Auto-rollback on query error\n";

  let label = Printf.sprintf "FailTest_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    Printf.printf "  ✓ Transaction started\n";

    let* () = exec_query_builder_unit
        (Query_builder.create_node (Printf.sprintf "(n:%s {value: 123})" label)) in
    Printf.printf "  ✓ Node created\n";

    (* Intentionally cause an error *)
    exec_query_builder (Query_builder.raw "INVALID CYPHER SYNTAX")
  in

  (match run tx session with
   | Error e ->
       let err_str = Error.to_string e in
       Printf.printf "  ✓ Transaction failed (as expected): %s\n"
         (String.sub err_str 0 (min 50 (String.length err_str)));

       (* Verify node was rolled back *)
       let verify = let* records = exec_query_builder
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.return ["count(n) AS cnt"]) in
         match records with
         | [r] ->
             (match Record.at_int r "cnt" with
              | Ok 0L ->
                  Printf.printf "  ✓ Node automatically rolled back\n";
                  return ()
              | Ok n ->
                  Printf.printf "  ✗ Expected 0 nodes, got %Ld\n" n;
                  return ()
              | Error _ -> return ())
         | _ -> return ()
       in
       let _ = run verify session in ()
   | Ok _ -> Printf.printf "  ✗ Transaction should have failed\n")

(* Example 5: Multi-query transaction with monadic composition *)
let example_multi_query_transaction session =
  Printf.printf "\nExample 5: Multi-query transaction (monadic)\n";

  let label = Printf.sprintf "MultiQuery_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    Printf.printf "  ✓ Transaction started\n";

    (* Query 1: Create first node *)
    let* () = exec_query_builder_unit
        (Query_builder.create_node (Printf.sprintf "(a:%s {name: 'Alice'})" label)) in
    Printf.printf "  ✓ Created Alice\n";

    (* Query 2: Create second node *)
    let* () = exec_query_builder_unit
        (Query_builder.create_node (Printf.sprintf "(b:%s {name: 'Bob'})" label)) in
    Printf.printf "  ✓ Created Bob\n";

    (* Query 3: Create relationship *)
    let* records = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(a:%s {name: 'Alice'}), (b:%s {name: 'Bob'})" label label)
         |> Query_builder.create "(a)-[r:KNOWS]->(b)"
         |> Query_builder.return ["type(r) AS rel_type"]) in
    match records with
    | [record] ->
        (match Record.at_text record "rel_type" with
         | Ok rel_type ->
             Printf.printf "  ✓ Created relationship: %s\n" rel_type;
             return ()
         | Error e ->
             fail (Error.Protocol (Format.asprintf "Decode error: %a" Record.pp_decode_error e)))
    | _ -> fail (Error.Protocol "Unexpected result")
  in

  (match run tx session with
   | Ok () ->
       Printf.printf "  ✓ All queries committed together\n";

       (* Verify and cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.detach_delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Transaction failed: %s\n" (Error.to_string e))

(* Example 6: Explicit commit control *)
let example_explicit_commit session =
  Printf.printf "\nExample 6: Explicit COMMIT control\n";

  let label = Printf.sprintf "CommitTest_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    let* () = exec_query_builder_unit
        (Query_builder.create_node (Printf.sprintf "(n:%s {value: 'test'})" label)) in
    Printf.printf "  ✓ Node created\n";

    (* Explicitly commit *)
    let* () = commit in
    Printf.printf "  ✓ Explicitly committed\n";
    return ()
  in

  (match run tx session with
   | Ok () ->
       Printf.printf "  ✓ Transaction completed\n";

       (* Cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Error: %s\n" (Error.to_string e))

(* Example 7: Conditional commit or rollback *)
let example_conditional_commit session =
  Printf.printf "\nExample 7: Conditional commit/rollback\n";

  let label = Printf.sprintf "CondTest_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let test_scenario should_commit =
    let tx =
      let* () = exec_query_builder_unit
          (Query_builder.create_node (Printf.sprintf "(n:%s {test: true})" label)) in
      (* Decide based on condition *)
      if should_commit then commit else rollback
    in
    run tx session
  in

  (* Test rollback scenario *)
  (match test_scenario false with
   | Ok () ->
       Printf.printf "  ✓ Rollback scenario completed\n";

       (* Verify node doesn't exist *)
       let verify = let* records = exec_query_builder
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.return ["count(n) AS cnt"]) in
         match records with
         | [r] ->
             (match Record.at_int r "cnt" with
              | Ok 0L -> Printf.printf "  ✓ Node was rolled back\n"; return ()
              | Ok n -> Printf.printf "  ✗ Expected 0 nodes, got %Ld\n" n; return ()
              | Error _ -> return ())
         | _ -> return ()
       in
       let _ = run verify session in ()
   | Error e -> Printf.eprintf "  ✗ Error: %s\n" (Error.to_string e));

  (* Test commit scenario *)
  (match test_scenario true with
   | Ok () ->
       Printf.printf "  ✓ Commit scenario completed\n";

       (* Cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Error: %s\n" (Error.to_string e))

(* Example 8: Error recovery with catch *)
let example_error_recovery session =
  Printf.printf "\nExample 8: Error recovery with catch\n";

  let label = Printf.sprintf "RecoveryTest_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    catch
      (let* () = exec_query_builder_unit
           (Query_builder.create_node (Printf.sprintf "(n:%s {value: 1})" label)) in
       (* This will fail *)
       exec_query_builder_unit (Query_builder.raw "INVALID SYNTAX"))
      (fun _err ->
         Printf.printf "  ✓ Caught error, creating fallback node\n";
         (* Create fallback node instead *)
         exec_query_builder_unit
           (Query_builder.create_node (Printf.sprintf "(n:%s {value: 2, fallback: true})" label)))
  in

  (match run tx session with
   | Ok () ->
       Printf.printf "  ✓ Error recovery succeeded\n";

       (* Cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.detach_delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e))

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Transaction Patterns - BETTER_API Edition\n";
    Printf.printf "==========================================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_automatic_commit session;
        example_explicit_rollback session;
        example_dsl_auto_commit session;
        example_auto_rollback_on_error session;
        example_multi_query_transaction session;
        example_explicit_commit session;
        example_conditional_commit session;
        example_error_recovery session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All transaction examples completed!\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
