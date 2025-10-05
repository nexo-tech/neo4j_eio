open Neo4j_eio

(** Integration tests for complete pipeline workflows combining operators and transformations *)

let test_complete_etl_pipeline env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "ETL_%d" (Random.int 1000000) in

      (* Extract, Transform, Load pipeline *)
      let result = Cypher.(
        query (Printf.sprintf
          "UNWIND [{name: 'Product A', price: 100, quantity: 5},
                  {name: 'Product B', price: 50, quantity: 10},
                  {name: 'Product C', price: 200, quantity: 2}] AS p
           CREATE (prod:%s {name: p.name, price: p.price, quantity: p.quantity})
           RETURN prod.name AS name, prod.price AS price, prod.quantity AS quantity" label)
        |> extract Extract.(
          let+ name = text "name"
          and+ price = int "price"
          and+ qty = int "quantity" in
          (name, price, qty)
        )
        |> map (List.map (fun (name, price, qty) -> (name, Int64.mul price qty)))
        |> sort_by snd
        |> reverse
        |> first
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok (Some ("Product B", 500L)) -> Ok ()
      | _ -> Error (Error.Protocol "ETL pipeline test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_grouping_aggregation_pipeline env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "Group_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf
          "UNWIND [{dept: 'Sales', emp: 'Alice', salary: 50000},
                  {dept: 'Sales', emp: 'Bob', salary: 55000},
                  {dept: 'IT', emp: 'Charlie', salary: 60000},
                  {dept: 'IT', emp: 'Diana', salary: 65000}] AS e
           CREATE (emp:%s {dept: e.dept, name: e.emp, salary: e.salary})
           RETURN emp.dept AS dept, emp.salary AS salary" label)
        |> extract Extract.(
          let+ dept = text "dept"
          and+ salary = int "salary" in
          (dept, salary)
        )
        |> group_by fst
        |> map (List.map (fun (dept, salaries) ->
          let total = List.fold_left (fun acc (_, s) -> Int64.add acc s) 0L salaries in
          (dept, total)
        ))
        |> sort_by snd
        |> reverse
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [("IT", 125000L); ("Sales", 105000L)] -> Ok ()
      | _ -> Error (Error.Protocol "Grouping aggregation test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_windowing_pipeline env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "Window_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND [1, 2, 3, 4, 5] AS n CREATE (v:%s {val: n}) RETURN v.val AS val ORDER BY v.val" label)
        |> extract Extract.(int "val")
        |> sliding_window 2
        |> map (List.map (fun window ->
          List.fold_left Int64.add 0L window
        ))
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [3L; 5L; 7L; 9L] -> Ok ()
      | _ -> Error (Error.Protocol "Windowing pipeline test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_validation_filter_pipeline env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "Valid_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf
          "UNWIND [10, -5, 20, 0, 30, -10] AS n
           CREATE (v:%s {value: n})
           RETURN v.value AS value" label)
        |> extract Extract.(int "value")
        |> filter (fun n -> n > 0L)
        |> sort Int64.compare
        |> take 2
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [10L; 20L] -> Ok ()
      | _ -> Error (Error.Protocol "Validation filter test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_dedup_sort_pipeline env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "Dedup_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf
          "UNWIND ['apple', 'banana', 'apple', 'cherry', 'banana', 'date'] AS fruit
           CREATE (f:%s {name: fruit})
           RETURN f.name AS name" label)
        |> extract Extract.(text "name")
        |> deduplicate_by (=)
        |> sort String.compare
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok ["apple"; "banana"; "cherry"; "date"] -> Ok ()
      | _ -> Error (Error.Protocol "Dedup sort test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let test_batch_processing_pipeline env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "Batch_%d" (Random.int 1000000) in

      let result = Cypher.(
        query (Printf.sprintf "UNWIND range(1, 10) AS n CREATE (i:%s {id: n}) RETURN i.id AS id ORDER BY i.id" label)
        |> extract Extract.(int "id")
        |> chunk 3
        |> map (List.map List.length)
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok [3; 3; 3; 1] -> Ok ()
      | _ -> Error (Error.Protocol "Batch processing test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();

  let open Alcotest in
  run "Pipeline Integration Tests" [
    "integration", [
      Test_helper.require_neo4j "complete ETL pipeline" `Quick test_complete_etl_pipeline;
      Test_helper.require_neo4j "grouping and aggregation" `Quick test_grouping_aggregation_pipeline;
      Test_helper.require_neo4j "windowing pipeline" `Quick test_windowing_pipeline;
      Test_helper.require_neo4j "validation and filter" `Quick test_validation_filter_pipeline;
      Test_helper.require_neo4j "dedup and sort" `Quick test_dedup_sort_pipeline;
      Test_helper.require_neo4j "batch processing" `Quick test_batch_processing_pipeline;
    ];
  ]
