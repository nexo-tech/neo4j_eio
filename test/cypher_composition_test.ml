(* Integration tests for Cypher composition and helper functions (Task 3.2) *)

open Neo4j_eio

(* Test parameter construction helpers *)
let test_param_helpers env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "ParamTest_%d" (Random.int 1000000) in

      (* Test using parameter construction helpers *)
      let result = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {name: $name, age: $age, active: $active})" label)
        |> with_params (props [
          "name" =: text "Test";
          "age" =: int 25L;
          "active" =: bool true
        ])
        |> fun q -> run q session
      ) in

      (* Verify *)
      let verify = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age, p.active AS active" label)
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result, verify with
      | Ok (), Ok [_] -> Ok ()
      | _ -> Error (Error.Protocol "Param helpers test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test error recovery with catch *)
let test_or_else env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "OrElseTest_%d" (Random.int 1000000) in

      (* This query will fail with NoResults error when using expect_one *)
      let failing_query = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> expect_one
        |> fun q -> run q session
      ) in

      (* This query catches the error and returns a default value *)
      let recovered_query = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> expect_one
        |> recover (fun _ -> Ok Record.empty)
        |> fun q -> run q session
      ) in

      match failing_query, recovered_query with
      | Error (Error.ClientError { code = "Client.NoResults"; _ }), Ok _ -> Ok ()
      | _ -> Error (Error.Protocol "catch test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test count helper *)
let test_count env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CountTest_%d" (Random.int 1000000) in

      (* Setup - create 5 nodes *)
      let _ = List.init 5 (fun i ->
        Cypher.(
          query_unit (Printf.sprintf "CREATE (p:%s {id: %d})" label i)
          |> fun q -> run q session
        )
      ) in

      (* Test count *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> count
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result with
      | Ok 5L -> Ok ()
      | Ok n -> Error (Error.Protocol (Printf.sprintf "Expected count 5, got %Ld" n))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test assert_non_empty *)
let test_assert_non_empty env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "AssertTest_%d" (Random.int 1000000) in

      (* Test with empty result (should fail) *)
      let empty_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> assert_non_empty
        |> fun q -> run q session
      ) in

      (* Setup one node *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {value: 1})" label)
        |> fun q -> run q session
      ) in

      (* Test with non-empty result (should succeed) *)
      let non_empty_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> assert_non_empty
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match empty_result, non_empty_result with
      | Error (Error.ClientError { code = "Client.EmptyResult"; _ }), Ok [_] -> Ok ()
      | _ -> Error (Error.Protocol "assert_non_empty test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test assert_count *)
let test_assert_count env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "AssertCountTest_%d" (Random.int 1000000) in

      (* Setup - create exactly 3 nodes *)
      let _ = List.init 3 (fun i ->
        Cypher.(
          query_unit (Printf.sprintf "CREATE (p:%s {id: %d})" label i)
          |> fun q -> run q session
        )
      ) in

      (* Test assert_count with correct count *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> assert_count 3
        |> fun q -> run q session
      ) in

      (* Test assert_count with wrong count (should fail) *)
      let wrong_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> assert_count 5
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result, wrong_result with
      | Ok _, Error (Error.ClientError { code = "Client.UnexpectedCount"; _ }) -> Ok ()
      | _ -> Error (Error.Protocol "assert_count test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test exists helper *)
let test_exists env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "ExistsTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {value: 42})" label)
        |> fun q -> run q session
      ) in

      (* Extract values and test exists *)
      let extractor = Extract.(int "value") in

      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
        |> extract extractor
        |> exists (fun x -> x = 42L)
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result with
      | Ok true -> Ok ()
      | _ -> Error (Error.Protocol "exists test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test find helper *)
let test_find env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "FindTest_%d" (Random.int 1000000) in

      (* Setup - create multiple nodes *)
      let _ = List.init 5 (fun i ->
        Cypher.(
          query_unit (Printf.sprintf "CREATE (p:%s {value: %d})" label (i * 10))
          |> fun q -> run q session
        )
      ) in

      (* Extract values and find one *)
      let extractor = Extract.(int "value") in

      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
        |> extract extractor
        |> find (fun x -> x > 25L)
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result with
      | Ok (Some x) when x > 25L -> Ok ()
      | _ -> Error (Error.Protocol "find test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test partition helper *)
let test_partition env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "PartitionTest_%d" (Random.int 1000000) in

      (* Setup - create nodes with different values *)
      let _ = List.init 10 (fun i ->
        Cypher.(
          query_unit (Printf.sprintf "CREATE (p:%s {value: %d})" label i)
          |> fun q -> run q session
        )
      ) in

      (* Extract and partition *)
      let extractor = Extract.(int "value") in

      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
        |> extract extractor
        |> partition (fun x -> x < 5L)
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result with
      | Ok (less_than_5, greater_or_equal_5) ->
          if List.length less_than_5 = 5 && List.length greater_or_equal_5 = 5 then Ok ()
          else Error (Error.Protocol (Printf.sprintf "Partition sizes: %d, %d" (List.length less_than_5) (List.length greater_or_equal_5)))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test tap for side effects *)
let test_tap env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "TapTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {value: 100})" label)
        |> fun q -> run q session
      ) in

      let side_effect_counter = ref 0 in

      (* Use tap to perform side effect *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> tap (fun _ -> incr side_effect_counter)
        |> count
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result, !side_effect_counter with
      | Ok 1L, 1 -> Ok ()
      | _ -> Error (Error.Protocol "tap test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test fold_left *)
let test_fold_left env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "FoldTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = List.init 5 (fun i ->
        Cypher.(
          query_unit (Printf.sprintf "CREATE (p:%s {value: %d})" label (i + 1))
          |> fun q -> run q session
        )
      ) in

      (* Extract and sum using fold_left *)
      let extractor = Extract.(int "value") in

      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
        |> extract extractor
        |> fold_left (fun acc x -> Int64.add acc x) 0L
        |> fun q -> run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in

      match result with
      | Ok 15L -> Ok ()  (* 1+2+3+4+5 = 15 *)
      | Ok n -> Error (Error.Protocol (Printf.sprintf "Expected 15, got %Ld" n))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();
  let cfg = Config.of_env () in
  Alcotest.run "Cypher Composition tests (Task 3.2)" [
    "Parameter helpers", [
      Alcotest.test_case "param_helpers" `Quick (fun () -> Eio_main.run (fun env -> test_param_helpers env cfg));
    ];
    "Error recovery", [
      Alcotest.test_case "or_else" `Quick (fun () -> Eio_main.run (fun env -> test_or_else env cfg));
    ];
    "Collection operations", [
      Alcotest.test_case "count" `Quick (fun () -> Eio_main.run (fun env -> test_count env cfg));
      Alcotest.test_case "exists" `Quick (fun () -> Eio_main.run (fun env -> test_exists env cfg));
      Alcotest.test_case "find" `Quick (fun () -> Eio_main.run (fun env -> test_find env cfg));
      Alcotest.test_case "partition" `Quick (fun () -> Eio_main.run (fun env -> test_partition env cfg));
      Alcotest.test_case "fold_left" `Quick (fun () -> Eio_main.run (fun env -> test_fold_left env cfg));
    ];
    "Assertions", [
      Alcotest.test_case "assert_non_empty" `Quick (fun () -> Eio_main.run (fun env -> test_assert_non_empty env cfg));
      Alcotest.test_case "assert_count" `Quick (fun () -> Eio_main.run (fun env -> test_assert_count env cfg));
    ];
    "Side effects", [
      Alcotest.test_case "tap" `Quick (fun () -> Eio_main.run (fun env -> test_tap env cfg));
    ];
  ]
