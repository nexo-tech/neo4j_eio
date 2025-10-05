open Neo4j_eio

(** Advanced query transformation pipeline examples *)

let example_aggregations session =
  Printf.printf "\nExample 1: Aggregations (sum, average, min, max)\n";

  let label = Printf.sprintf "Agg_%d" (Random.int 1000000) in

  let sum = Cypher.(
    query (Printf.sprintf "UNWIND [10, 20, 30, 40, 50] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> sum_int
    |> run_in_exn session
  ) in

  let avg = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> average_int
    |> run_in_exn session
  ) in

  let min = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> min_by Int64.compare
    |> run_in_exn session
  ) in

  let max = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> max_by Int64.compare
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Sum: %Ld, Avg: %Ld, Min: %Ld, Max: %Ld\n"
    sum avg (Option.get min) (Option.get max);
  Printf.printf "  ✓ Aggregations work!\n"

let example_sorting session =
  Printf.printf "\nExample 2: Sorting and reversing\n";

  let label = Printf.sprintf "Sort_%d" (Random.int 1000000) in

  let sorted = Cypher.(
    query (Printf.sprintf "UNWIND [5, 2, 8, 1, 9, 3] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> sort Int64.compare
    |> run_in_exn session
  ) in

  let reversed = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> sort Int64.compare
    |> reverse
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Sorted: [%s]\n" (String.concat "; " (List.map Int64.to_string sorted));
  Printf.printf "  Reversed: [%s]\n" (String.concat "; " (List.map Int64.to_string reversed));
  Printf.printf "  ✓ Sorting works!\n"

let example_chunking session =
  Printf.printf "\nExample 3: Chunking and batching\n";

  let label = Printf.sprintf "Chunk_%d" (Random.int 1000000) in

  let chunks = Cypher.(
    query (Printf.sprintf "UNWIND range(1, 10) AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> chunk 3
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Chunks of 3:\n";
  List.iter (fun chunk ->
    Printf.printf "    [%s]\n" (String.concat ", " (List.map Int64.to_string chunk))
  ) chunks;
  Printf.printf "  ✓ Chunking works!\n"

let example_take_drop_while session =
  Printf.printf "\nExample 4: Take/drop while predicates\n";

  let label = Printf.sprintf "TakeDrop_%d" (Random.int 1000000) in

  let taken = Cypher.(
    query (Printf.sprintf "UNWIND [2, 4, 6, 8, 1, 3, 5] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> take_while (fun n -> Int64.rem n 2L = 0L)
    |> run_in_exn session
  ) in

  let dropped = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> drop_while (fun n -> Int64.rem n 2L = 0L)
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Take while even: [%s]\n" (String.concat ", " (List.map Int64.to_string taken));
  Printf.printf "  Drop while even: [%s]\n" (String.concat ", " (List.map Int64.to_string dropped));
  Printf.printf "  ✓ Take/drop while works!\n"

let example_indexed session =
  Printf.printf "\nExample 5: Indexing and nth element\n";

  let label = Printf.sprintf "Index_%d" (Random.int 1000000) in

  let indexed = Cypher.(
    query (Printf.sprintf "UNWIND ['apple', 'banana', 'cherry'] AS fruit CREATE (p:%s {fruit: fruit}) RETURN p.fruit AS fruit" label)
    |> extract Extract.(text "fruit")
    |> indexed
    |> run_in_exn session
  ) in

  let second = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.fruit AS fruit" label)
    |> extract Extract.(text "fruit")
    |> nth 1
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Indexed: ";
  List.iter (fun (i, fruit) -> Printf.printf "(%d, %s) " i fruit) indexed;
  Printf.printf "\n";
  Printf.printf "  Element at index 1: %s\n" (Option.get second);
  Printf.printf "  ✓ Indexing works!\n"

let example_deduplication session =
  Printf.printf "\nExample 6: Deduplication\n";

  let label = Printf.sprintf "Dedup_%d" (Random.int 1000000) in

  let deduped = Cypher.(
    query (Printf.sprintf "UNWIND [1, 2, 2, 3, 1, 4, 3, 5, 1] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> deduplicate_by (=)
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Deduplicated: [%s]\n" (String.concat ", " (List.map Int64.to_string deduped));
  Printf.printf "  ✓ Deduplication works!\n"

let example_span_break session =
  Printf.printf "\nExample 7: Span and break\n";

  let label = Printf.sprintf "Span_%d" (Random.int 1000000) in

  let (prefix, suffix) = Cypher.(
    query (Printf.sprintf "UNWIND [2, 4, 6, 1, 3, 5] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> span (fun n -> Int64.rem n 2L = 0L)
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Span even: prefix=[%s], suffix=[%s]\n"
    (String.concat ", " (List.map Int64.to_string prefix))
    (String.concat ", " (List.map Int64.to_string suffix));
  Printf.printf "  ✓ Span/break works!\n"

let example_sliding_window session =
  Printf.printf "\nExample 8: Sliding window\n";

  let label = Printf.sprintf "Window_%d" (Random.int 1000000) in

  let windows = Cypher.(
    query (Printf.sprintf "UNWIND [1, 2, 3, 4, 5] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> sliding_window 3
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Windows of size 3:\n";
  List.iter (fun window ->
    Printf.printf "    [%s]\n" (String.concat ", " (List.map Int64.to_string window))
  ) windows;
  Printf.printf "  ✓ Sliding window works!\n"

let example_complex_pipeline session =
  Printf.printf "\nExample 9: Complex transformation pipeline\n";

  let label = Printf.sprintf "Complex_%d" (Random.int 1000000) in

  let result = Cypher.(
    query (Printf.sprintf "UNWIND range(1, 50) AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> filter (fun n -> Int64.rem n 3L = 0L)
    |> map (List.map (fun n -> Int64.mul n 2L))
    |> sort Int64.compare
    |> reverse
    |> take 5
    |> sum_int
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Pipeline: filter(divisible by 3) -> map(*2) -> sort -> reverse -> take(5) -> sum\n";
  Printf.printf "  Result: %Ld\n" result;
  Printf.printf "  ✓ Complex pipeline works!\n"

let example_reduce session =
  Printf.printf "\nExample 10: Custom reduce/fold\n";

  let label = Printf.sprintf "Reduce_%d" (Random.int 1000000) in

  let product = Cypher.(
    query (Printf.sprintf "UNWIND [2, 3, 4, 5] AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> reduce Int64.mul 1L
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Product of [2, 3, 4, 5]: %Ld\n" product;
  Printf.printf "  ✓ Custom reduce works!\n"

let () =
  Random.self_init ();
  Printf.printf "Query Transformation Pipeline Examples\n";
  Printf.printf "======================================\n";

  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
    let cfg = Config.of_env () in

    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      example_aggregations session;
      example_sorting session;
      example_chunking session;
      example_take_drop_while session;
      example_indexed session;
      example_deduplication session;
      example_span_break session;
      example_sliding_window session;
      example_complex_pipeline session;
      example_reduce session;
      Ok ()
    ) with
    | Ok () ->
        Printf.printf "\nAll transformation examples completed successfully!\n"
    | Error e ->
        Printf.eprintf "\nExecution failed: %s\n" (Error.to_string e);
        exit 1
