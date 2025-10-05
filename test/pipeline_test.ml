open Neo4j_eio

let test_pipeline_run_in env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "PipelineTest_%d" (Random.int 1000000) in

      (* Test 1: Basic pipeline with run_in *)
      let result1 = Cypher.(
        query (Printf.sprintf "CREATE (p:%s {name: 'Alice', age: 30}) RETURN p.name AS name" label)
        |> extract Extract.(text "name")
        |> expect_one
        |> run_in session
      ) in

      (* Test 2: Pipeline with |>> operator *)
      let result2 = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age" label)
        |> extract Extract.(
          let+ name = text "name"
          and+ age = int "age" in
          (name, age)
        )
        |> expect_one
        |>> session
      ) in

      (* Test 3: Pipeline with execute *)
      let result3 = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
        |> map (fun records -> List.length records)
        |> execute session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result1, result2, result3 with
      | Ok "Alice", Ok ("Alice", 30L), Ok 1 -> Ok ()
      | _ -> Error (Error.Protocol "Pipeline operator test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_pipeline_chaining env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "PipelineChain_%d" (Random.int 1000000) in

      (* Complex pipeline demonstrating chaining *)
      let result = Cypher.(
        query (Printf.sprintf "UNWIND [1, 2, 3, 4, 5] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> map (List.filter (fun v -> v > 2L))
        |> map (List.map Int64.to_int)
        |> run_in session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [3; 4; 5] -> Ok ()
      | Ok vals -> Error (Error.ClientError {
          code = "Test.UnexpectedValue";
          message = Printf.sprintf "Expected [3; 4; 5], got %s"
            (String.concat "; " (List.map string_of_int vals))
        })
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_pipeline_with_first env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "PipelineFirst_%d" (Random.int 1000000) in

      (* Pipeline with first combinator *)
      let result = Cypher.(
        query (Printf.sprintf "UNWIND ['a', 'b', 'c'] AS letter CREATE (p:%s {letter: letter}) RETURN p.letter AS letter" label)
        |> extract Extract.(text "letter")
        |> first
        |> run_in session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok (Some "a") -> Ok ()
      | _ -> Error (Error.Protocol "Pipeline first test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_pipeline_with_take env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "PipelineTake_%d" (Random.int 1000000) in

      (* Pipeline with take combinator *)
      let result = Cypher.(
        query (Printf.sprintf "UNWIND range(1, 10) AS n CREATE (p:%s {n: n}) RETURN p.n AS n" label)
        |> extract Extract.(int "n")
        |> take 3
        |> run_in session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [1L; 2L; 3L] -> Ok ()
      | _ -> Error (Error.Protocol "Pipeline take test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_pipeline_complex env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "PipelineComplex_%d" (Random.int 1000000) in

      (* Complex multi-stage pipeline *)
      let result = Cypher.(
        query (Printf.sprintf "UNWIND range(1, 20) AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> map (List.filter (fun v -> Int64.rem v 2L = 0L))
        |> map (List.map (fun v -> Int64.mul v 2L))
        |> take 5
        |> map (List.fold_left Int64.add 0L)
        |> run_in session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok sum when sum = 60L -> Ok ()
      | Ok sum -> Error (Error.ClientError {
          code = "Test.UnexpectedSum";
          message = Printf.sprintf "Expected 60, got %Ld" sum
        })
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_pipeline_exception_variant env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "PipelineExn_%d" (Random.int 1000000) in

      (* Test run_in_exn variant *)
      let name = Cypher.(
        query (Printf.sprintf "CREATE (p:%s {name: 'Bob'}) RETURN p.name AS name" label)
        |> extract Extract.(text "name")
        |> expect_one
        |> run_in_exn session
      ) in

      (* Test execute_exn variant *)
      let count = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN count(p) AS count" label)
        |> extract Extract.(int "count")
        |> expect_one
        |> execute_exn session
      ) in

      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      if name = "Bob" && count = 1L then Ok ()
      else Error (Error.Protocol "Exception variant test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();

  let open Alcotest in
  run "Pipeline Operators" [
    "pipeline_operators", [
      Test_helper.require_neo4j "run_in and |>> operators" `Quick test_pipeline_run_in;
      Test_helper.require_neo4j "pipeline chaining" `Quick test_pipeline_chaining;
      Test_helper.require_neo4j "pipeline with first" `Quick test_pipeline_with_first;
      Test_helper.require_neo4j "pipeline with take" `Quick test_pipeline_with_take;
      Test_helper.require_neo4j "complex multi-stage pipeline" `Quick test_pipeline_complex;
      Test_helper.require_neo4j "exception variants" `Quick test_pipeline_exception_variant;
    ];
  ]
