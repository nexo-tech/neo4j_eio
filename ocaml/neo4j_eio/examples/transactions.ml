(* File: examples/transactions.ml *)
(* Task 2.1: Demonstrates transaction patterns *)

open Neo4j_eio

(* Example 1: Explicit BEGIN/COMMIT/ROLLBACK *)
let example_explicit_transaction session =
  Printf.printf "Example 1: Explicit transaction with COMMIT\n";

  let label = Printf.sprintf "TxTest_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Begin transaction *)
  match Session.begin_transaction session () with
  | Error e -> Printf.eprintf "  ✗ BEGIN failed: %s\n" (Error.to_string e)
  | Ok () ->
      Printf.printf "  ✓ Transaction begun\n";

      (* Create a node within the transaction *)
      (match query session
         ~statement:(Printf.sprintf "CREATE (n:%s {value: 42}) RETURN n" label)
         () with
       | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
       | Ok [record] ->
           (match Record.at_node record "n" with
            | Ok node ->
                Printf.printf "  ✓ Node created in transaction (id: %Ld)\n" node.node_id
            | Error _ -> Printf.printf "  ✗ Decode error\n");

           (* Commit the transaction *)
           (match Session.commit session with
            | Error e -> Printf.eprintf "  ✗ COMMIT failed: %s\n" (Error.to_string e)
            | Ok () ->
                Printf.printf "  ✓ Transaction committed\n";

                (* Verify node persists *)
                (match query session
                   ~statement:(Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" label)
                   () with
                 | Ok [r] ->
                     (match Record.at_int r "cnt" with
                      | Ok 1L ->
                          Printf.printf "  ✓ Node persisted after commit\n";
                          (* Cleanup *)
                          let _ = query_ session
                            ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
                            () in ()
                      | Ok n -> Printf.printf "  ✗ Expected 1 node, got %Ld\n" n
                      | Error _ -> Printf.printf "  ✗ Decode error\n")
                 | _ -> ()))
       | _ -> ())

(* Example 2: Explicit ROLLBACK *)
let example_explicit_rollback session =
  Printf.printf "\nExample 2: Explicit transaction with ROLLBACK\n";

  let label = Printf.sprintf "RollbackTest_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Begin transaction *)
  match Session.begin_transaction session () with
  | Error e -> Printf.eprintf "  ✗ BEGIN failed: %s\n" (Error.to_string e)
  | Ok () ->
      Printf.printf "  ✓ Transaction begun\n";

      (* Create a node *)
      (match query_ session
         ~statement:(Printf.sprintf "CREATE (n:%s {value: 99})" label)
         () with
       | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
       | Ok () ->
           Printf.printf "  ✓ Node created in transaction\n";

           (* Rollback the transaction *)
           (match Session.rollback session with
            | Error e -> Printf.eprintf "  ✗ ROLLBACK failed: %s\n" (Error.to_string e)
            | Ok () ->
                Printf.printf "  ✓ Transaction rolled back\n";

                (* Verify node doesn't exist *)
                (match query session
                   ~statement:(Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" label)
                   () with
                 | Ok [r] ->
                     (match Record.at_int r "cnt" with
                      | Ok 0L -> Printf.printf "  ✓ Node rolled back successfully\n"
                      | Ok n -> Printf.printf "  ✗ Expected 0 nodes, got %Ld\n" n
                      | Error _ -> Printf.printf "  ✗ Decode error\n")
                 | _ -> ())))

(* Example 3: Using transact helper for automatic rollback on error *)
let example_transact_helper session =
  Printf.printf "\nExample 3: Using transact helper (auto-rollback on error)\n";

  let label = Printf.sprintf "TransactTest_%d" (Random.int 1000000) in

  (* Use transact - automatically commits on success *)
  match Session.transact session (fun s ->
    let open Neo4j in
    Printf.printf "  ✓ Transaction started automatically\n";

    (* Create a node *)
    match query s
      ~statement:(Printf.sprintf "CREATE (n:%s {name: 'Alice'}) RETURN n.name AS name" label)
      () with
    | Error e -> Error e
    | Ok [record] ->
        (match Record.at_text record "name" with
         | Ok name ->
             Printf.printf "  ✓ Node created: %s\n" name;
             Ok [record]
         | Error e ->
             Error (Error.Protocol (Format.asprintf "Decode error: %a" Record.pp_decode_error e)))
    | Ok _ -> Error (Error.Protocol "Unexpected result")
  ) with
  | Error e ->
      Printf.eprintf "  ✗ Transaction failed: %s\n" (Error.to_string e)
  | Ok _ ->
      Printf.printf "  ✓ Transaction committed automatically\n";

      (* Verify node exists *)
      (match Neo4j.query session
         ~statement:(Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" label)
         () with
       | Ok [r] ->
           (match Record.at_int r "cnt" with
            | Ok 1L ->
                Printf.printf "  ✓ Node persisted after transact\n";
                (* Cleanup *)
                let _ = Neo4j.query_ session
                  ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
                  () in ()
            | Ok n -> Printf.printf "  ✗ Expected 1 node, got %Ld\n" n
            | Error _ -> Printf.printf "  ✗ Decode error\n")
       | _ -> ())

(* Example 4: Transact with automatic rollback on failure *)
let example_transact_rollback session =
  Printf.printf "\nExample 4: Transact auto-rollback on query error\n";

  let label = Printf.sprintf "FailTest_%d" (Random.int 1000000) in

  (* This transaction will fail and rollback automatically *)
  match Session.transact session (fun s ->
    let open Neo4j in
    Printf.printf "  ✓ Transaction started\n";

    (* Create a node *)
    match query_ s
      ~statement:(Printf.sprintf "CREATE (n:%s {value: 123})" label)
      () with
    | Error e -> Error e
    | Ok () ->
        Printf.printf "  ✓ Node created\n";

        (* Intentionally cause an error *)
        query s ~statement:"INVALID CYPHER SYNTAX" ()
  ) with
  | Error e ->
      Printf.printf "  ✓ Transaction failed (as expected): %s\n"
        (String.sub (Error.to_string e) 0 (min 50 (String.length (Error.to_string e))));

      (* Verify node was rolled back *)
      (match Neo4j.query session
         ~statement:(Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" label)
         () with
       | Ok [r] ->
           (match Record.at_int r "cnt" with
            | Ok 0L -> Printf.printf "  ✓ Node automatically rolled back\n"
            | Ok n -> Printf.printf "  ✗ Expected 0 nodes, got %Ld\n" n
            | Error _ -> Printf.printf "  ✗ Decode error\n")
       | _ -> ())
  | Ok _ ->
      Printf.printf "  ✗ Transaction should have failed\n"

(* Example 5: Multi-query transaction *)
let example_multi_query_transaction session =
  Printf.printf "\nExample 5: Multi-query transaction\n";

  let label = Printf.sprintf "MultiQuery_%d" (Random.int 1000000) in

  match Session.transact session (fun s ->
    let open Neo4j in
    Printf.printf "  ✓ Transaction started\n";

    (* Query 1: Create first node *)
    match query_ s
      ~statement:(Printf.sprintf "CREATE (a:%s {name: 'Alice'})" label)
      () with
    | Error e -> Error e
    | Ok () ->
        Printf.printf "  ✓ Created Alice\n";

        (* Query 2: Create second node *)
        match query_ s
          ~statement:(Printf.sprintf "CREATE (b:%s {name: 'Bob'})" label)
          () with
        | Error e -> Error e
        | Ok () ->
            Printf.printf "  ✓ Created Bob\n";

            (* Query 3: Create relationship *)
            match query s
              ~statement:(Printf.sprintf
                "MATCH (a:%s {name: 'Alice'}), (b:%s {name: 'Bob'}) CREATE (a)-[r:KNOWS]->(b) RETURN type(r) AS rel_type"
                label label)
              () with
            | Error e -> Error e
            | Ok [record] ->
                (match Record.at_text record "rel_type" with
                 | Ok rel_type ->
                     Printf.printf "  ✓ Created relationship: %s\n" rel_type;
                     Ok ()
                 | Error e ->
                     Error (Error.Protocol (Format.asprintf "Decode error: %a" Record.pp_decode_error e)))
            | Ok _ -> Error (Error.Protocol "Unexpected result")
  ) with
  | Error e ->
      Printf.eprintf "  ✗ Transaction failed: %s\n" (Error.to_string e)
  | Ok () ->
      Printf.printf "  ✓ All queries committed together\n";

      (* Verify all data exists *)
      (match Neo4j.query session
         ~statement:(Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" label)
         () with
       | Ok [r] ->
           (match Record.at_int r "cnt" with
            | Ok 2L ->
                Printf.printf "  ✓ Both nodes persisted\n";
                (* Cleanup *)
                let _ = Neo4j.query_ session
                  ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
                  () in ()
            | Ok n -> Printf.printf "  ✗ Expected 2 nodes, got %Ld\n" n
            | Error _ -> Printf.printf "  ✗ Decode error\n")
       | _ -> ())

(* Example 6: Transaction with metadata *)
let example_transaction_metadata session =
  Printf.printf "\nExample 6: Transaction with metadata\n";

  let label = Printf.sprintf "MetaTest_%d" (Random.int 1000000) in

  (* Create metadata *)
  let metadata = Value.StringMap.empty
    |> Value.StringMap.add "app" (Value.Text "transaction_example")
    |> Value.StringMap.add "version" (Value.Text "1.0") in

  match Session.begin_transaction session ~metadata () with
  | Error e -> Printf.eprintf "  ✗ BEGIN with metadata failed: %s\n" (Error.to_string e)
  | Ok () ->
      Printf.printf "  ✓ Transaction begun with metadata\n";

      (match Neo4j.query_ session
         ~statement:(Printf.sprintf "CREATE (n:%s {value: 'meta'})" label)
         () with
       | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
       | Ok () ->
           (match Session.commit session with
            | Error e -> Printf.eprintf "  ✗ COMMIT failed: %s\n" (Error.to_string e)
            | Ok () ->
                Printf.printf "  ✓ Transaction with metadata committed\n";
                (* Cleanup *)
                let _ = Neo4j.query_ session
                  ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
                  () in ()))

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Transaction Patterns\n";
    Printf.printf "====================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_explicit_transaction session;
        example_explicit_rollback session;
        example_transact_helper session;
        example_transact_rollback session;
        example_multi_query_transaction session;
        example_transaction_metadata session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All transaction examples completed!\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
