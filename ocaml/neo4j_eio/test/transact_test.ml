open Neo4j_eio

(* Test transact with successful action - should commit *)
let test_transact_success env cfg =
  let unique_label = Printf.sprintf "TestTransactSuccess_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Use transact to create a node *)
      match Session.transact session (fun s ->
        let create_query = Printf.sprintf "CREATE (n:%s {value: 42}) RETURN n" unique_label in
        Session.run s ~statement:create_query ()
      ) with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check bool) "node created in transaction" true (List.length records > 0);

      (* Verify node exists (transaction was committed) *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label in
      match Session.run session ~statement:match_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check bool) "node persisted after transact" true (List.length records > 0);

      (* Cleanup *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test transact with invalid Cypher - should rollback *)
let test_transact_invalid_cypher env cfg =
  let unique_label = Printf.sprintf "TestTransactInvalid_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Use transact with an action that has invalid Cypher *)
      let result = Session.transact session (fun s ->
        (* First create a node *)
        let create_query = Printf.sprintf "CREATE (n:%s {value: 42})" unique_label in
        match Session.run s ~statement:create_query () with
        | Error e -> Error e
        | Ok _ ->
            (* Then run invalid Cypher - this should fail and trigger rollback *)
            Session.run s ~statement:"INVALID CYPHER QUERY" ()
      ) in

      (* Transaction should have failed and rolled back *)
      (match result with
       | Ok _ -> Alcotest.fail "Expected transaction to fail"
       | Error _ -> ());

      (* Verify node doesn't exist (transaction was rolled back) *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label in
      match Session.run session ~statement:match_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check int) "node should not exist after rollback" 0 (List.length records);
          Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test transact with explicit error result - should rollback *)
let test_transact_explicit_error env cfg =
  let unique_label = Printf.sprintf "TestTransactExplicit_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Use transact with an action that returns Error *)
      let result = Session.transact session (fun s ->
        (* Create a node *)
        let create_query = Printf.sprintf "CREATE (n:%s {value: 42})" unique_label in
        match Session.run s ~statement:create_query () with
        | Error e -> Error e
        | Ok _ ->
            (* Explicitly return an error *)
            Error (Error.Protocol "Intentional error for testing")
      ) in

      (* Transaction should have failed and rolled back *)
      (match result with
       | Ok _ -> Alcotest.fail "Expected transaction to fail"
       | Error (Error.Protocol msg) when msg = "Intentional error for testing" -> ()
       | Error e -> Alcotest.failf "Wrong error: %s" (Error.to_string e));

      (* Verify node doesn't exist (transaction was rolled back) *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label in
      match Session.run session ~statement:match_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check int) "node should not exist after explicit error" 0 (List.length records);
          Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test nested transact - should work with proper isolation *)
let test_transact_multiple env cfg =
  let unique_label1 = Printf.sprintf "TestMulti1_%d" (Random.int 1000000) in
  let unique_label2 = Printf.sprintf "TestMulti2_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* First transaction - success *)
      match Session.transact session (fun s ->
        let create_query = Printf.sprintf "CREATE (n:%s {value: 1})" unique_label1 in
        Session.run s ~statement:create_query ()
      ) with
      | Error e -> Error e
      | Ok _ ->

      (* Second transaction - failure *)
      let _ = Session.transact session (fun s ->
        let create_query = Printf.sprintf "CREATE (n:%s {value: 2})" unique_label2 in
        match Session.run s ~statement:create_query () with
        | Error e -> Error e
        | Ok _ -> Error (Error.Protocol "Intentional rollback")
      ) in

      (* Verify first node exists, second doesn't *)
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

(* Test transact with complex operations *)
let test_transact_complex env cfg =
  let unique_label = Printf.sprintf "TestComplex_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Complex transaction with multiple operations *)
      match Session.transact session (fun s ->
        (* Create multiple nodes *)
        let create_query = Printf.sprintf "CREATE (n:%s {id: 1})" unique_label in
        match Session.run s ~statement:create_query () with
        | Error e -> Error e
        | Ok _ ->

        let create_query2 = Printf.sprintf "CREATE (n:%s {id: 2})" unique_label in
        match Session.run s ~statement:create_query2 () with
        | Error e -> Error e
        | Ok _ ->

        (* Count them *)
        let count_query = Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" unique_label in
        match Session.run s ~statement:count_query () with
        | Error e -> Error e
        | Ok records ->
            (* Verify count is 2 within transaction *)
            (match records with
             | [Value.Int n] -> Alcotest.(check int64) "count in tx" 2L n
             | _ -> Alcotest.fail "Expected count result");
            Ok ()
      ) with
      | Error e -> Error e
      | Ok () ->

      (* Verify nodes exist after commit *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n" unique_label in
      match Session.run session ~statement:match_query () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check int) "both nodes exist" 2 (List.length records);

      (* Cleanup *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DETACH DELETE n" unique_label in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();
  Alcotest.run "Transact helper tests"
    [ "transact function", [
        Test_helper.with_neo4j "transact success commits" `Quick test_transact_success;
        Test_helper.with_neo4j "transact invalid cypher rolls back" `Quick test_transact_invalid_cypher;
        Test_helper.with_neo4j "transact explicit error rolls back" `Quick test_transact_explicit_error;
        Test_helper.with_neo4j "multiple transacts work correctly" `Quick test_transact_multiple;
        Test_helper.with_neo4j "transact with complex operations" `Quick test_transact_complex;
      ]
    ]
