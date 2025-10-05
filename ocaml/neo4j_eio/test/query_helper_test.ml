(* Simple integration tests for Query_helper module *)

open Neo4j_eio

(* Test query_extract - integration test *)
let test_query_extract env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "QHTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_helper.query_unit session
        (Printf.sprintf "CREATE (p:%s {name: 'Alice', age: 30})" label)
        ()
      in

      (* Test *)
      let extractor = Extract.(
        let+ name = text "name"
        and+ age = int "age" in
        (name, age)
      ) in

      let result = Query_helper.query_extract session
        (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age" label)
        extractor
      in

      (* Cleanup *)
      let _ = Query_helper.query_unit session
        (Printf.sprintf "MATCH (n:%s) DELETE n" label) ()
      in

      match result with
      | Ok [(name, age)] when name = "Alice" && age = 30L -> Ok ()
      | Ok _ -> Error (Error.Protocol "Unexpected result")
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test query_extract_one *)
let test_query_extract_one env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "QHTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_helper.query_unit session
        (Printf.sprintf "CREATE (p:%s {value: 42})" label)
        ()
      in

      (* Test *)
      let result = Query_helper.query_extract_one session
        (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
        Extract.(int "value")
      in

      (* Cleanup *)
      let _ = Query_helper.query_unit session
        (Printf.sprintf "MATCH (n:%s) DELETE n" label) ()
      in

      match result with
      | Ok 42L -> Ok ()
      | _ -> Error (Error.Protocol "Expected 42")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test query_unit *)
let test_query_unit env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "QHTest_%d" (Random.int 1000000) in

      (* Test *)
      let result = Query_helper.query_unit session
        (Printf.sprintf "CREATE (n:%s {test: 'value'})" label)
        ()
      in

      (* Verify *)
      let count = Query_helper.query_count session
        (Printf.sprintf "MATCH (n:%s) RETURN n" label)
        ()
      in

      (* Cleanup *)
      let _ = Query_helper.query_unit session
        (Printf.sprintf "MATCH (n:%s) DELETE n" label) ()
      in

      match result, count with
      | Ok (), Ok 1 -> Ok ()
      | _ -> Error (Error.Protocol "Unit test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test transact *)
let test_transact env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "QHTest_%d" (Random.int 1000000) in

      (* Test transaction *)
      let tx_result = Query_helper.transact session (fun tx ->
        match Session.run tx
          ~statement:(Printf.sprintf "CREATE (n:%s {id: 1})" label)
          ()
        with
        | Error e -> Error e
        | Ok _ ->
            Session.run tx
              ~statement:(Printf.sprintf "CREATE (n:%s {id: 2})" label)
              ()
            |> Result.map (fun _ -> ())
      ) in

      (* Verify *)
      let count = Query_helper.query_count session
        (Printf.sprintf "MATCH (n:%s) RETURN n" label)
        ()
      in

      (* Cleanup *)
      let _ = Query_helper.query_unit session
        (Printf.sprintf "MATCH (n:%s) DELETE n" label) ()
      in

      match tx_result, count with
      | Ok (), Ok 2 -> Ok ()
      | _ -> Error (Error.Protocol "Transaction test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test batch_execute *)
let test_batch_execute env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "QHTest_%d" (Random.int 1000000) in

      (* Batch insert *)
      let param_lists = List.init 10 (fun i ->
        [("id", Value.Int (Int64.of_int i))]
      ) in

      let batch_result = Query_helper.batch_execute session
        (Printf.sprintf "CREATE (n:%s {id: $id})" label)
        ~batch_size:3
        param_lists
      in

      (* Verify *)
      let count = Query_helper.query_count session
        (Printf.sprintf "MATCH (n:%s) RETURN n" label)
        ()
      in

      (* Cleanup *)
      let _ = Query_helper.query_unit session
        (Printf.sprintf "MATCH (n:%s) DELETE n" label) ()
      in

      match batch_result, count with
      | Ok (), Ok 10 -> Ok ()
      | _ -> Error (Error.Protocol "Batch execute failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test utility functions *)
let test_utility_functions () =
  let open Query_helper in

  (* with_default *)
  (match with_default 42 (Ok (Some 10)) with
   | Ok 10 -> ()
   | _ -> Alcotest.fail "with_default Some");

  (match with_default 42 (Ok None) with
   | Ok 42 -> ()
   | _ -> Alcotest.fail "with_default None");

  (* option_to_result *)
  (match option_to_result "error" (Some 5) with
   | Ok 5 -> ()
   | _ -> Alcotest.fail "option_to_result Some");

  (match option_to_result "error" None with
   | Error "error" -> ()
   | _ -> Alcotest.fail "option_to_result None");

  (* result_to_option *)
  (match result_to_option (Ok 5) with
   | Some 5 -> ()
   | _ -> Alcotest.fail "result_to_option Ok");

  (match result_to_option (Error "err") with
   | None -> ()
   | _ -> Alcotest.fail "result_to_option Error")

let () =
  Random.self_init ();
  let cfg = Config.of_env () in
  Alcotest.run "Query_helper tests" [
    "Integration tests", [
      Alcotest.test_case "query_extract" `Quick (fun () -> Eio_main.run (fun env -> test_query_extract env cfg));
      Alcotest.test_case "query_extract_one" `Quick (fun () -> Eio_main.run (fun env -> test_query_extract_one env cfg));
      Alcotest.test_case "query_unit" `Quick (fun () -> Eio_main.run (fun env -> test_query_unit env cfg));
      Alcotest.test_case "transact" `Quick (fun () -> Eio_main.run (fun env -> test_transact env cfg));
      Alcotest.test_case "batch_execute" `Quick (fun () -> Eio_main.run (fun env -> test_batch_execute env cfg));
    ];
    "Utility functions", [
      Alcotest.test_case "utility functions" `Quick test_utility_functions;
    ];
  ]
