(* Integration tests for Cypher query builder *)

open Neo4j_eio

(* Test basic query construction and execution *)
let test_basic_query env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {name: 'Alice', age: 30})" label)
        |> fun q -> Cypher.run q session
      ) in

      (* Test basic query *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Ok [_record] -> Ok ()
      | _ -> Error (Error.Protocol "Expected one record")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test query with parameters *)
let test_query_with_params env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Create with parameters *)
      let create_result = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {name: $name, age: $age})" label)
        |> with_params ["name", Value.Text "Bob"; "age", Value.Int 25L]
        |> fun q -> Cypher.run q session
      ) in

      (* Query with parameters *)
      let query_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s {name: $name}) RETURN p" label)
        |> with_params ["name", Value.Text "Bob"]
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match create_result, query_result with
      | Ok (), Ok [_] -> Ok ()
      | _ -> Error (Error.Protocol "Query with params failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test query with extraction *)
let test_query_with_extract env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {name: 'Charlie', age: 35})" label)
        |> fun q -> Cypher.run q session
      ) in

      (* Query with extraction *)
      let extractor = Extract.(
        let+ name = text "name"
        and+ age = int "age" in
        (name, age)
      ) in

      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age" label)
        |> extract extractor
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Ok [("Charlie", 35L)] -> Ok ()
      | _ -> Error (Error.Protocol "Extraction failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test expect_one combinator *)
let test_expect_one env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {value: 42})" label)
        |> fun q -> Cypher.run q session
      ) in

      (* Test expect_one *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> expect_one
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Ok _record -> Ok ()
      | _ -> Error (Error.Protocol "expect_one failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test expect_one with no results should fail *)
let test_expect_one_no_results env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Test expect_one with no results *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> expect_one
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Error (Error.ClientError { code = "Client.NoResults"; _ }) -> Ok ()
      | _ -> Error (Error.Protocol "Expected NoResults error")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test first combinator *)
let test_first env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Setup - create multiple nodes *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {id: 1}), (p2:%s {id: 2}), (p3:%s {id: 3})" label label label)
        |> fun q -> Cypher.run q session
      ) in

      (* Test first *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p ORDER BY p.id" label)
        |> first
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Ok (Some _record) -> Ok ()
      | _ -> Error (Error.Protocol "first failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test take combinator *)
let test_take env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Setup - create multiple nodes *)
      let _ = List.init 10 (fun i ->
        Cypher.(
          query_unit (Printf.sprintf "CREATE (p:%s {id: %d})" label i)
          |> fun q -> Cypher.run q session
        )
      ) in

      (* Test take *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> take 3
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Ok records when List.length records = 3 -> Ok ()
      | Ok records -> Error (Error.Protocol (Printf.sprintf "Expected 3 records, got %d" (List.length records)))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test map combinator *)
let test_map env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {value: 5})" label)
        |> fun q -> Cypher.run q session
      ) in

      (* Test map *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> map List.length
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Ok 1 -> Ok ()
      | _ -> Error (Error.Protocol "map failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test fluent pipeline *)
let test_fluent_pipeline env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = List.init 5 (fun i ->
        Cypher.(
          query_unit (Printf.sprintf "CREATE (p:%s {name: 'Person%d', age: %d})" label i (20 + i * 10))
          |> fun q -> Cypher.run q session
        )
      ) in

      (* Test fluent pipeline *)
      let extractor = Extract.(text "name") in

      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name ORDER BY p.age" label)
        |> extract extractor
        |> take 3
        |> map (fun names -> String.concat ", " names)
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result with
      | Ok result_str when String.length result_str > 0 -> Ok ()
      | _ -> Error (Error.Protocol "Fluent pipeline failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test parameter operator =: *)
let test_param_operator env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CypherTest_%d" (Random.int 1000000) in

      (* Test using =: operator *)
      let result = Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {name: $name})" label)
        |> with_params ["name" =: Value.Text "TestName"]
        |> fun q -> Cypher.run q session
      ) in

      (* Verify *)
      let verify = Cypher.(
        query (Printf.sprintf "MATCH (p:%s {name: 'TestName'}) RETURN p" label)
        |> fun q -> Cypher.run q session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> Cypher.run q session
      ) in

      match result, verify with
      | Ok (), Ok [_] -> Ok ()
      | _ -> Error (Error.Protocol "Param operator test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();
  let cfg = Config.of_env () in
  Alcotest.run "Cypher Query Builder tests" [
    "Cypher basics", [
      Alcotest.test_case "basic_query" `Quick (fun () -> Eio_main.run (fun env -> test_basic_query env cfg));
      Alcotest.test_case "query_with_params" `Quick (fun () -> Eio_main.run (fun env -> test_query_with_params env cfg));
      Alcotest.test_case "query_with_extract" `Quick (fun () -> Eio_main.run (fun env -> test_query_with_extract env cfg));
    ];
    "Cypher combinators", [
      Alcotest.test_case "expect_one" `Quick (fun () -> Eio_main.run (fun env -> test_expect_one env cfg));
      Alcotest.test_case "expect_one_no_results" `Quick (fun () -> Eio_main.run (fun env -> test_expect_one_no_results env cfg));
      Alcotest.test_case "first" `Quick (fun () -> Eio_main.run (fun env -> test_first env cfg));
      Alcotest.test_case "take" `Quick (fun () -> Eio_main.run (fun env -> test_take env cfg));
      Alcotest.test_case "map" `Quick (fun () -> Eio_main.run (fun env -> test_map env cfg));
    ];
    "Cypher fluent API", [
      Alcotest.test_case "fluent_pipeline" `Quick (fun () -> Eio_main.run (fun env -> test_fluent_pipeline env cfg));
      Alcotest.test_case "param_operator" `Quick (fun () -> Eio_main.run (fun env -> test_param_operator env cfg));
    ];
  ]
