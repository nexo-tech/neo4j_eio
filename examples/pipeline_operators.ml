open Neo4j_eio

(** Example demonstrating the new pipeline operators introduced in Task 4.1 *)

let example_basic_pipeline session =
  Printf.printf "\nExample 1: Basic pipeline with run_in\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let result = Cypher.(
    query (Printf.sprintf "CREATE (p:%s {name: 'Alice', age: 30}) RETURN p.name AS name, p.age AS age" label)
    |> extract Extract.(
      let+ name = text "name"
      and+ age = int "age" in
      (name, age)
    )
    |> expect_one
    |> run_in session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  match result with
  | Ok (name, age) ->
      Printf.printf "  Created and retrieved: name=%s, age=%Ld\n" name age;
      Printf.printf "  ✓ Basic pipeline works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Pipeline failed: %s\n" (Error.to_string e)

let example_pipeline_operator session =
  Printf.printf "\nExample 2: Using the |>> operator\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let result = Cypher.(
    query (Printf.sprintf "UNWIND ['a', 'b', 'c', 'd', 'e'] AS letter CREATE (p:%s {letter: letter}) RETURN p.letter AS letter" label)
    |> extract Extract.(text "letter")
    |> take 3
    |>> session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  match result with
  | Ok letters ->
      Printf.printf "  First 3 letters: %s\n" (String.concat ", " letters);
      Printf.printf "  ✓ Pipeline operator works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Pipeline failed: %s\n" (Error.to_string e)

let example_execute_function session =
  Printf.printf "\nExample 3: Using the execute function\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let result = Cypher.(
    query (Printf.sprintf "UNWIND range(1, 10) AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> map (List.filter (fun v -> Int64.rem v 2L = 0L))
    |> execute session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  match result with
  | Ok evens ->
      Printf.printf "  Even numbers: %s\n" (String.concat ", " (List.map Int64.to_string evens));
      Printf.printf "  ✓ Execute function works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Execution failed: %s\n" (Error.to_string e)

let example_complex_pipeline session =
  Printf.printf "\nExample 4: Complex multi-stage pipeline\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let result = Cypher.(
    query (Printf.sprintf "UNWIND range(1, 100) AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> map (List.filter (fun v -> Int64.rem v 3L = 0L))
    |> map (List.map (fun v -> Int64.mul v 2L))
    |> take 5
    |> map (List.fold_left Int64.add 0L)
    |> run_in session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  match result with
  | Ok sum ->
      Printf.printf "  Sum of first 5 multiples of 3 (doubled): %Ld\n" sum;
      Printf.printf "  ✓ Complex pipeline works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Pipeline failed: %s\n" (Error.to_string e)

let example_exception_variants session =
  Printf.printf "\nExample 5: Using exception variants (run_in_exn, execute_exn)\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let name = Cypher.(
    query (Printf.sprintf "CREATE (p:%s {name: 'Charlie', score: 95}) RETURN p.name AS name" label)
    |> extract Extract.(text "name")
    |> expect_one
    |> run_in_exn session
  ) in

  let score = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.score AS score" label)
    |> extract Extract.(int "score")
    |> expect_one
    |> execute_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Student: %s, Score: %Ld\n" name score;
  Printf.printf "  ✓ Exception variants work!\n"

let example_pipeline_with_first session =
  Printf.printf "\nExample 6: Pipeline with first combinator\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let result = Cypher.(
    query (Printf.sprintf "UNWIND ['apple', 'banana', 'cherry'] AS fruit CREATE (p:%s {fruit: fruit}) RETURN p.fruit AS fruit ORDER BY p.fruit" label)
    |> extract Extract.(text "fruit")
    |> first
    |> run_in session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  match result with
  | Ok (Some fruit) ->
      Printf.printf "  First fruit (alphabetically): %s\n" fruit;
      Printf.printf "  ✓ Pipeline with first works!\n"
  | Ok None ->
      Printf.printf "  ✗ No fruits found\n"
  | Error e ->
      Printf.eprintf "  ✗ Pipeline failed: %s\n" (Error.to_string e)

let example_aggregation_pipeline session =
  Printf.printf "\nExample 7: Aggregation pipeline\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let stats = Cypher.(
    query (Printf.sprintf "UNWIND range(1, 20) AS n CREATE (p:%s {value: n}) RETURN p.value AS value" label)
    |> extract Extract.(int "value")
    |> map (fun values ->
      let count = List.length values in
      let sum = List.fold_left Int64.add 0L values in
      let avg = Int64.div sum (Int64.of_int count) in
      (count, sum, avg)
    )
    |> run_in session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  match stats with
  | Ok (count, sum, avg) ->
      Printf.printf "  Count: %d, Sum: %Ld, Average: %Ld\n" count sum avg;
      Printf.printf "  ✓ Aggregation pipeline works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Pipeline failed: %s\n" (Error.to_string e)

let example_filter_pipeline session =
  Printf.printf "\nExample 8: Filter and transform pipeline\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  let result = Cypher.(
    query (Printf.sprintf "UNWIND range(1, 50) AS n CREATE (p:%s {num: n}) RETURN p.num AS num" label)
    |> extract Extract.(int "num")
    |> map (List.filter (fun n -> Int64.rem n 5L = 0L))
    |> map (List.map (fun n -> Int64.to_int n))
    |> map (List.map (fun n -> n * n))
    |> take 3
    |> run_in session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  match result with
  | Ok squares ->
      Printf.printf "  Squares of first 3 multiples of 5: %s\n"
        (String.concat ", " (List.map string_of_int squares));
      Printf.printf "  ✓ Filter pipeline works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Pipeline failed: %s\n" (Error.to_string e)

let () =
  Random.self_init ();
  Printf.printf "Pipeline Operators Examples\n";
  Printf.printf "===========================\n";

  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
    let cfg = Config.of_env () in

    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      example_basic_pipeline session;
      example_pipeline_operator session;
      example_execute_function session;
      example_complex_pipeline session;
      example_exception_variants session;
      example_pipeline_with_first session;
      example_aggregation_pipeline session;
      example_filter_pipeline session;
      Ok ()
    ) with
    | Ok () ->
        Printf.printf "\nAll examples completed successfully!\n"
    | Error e ->
        Printf.eprintf "\nExecution failed: %s\n" (Error.to_string e);
        exit 1
