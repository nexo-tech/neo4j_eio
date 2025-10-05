open Neo4j_eio

(** Unit tests for transaction DSL *)

(** Test monadic composition *)
let test_monadic_composition () =
  let open Transaction_dsl in

  (* Test that bind and return compose correctly *)
  let _tx = let* x = return 10 in
            let* y = return 20 in
            return (x + y) in

  (* We can't test without a session, so just verify it compiles *)
  Alcotest.(check bool) "monadic composition compiles" true true

(** Test control flow *)
let test_control_flow () =
  let open Transaction_dsl in

  (* Test that control flow operators compile *)
  let _tx1 = let* () = when_ true (return ()) in return 42 in
  let _tx2 = let* () = unless false (return ()) in return 42 in

  Alcotest.(check bool) "control flow compiles" true true

(** Test sequence operations *)
let test_sequence_operations () =
  let open Transaction_dsl in

  (* Test that sequence operations compile *)
  let _tx1 = sequence [return 1; return 2; return 3] in
  let _tx2 = map (fun x -> return (x * 2)) [1; 2; 3] in

  Alcotest.(check bool) "sequence operations compile" true true

(** Test error handling *)
let test_error_handling () =
  let open Transaction_dsl in

  (* Test that error handling operations compile *)
  let _tx1 = catch (fail (Error.Protocol "test error")) (fun _ -> return 42) in
  let _tx2 = try_with (fail (Error.Protocol "error")) ~on_error:(return 99) in
  let _tx3 = lift_result (Ok 123) in

  Alcotest.(check bool) "error handling compiles" true true

(** Integration test: Basic transaction *)
let test_basic_transaction env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Transaction_dsl in
      let label = Printf.sprintf "TxDSL_%d" (Random.int 1000000) in

      (* Create a transaction that creates and queries a node *)
      let tx =
        let* () = exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(p:%s {name: 'Alice', age: 30})" label)) in
        let* records = exec_query_builder
          (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
           |> Query_builder.return ["p.name AS name"; "p.age AS age"]) in
        match records with
        | [record] ->
            (match Record.at_text record "name", Record.at_int record "age" with
             | Ok "Alice", Ok 30L -> return ()
             | _ -> fail (Error.Protocol "Unexpected values"))
        | _ -> fail (Error.Protocol "Expected one record")
      in

      (* Run the transaction *)
      let result = run tx session in

      (* Cleanup *)
      let cleanup_builder = Query_builder.match_ (Printf.sprintf "(p:%s)" label)
                            |> Query_builder.detach_delete ["p"] in
      let _ = Query_builder.execute_unit cleanup_builder session in

      result
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Transaction failed: %s" (Error.to_string e)

(** Integration test: Transaction rollback *)
let test_transaction_rollback env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Transaction_dsl in
      let label = Printf.sprintf "RollbackTest_%d" (Random.int 1000000) in

      (* Create a transaction that will be rolled back *)
      let tx =
        let* () = exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(p:%s {value: 99})" label)) in
        rollback
      in

      (* Run the transaction *)
      match run tx session with
      | Ok () ->
          (* Verify node doesn't exist after rollback *)
          let verify_builder = Query_builder.match_ (Printf.sprintf "(p:%s)" label)
                               |> Query_builder.return ["count(p) AS cnt"] in
          let verify = Query_builder.execute verify_builder session in
          (match verify with
           | Ok [record] ->
               (match Record.at_int record "cnt" with
                | Ok 0L -> Ok ()
                | Ok n -> Error (Error.Protocol
                            (Printf.sprintf "Expected 0 nodes, got %Ld" n))
                | Error _ -> Error (Error.Protocol "Decode error"))
           | _ -> Error (Error.Protocol "Unexpected result"))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Rollback test failed: %s" (Error.to_string e)

(** Integration test: Transaction with multiple operations *)
let test_transaction_multiple_ops env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Transaction_dsl in
      let label = Printf.sprintf "MultiOp_%d" (Random.int 1000000) in

      (* Transaction with multiple creates *)
      let tx =
        let* () = iter (fun name ->
          exec_query_builder_unit
            (Query_builder.create_node
               (Printf.sprintf "(p:%s {name: '%s'})" label name))
        ) ["Alice"; "Bob"; "Charlie"] in

        let* records = exec_query_builder
          (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
           |> Query_builder.return ["count(p) AS cnt"]) in

        match records with
        | [record] ->
            (match Record.at_int record "cnt" with
             | Ok 3L -> return ()
             | Ok n -> fail (Error.Protocol
                        (Printf.sprintf "Expected 3 nodes, got %Ld" n))
             | Error _ -> fail (Error.Protocol "Decode error"))
        | _ -> fail (Error.Protocol "Expected one record")
      in

      let result = run tx session in

      (* Cleanup *)
      let cleanup_builder = Query_builder.match_ (Printf.sprintf "(p:%s)" label)
                            |> Query_builder.detach_delete ["p"] in
      let _ = Query_builder.execute_unit cleanup_builder session in

      result
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Multi-op test failed: %s" (Error.to_string e)

(** Integration test: Transaction error handling *)
let test_transaction_error_handling env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Transaction_dsl in
      let label = Printf.sprintf "ErrorTest_%d" (Random.int 1000000) in

      (* Transaction that handles errors *)
      let tx =
        catch
          (let* () = exec_query_builder_unit
             (Query_builder.create_node
                (Printf.sprintf "(p:%s {value: 1})" label)) in
           (* Intentionally cause an error with invalid Cypher *)
           exec_query_builder_unit
             (Query_builder.raw "INVALID CYPHER SYNTAX"))
          (fun _err ->
             (* On error, create a different node *)
             exec_query_builder_unit
               (Query_builder.create_node
                  (Printf.sprintf "(p:%s {value: 2})" label)))
      in

      let result = run tx session in

      (* Cleanup *)
      let cleanup_builder = Query_builder.match_ (Printf.sprintf "(p:%s)" label)
                            |> Query_builder.detach_delete ["p"] in
      let _ = Query_builder.execute_unit cleanup_builder session in

      result
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Error handling test failed: %s" (Error.to_string e)

(** Integration test: Applicative composition *)
let test_applicative_composition env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Transaction_dsl in
      let label = Printf.sprintf "ApplicTest_%d" (Random.int 1000000) in

      let tx =
        let* () = exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(a:%s {value: 10})" label)) in
        let* () = exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(b:%s {value: 20})" label)) in

        (* Use and+ to combine queries *)
        let+ r1 = exec_query_builder
                    (Query_builder.match_ (Printf.sprintf "(a:%s {value: 10})" label)
                     |> Query_builder.return ["a.value AS v"])
        and+ r2 = exec_query_builder
                    (Query_builder.match_ (Printf.sprintf "(b:%s {value: 20})" label)
                     |> Query_builder.return ["b.value AS v"]) in

        match r1, r2 with
        | [rec1], [rec2] ->
            (match Record.at_int rec1 "v", Record.at_int rec2 "v" with
             | Ok 10L, Ok 20L -> (10L, 20L)
             | _ -> failwith "Unexpected values")
        | _ -> failwith "Unexpected result"
      in

      let result = run tx session in

      (* Cleanup *)
      let cleanup_builder = Query_builder.match_ (Printf.sprintf "(n:%s)" label)
                            |> Query_builder.detach_delete ["n"] in
      let _ = Query_builder.execute_unit cleanup_builder session in

      match result with
      | Ok (10L, 20L) -> Ok ()
      | Ok _ -> Error (Error.Protocol "Unexpected result")
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Applicative test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();

  let open Alcotest in
  run "Transaction DSL Tests" [
    "unit", [
      test_case "monadic composition" `Quick test_monadic_composition;
      test_case "control flow" `Quick test_control_flow;
      test_case "sequence operations" `Quick test_sequence_operations;
      test_case "error handling" `Quick test_error_handling;
    ];
    "integration", [
      Test_helper.require_neo4j "basic transaction" `Quick test_basic_transaction;
      Test_helper.require_neo4j "transaction rollback" `Quick test_transaction_rollback;
      Test_helper.require_neo4j "multiple operations" `Quick test_transaction_multiple_ops;
      Test_helper.require_neo4j "error handling" `Quick test_transaction_error_handling;
      Test_helper.require_neo4j "applicative composition" `Quick test_applicative_composition;
    ];
  ]
