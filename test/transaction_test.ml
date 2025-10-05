open Neo4j_eio

(* Test create node in transaction, rollback - node should not exist *)
let test_create_rollback env cfg =
  let unique_label = Printf.sprintf "TestRollback_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Begin transaction *)
      match Session.begin_transaction session () with
      | Error e -> Error e
      | Ok () ->

      (* Create a node with unique label *)
      let create_query = Printf.sprintf "CREATE (n:%s {value: 42}) RETURN n" unique_label in
      match Session.run session ~statement:create_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check bool) "node created" true (List.length records > 0);

      (* Rollback the transaction *)
      match Session.rollback session with
      | Error e -> Error e
      | Ok () ->

      (* Verify node doesn't exist *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label in
      match Session.run session ~statement:match_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check int) "node should not exist after rollback" 0 (List.length records);
          Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test create node in transaction, commit - node should exist *)
let test_create_commit env cfg =
  let unique_label = Printf.sprintf "TestCommit_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Begin transaction *)
      match Session.begin_transaction session () with
      | Error e -> Error e
      | Ok () ->

      (* Create a node with unique label *)
      let create_query = Printf.sprintf "CREATE (n:%s {value: 42}) RETURN n" unique_label in
      match Session.run session ~statement:create_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check bool) "node created" true (List.length records > 0);

      (* Commit the transaction *)
      match Session.commit session with
      | Error e -> Error e
      | Ok () ->

      (* Verify node exists *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label in
      match Session.run session ~statement:match_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check bool) "node should exist after commit" true (List.length records > 0);

      (* Cleanup: delete the node *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test transaction with metadata *)
let test_transaction_metadata env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Begin transaction with metadata *)
      let metadata = Value.StringMap.empty
        |> Value.StringMap.add "app" (Value.Text "test")
        |> Value.StringMap.add "tx_id" (Value.Int 123L)
      in
      match Session.begin_transaction session ~metadata () with
      | Error e -> Error e
      | Ok () ->

      (* Rollback *)
      Session.rollback session
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test multiple transactions in sequence *)
let test_sequential_transactions env cfg =
  let unique_label1 = Printf.sprintf "TestSeq1_%d" (Random.int 1000000) in
  let unique_label2 = Printf.sprintf "TestSeq2_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* First transaction - commit *)
      match Session.begin_transaction session () with
      | Error e -> Error e
      | Ok () ->

      let create_query1 = Printf.sprintf "CREATE (n:%s {value: 1})" unique_label1 in
      match Session.run session ~statement:create_query1 () with
      | Error e -> Error e
      | Ok _ ->

      match Session.commit session with
      | Error e -> Error e
      | Ok () ->

      (* Second transaction - rollback *)
      match Session.begin_transaction session () with
      | Error e -> Error e
      | Ok () ->

      let create_query2 = Printf.sprintf "CREATE (n:%s {value: 2})" unique_label2 in
      match Session.run session ~statement:create_query2 () with
      | Error e -> Error e
      | Ok _ ->

      match Session.rollback session with
      | Error e -> Error e
      | Ok () ->

      (* Verify: first node exists, second doesn't *)
      let match_query1 = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label1 in
      match Session.run session ~statement:match_query1 () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check bool) "first node exists" true (List.length records > 0);

      let match_query2 = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label2 in
      match Session.run session ~statement:match_query2 () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check int) "second node doesn't exist" 0 (List.length records);

      (* Cleanup *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label1 in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();
  Alcotest.run "Transaction tests"
    [ "explicit transactions", [
        Test_helper.with_neo4j "create-rollback leaves database unchanged" `Quick test_create_rollback;
        Test_helper.with_neo4j "create-commit persists changes" `Quick test_create_commit;
        Test_helper.with_neo4j "transaction with metadata" `Quick test_transaction_metadata;
        Test_helper.with_neo4j "sequential transactions" `Quick test_sequential_transactions;
      ]
    ]
