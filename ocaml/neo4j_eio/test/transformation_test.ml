open Neo4j_eio

let test_flat_map env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "FlatMapTest_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND ['a,b', 'c,d', 'e,f'] AS s CREATE (p:%s {s: s}) RETURN p.s AS s" label)
        |> extract Extract.(text "s")
        |> flat_map (fun s -> String.split_on_char ',' s)
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok ["a"; "b"; "c"; "d"; "e"; "f"] -> Ok ()
      | _ -> Error (Error.Protocol "Flat map test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_aggregations env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "AggTest_%d" (Random.int 1000000) in

      let sum_result = Cypher.(
        query (Printf.sprintf "UNWIND [10, 20, 30, 40] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> sum_int
        |> run_in session
      ) in

      let avg_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> average_int
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match sum_result, avg_result with
      | Ok 100L, Ok 25L -> Ok ()
      | _ -> Error (Error.Protocol "Aggregation test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_sorting env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "SortTest_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND [5, 2, 8, 1, 9] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> sort Int64.compare
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [1L; 2L; 5L; 8L; 9L] -> Ok ()
      | _ -> Error (Error.Protocol "Sort test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_chunking env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "ChunkTest_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND range(1, 7) AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> chunk 3
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [[1L; 2L; 3L]; [4L; 5L; 6L]; [7L]] -> Ok ()
      | _ -> Error (Error.Protocol "Chunk test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_take_drop_while env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "TakeDropTest_%d" (Random.int 1000000) in

      let take_result = Cypher.(
        query (Printf.sprintf "UNWIND [1, 2, 3, 4, 5] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> take_while (fun n -> n < 4L)
        |> run_in session
      ) in

      let drop_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value ORDER BY p.value" label)
        |> extract Extract.(int "value")
        |> drop_while (fun n -> n < 3L)
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match take_result, drop_result with
      | Ok [1L; 2L; 3L], Ok [3L; 4L; 5L] -> Ok ()
      | _ -> Error (Error.Protocol "Take/drop while test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_indexed env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "IndexTest_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND ['a', 'b', 'c'] AS letter CREATE (p:%s {letter: letter}) RETURN p.letter AS letter" label)
        |> extract Extract.(text "letter")
        |> indexed
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [(0, "a"); (1, "b"); (2, "c")] -> Ok ()
      | _ -> Error (Error.Protocol "Indexed test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_reverse env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "ReverseTest_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND [1, 2, 3, 4, 5] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> reverse
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [5L; 4L; 3L; 2L; 1L] -> Ok ()
      | _ -> Error (Error.Protocol "Reverse test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_min_max env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "MinMaxTest_%d" (Random.int 1000000) in

      let min_result = Cypher.(
        query (Printf.sprintf "UNWIND [5, 2, 8, 1, 9] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> min_by Int64.compare
        |> run_in session
      ) in

      let max_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> max_by Int64.compare
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match min_result, max_result with
      | Ok (Some 1L), Ok (Some 9L) -> Ok ()
      | _ -> Error (Error.Protocol "Min/max test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_nth env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "NthTest_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND ['zero', 'one', 'two', 'three'] AS s CREATE (p:%s {s: s}) RETURN p.s AS s" label)
        |> extract Extract.(text "s")
        |> nth 2
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok (Some "two") -> Ok ()
      | _ -> Error (Error.Protocol "Nth test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_deduplicate env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "DedupTest_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND [1, 2, 2, 3, 1, 4, 3] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
        |> extract Extract.(int "value")
        |> deduplicate_by (=)
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [1L; 2L; 3L; 4L] -> Ok ()
      | _ -> Error (Error.Protocol "Deduplicate test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();

  let open Alcotest in
  run "Query Transformation Pipeline" [
    "transformations", [
      Test_helper.require_neo4j "flat_map" `Quick test_flat_map;
      Test_helper.require_neo4j "aggregations (sum/avg)" `Quick test_aggregations;
      Test_helper.require_neo4j "sorting" `Quick test_sorting;
      Test_helper.require_neo4j "chunking" `Quick test_chunking;
      Test_helper.require_neo4j "take_while/drop_while" `Quick test_take_drop_while;
      Test_helper.require_neo4j "indexed" `Quick test_indexed;
      Test_helper.require_neo4j "reverse" `Quick test_reverse;
      Test_helper.require_neo4j "min/max" `Quick test_min_max;
      Test_helper.require_neo4j "nth" `Quick test_nth;
      Test_helper.require_neo4j "deduplicate" `Quick test_deduplicate;
    ];
  ]
