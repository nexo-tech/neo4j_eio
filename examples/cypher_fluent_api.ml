(* File: examples/cypher_fluent_api.ml *)
(* Task 3.3: Comprehensive examples of the Cypher fluent API *)

open Neo4j_eio

(* Example 1: Basic query with extraction *)
let example_basic_query session =
  Printf.printf "Example 1: Basic query with extraction\n";

  let result = Cypher.(
    query "RETURN 1 AS num, 'hello' AS text"
    |> extract Extract.(
      let+ num = int "num"
      and+ text = text "text" in
      (num, text)
    )
    |> fun q -> run q session
  ) in

  match result with
  | Ok [(num, text)] ->
      Printf.printf "  Results: num=%Ld, text=%s\n" num text;
      Printf.printf "  ✓ Basic query works!\n"
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 2: Query with parameters *)
let example_query_with_params session =
  Printf.printf "\nExample 2: Query with parameters\n";

  let result = Cypher.(
    query "RETURN $a + $b AS sum, $a * $b AS product"
    |> with_params [
      "a" =: int 7L;
      "b" =: int 6L;
    ]
    |> extract Extract.(
      let+ sum = int "sum"
      and+ product = int "product" in
      (sum, product)
    )
    |> expect_one
    |> fun q -> run q session
  ) in

  match result with
  | Ok (sum, product) ->
      Printf.printf "  Input: a=7, b=6\n";
      Printf.printf "  Results: sum=%Ld, product=%Ld\n" sum product;
      Printf.printf "  ✓ Parameters work!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 3: Creating nodes with fluent API *)
let example_create_nodes session =
  Printf.printf "\nExample 3: Creating nodes\n";

  let label = Printf.sprintf "Person_%d" (Random.int 1000000) in

  let result = Cypher.(
    query_unit (Printf.sprintf "CREATE (p:%s {name: $name, age: $age})" label)
    |> with_params (props [
      "name" =: text "Alice";
      "age" =: int 30L;
    ])
    |> fun q -> run q session
  ) in

  match result with
  | Ok () ->
      Printf.printf "  ✓ Node created successfully\n";
      (* Cleanup *)
      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> fun q -> run q session
      ) in
      Printf.printf "  ✓ Cleanup completed\n"
  | Error e ->
      Printf.eprintf "  ✗ Create failed: %s\n" (Error.to_string e)

(* Example 4: Query with expect_one combinator *)
let example_expect_one session =
  Printf.printf "\nExample 4: Using expect_one combinator\n";

  let label = Printf.sprintf "Person_%d" (Random.int 1000000) in

  (* Setup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "CREATE (p:%s {name: 'Bob', age: 25})" label)
    |> fun q -> run q session
  ) in

  let result = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age" label)
    |> extract Extract.(
      let+ name = text "name"
      and+ age = int "age" in
      (name, age)
    )
    |> expect_one
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok (name, age) ->
      Printf.printf "  Found person: %s, age %Ld\n" name age;
      Printf.printf "  ✓ expect_one works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 5: Using first combinator *)
let example_first session =
  Printf.printf "\nExample 5: Using first combinator\n";

  let label = Printf.sprintf "Item_%d" (Random.int 1000000) in

  (* Setup - create multiple nodes *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "CREATE (i:%s {id: 1}), (i2:%s {id: 2}), (i3:%s {id: 3})" label label label)
    |> fun q -> run q session
  ) in

  let result = Cypher.(
    query (Printf.sprintf "MATCH (i:%s) RETURN i.id AS id ORDER BY i.id" label)
    |> extract Extract.(int "id")
    |> first
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok (Some first_id) ->
      Printf.printf "  First ID: %Ld\n" first_id;
      Printf.printf "  ✓ first works!\n"
  | Ok None ->
      Printf.printf "  ✗ No results found\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 6: Using take combinator *)
let example_take session =
  Printf.printf "\nExample 6: Using take combinator\n";

  let result = Cypher.(
    query "UNWIND [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] AS n RETURN n"
    |> extract Extract.(int "n")
    |> take 3
    |> fun q -> run q session
  ) in

  match result with
  | Ok items ->
      Printf.printf "  Took %d items: " (List.length items);
      List.iter (fun n -> Printf.printf "%Ld " n) items;
      Printf.printf "\n  ✓ take works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 7: Using map to transform results *)
let example_map session =
  Printf.printf "\nExample 7: Using map to transform results\n";

  let result = Cypher.(
    query "UNWIND [1, 2, 3] AS n RETURN n"
    |> extract Extract.(int "n")
    |> map (List.map (fun x -> Int64.mul x 2L))
    |> fun q -> run q session
  ) in

  match result with
  | Ok doubled ->
      Printf.printf "  Doubled values: ";
      List.iter (fun n -> Printf.printf "%Ld " n) doubled;
      Printf.printf "\n  ✓ map works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 8: Using count helper *)
let example_count session =
  Printf.printf "\nExample 8: Using count helper\n";

  let label = Printf.sprintf "Counter_%d" (Random.int 1000000) in

  (* Setup *)
  let _ = List.init 7 (fun i ->
    Cypher.(
      query_unit (Printf.sprintf "CREATE (n:%s {id: %d})" label i)
      |> fun q -> run q session
    )
  ) in

  let result = Cypher.(
    query (Printf.sprintf "MATCH (n:%s) RETURN n" label)
    |> count
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok n ->
      Printf.printf "  Count: %d\n" n;
      Printf.printf "  ✓ count works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 9: Using filter to select specific results *)
let example_filter session =
  Printf.printf "\nExample 9: Using filter\n";

  let result = Cypher.(
    query "UNWIND [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] AS n RETURN n"
    |> extract Extract.(int "n")
    |> filter (fun x -> x > 5L)
    |> fun q -> run q session
  ) in

  match result with
  | Ok filtered ->
      Printf.printf "  Filtered values (> 5): ";
      List.iter (fun n -> Printf.printf "%Ld " n) filtered;
      Printf.printf "\n  ✓ filter works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 10: Using exists to check for specific values *)
let example_exists session =
  Printf.printf "\nExample 10: Using exists predicate\n";

  let result = Cypher.(
    query "UNWIND [1, 2, 3, 4, 5] AS n RETURN n"
    |> extract Extract.(int "n")
    |> exists (fun x -> x = 3L)
    |> fun q -> run q session
  ) in

  match result with
  | Ok true ->
      Printf.printf "  Found value 3 in list\n";
      Printf.printf "  ✓ exists works!\n"
  | Ok false ->
      Printf.printf "  Value 3 not found\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 11: Using find to locate specific value *)
let example_find session =
  Printf.printf "\nExample 11: Using find\n";

  let label = Printf.sprintf "Find_%d" (Random.int 1000000) in

  (* Setup *)
  let _ = List.init 10 (fun i ->
    Cypher.(
      query_unit (Printf.sprintf "CREATE (n:%s {value: %d})" label (i * 10))
      |> fun q -> run q session
    )
  ) in

  let result = Cypher.(
    query (Printf.sprintf "MATCH (n:%s) RETURN n.value AS value" label)
    |> extract Extract.(int "value")
    |> find (fun x -> x > 50L)
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok (Some value) ->
      Printf.printf "  Found first value > 50: %Ld\n" value;
      Printf.printf "  ✓ find works!\n"
  | Ok None ->
      Printf.printf "  No value found\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 12: Using partition to split results *)
let example_partition session =
  Printf.printf "\nExample 12: Using partition\n";

  let result = Cypher.(
    query "UNWIND [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] AS n RETURN n"
    |> extract Extract.(int "n")
    |> partition (fun x -> Int64.rem x 2L = 0L)
    |> fun q -> run q session
  ) in

  match result with
  | Ok (evens, odds) ->
      Printf.printf "  Even numbers: ";
      List.iter (fun n -> Printf.printf "%Ld " n) evens;
      Printf.printf "\n  Odd numbers: ";
      List.iter (fun n -> Printf.printf "%Ld " n) odds;
      Printf.printf "\n  ✓ partition works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 13: Using fold_left to aggregate *)
let example_fold session =
  Printf.printf "\nExample 13: Using fold_left\n";

  let result = Cypher.(
    query "UNWIND [1, 2, 3, 4, 5] AS n RETURN n"
    |> extract Extract.(int "n")
    |> fold_left (fun acc x -> Int64.add acc x) 0L
    |> fun q -> run q session
  ) in

  match result with
  | Ok sum ->
      Printf.printf "  Sum of 1+2+3+4+5: %Ld\n" sum;
      Printf.printf "  ✓ fold_left works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 14: Using tap for side effects *)
let example_tap session =
  Printf.printf "\nExample 14: Using tap for side effects\n";

  let counter = ref 0 in

  let result = Cypher.(
    query "UNWIND [1, 2, 3] AS n RETURN n"
    |> extract Extract.(int "n")
    |> tap (fun items -> counter := List.length items)
    |> map (List.map (fun x -> Int64.mul x 2L))
    |> fun q -> run q session
  ) in

  match result with
  | Ok doubled ->
      Printf.printf "  Side effect recorded %d items\n" !counter;
      Printf.printf "  Doubled values: ";
      List.iter (fun n -> Printf.printf "%Ld " n) doubled;
      Printf.printf "\n  ✓ tap works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 15: Using assert_non_empty *)
let example_assert_non_empty session =
  Printf.printf "\nExample 15: Using assert_non_empty\n";

  let label = Printf.sprintf "Assert_%d" (Random.int 1000000) in

  (* This should fail *)
  let empty_result = Cypher.(
    query (Printf.sprintf "MATCH (n:%s) RETURN n" label)
    |> assert_non_empty
    |> fun q -> run q session
  ) in

  (* Setup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "CREATE (n:%s {value: 1})" label)
    |> fun q -> run q session
  ) in

  (* This should succeed *)
  let non_empty_result = Cypher.(
    query (Printf.sprintf "MATCH (n:%s) RETURN n" label)
    |> assert_non_empty
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match empty_result, non_empty_result with
  | Error (Error.ClientError { code = "Client.EmptyResult"; _ }), Ok (_::_) ->
      Printf.printf "  Empty query correctly failed\n";
      Printf.printf "  Non-empty query succeeded\n";
      Printf.printf "  ✓ assert_non_empty works!\n"
  | _ ->
      Printf.printf "  ✗ Unexpected behavior\n"

(* Example 16: Using assert_count *)
let example_assert_count session =
  Printf.printf "\nExample 16: Using assert_count\n";

  let label = Printf.sprintf "Count_%d" (Random.int 1000000) in

  (* Setup - create exactly 5 nodes *)
  let _ = List.init 5 (fun i ->
    Cypher.(
      query_unit (Printf.sprintf "CREATE (n:%s {id: %d})" label i)
      |> fun q -> run q session
    )
  ) in

  let result = Cypher.(
    query (Printf.sprintf "MATCH (n:%s) RETURN n" label)
    |> assert_count 5
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok results when List.length results = 5 ->
      Printf.printf "  Assert count 5: passed\n";
      Printf.printf "  ✓ assert_count works!\n"
  | _ ->
      Printf.printf "  ✗ Unexpected result\n"

(* Example 17: Using recover for error recovery *)
let example_recover session =
  Printf.printf "\nExample 17: Using recover for error handling\n";

  let label = Printf.sprintf "Recover_%d" (Random.int 1000000) in

  (* Query that will fail but recover *)
  let result = Cypher.(
    query (Printf.sprintf "MATCH (n:%s) RETURN n" label)
    |> expect_one
    |> recover (fun _ -> Ok (Record.empty))
    |> fun q -> run q session
  ) in

  match result with
  | Ok _ ->
      Printf.printf "  Recovered from error successfully\n";
      Printf.printf "  ✓ recover works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Recovery failed: %s\n" (Error.to_string e)

(* Example 18: Complex pipeline with multiple operations *)
let example_complex_pipeline session =
  Printf.printf "\nExample 18: Complex pipeline\n";

  let label = Printf.sprintf "Pipeline_%d" (Random.int 1000000) in

  (* Setup *)
  let _ = List.init 20 (fun i ->
    Cypher.(
      query_unit (Printf.sprintf "CREATE (n:%s {value: %d})" label i)
      |> fun q -> run q session
    )
  ) in

  let result = Cypher.(
    query (Printf.sprintf "MATCH (n:%s) RETURN n.value AS value ORDER BY n.value" label)
    |> extract Extract.(int "value")
    |> filter (fun x -> x > 5L)
    |> map (List.map (fun x -> Int64.mul x 2L))
    |> take 5
    |> fold_left (fun acc x -> Int64.add acc x) 0L
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok sum ->
      Printf.printf "  Complex pipeline result: %Ld\n" sum;
      Printf.printf "  (filter > 5, double, take 5, sum)\n";
      Printf.printf "  ✓ Complex pipeline works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Pipeline failed: %s\n" (Error.to_string e)

(* Example 19: Using bind for query composition *)
let example_monadic_composition session =
  Printf.printf "\nExample 19: Query composition with bind\n";

  let label = Printf.sprintf "Monadic_%d" (Random.int 1000000) in

  (* Create nodes and retrieve names *)
  let create_alice = Cypher.(
    query_unit (Printf.sprintf "CREATE (p:%s {name: 'Alice', age: 30})" label)
    |> fun q -> run q session
  ) in

  let create_bob = match create_alice with
    | Ok () -> Cypher.(
        query_unit (Printf.sprintf "CREATE (p:%s {name: 'Bob', age: 25})" label)
        |> fun q -> run q session
      )
    | Error e -> Error e
  in

  let result = match create_bob with
    | Ok () -> Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name" label)
        |> extract Extract.(text "name")
        |> fun q -> run q session
      )
    | Error e -> Error e
  in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok names ->
      Printf.printf "  Created and retrieved: ";
      List.iter (fun name -> Printf.printf "%s " name) names;
      Printf.printf "\n  ✓ Query composition works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Composition failed: %s\n" (Error.to_string e)


(* Example 20: Using sequence to run multiple queries *)
let example_sequence session =
  Printf.printf "\nExample 20: Using sequence\n";

  let label = Printf.sprintf "Seq_%d" (Random.int 1000000) in

  let queries = List.init 3 (fun i ->
    Cypher.(
      query (Printf.sprintf "CREATE (n:%s {id: %d}) RETURN n.id AS id" label i)
      |> extract Extract.(int "id")
      |> expect_one
    )
  ) in

  let result = Cypher.(
    sequence queries
    |> fun q -> run q session
  ) in

  (* Cleanup *)
  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> fun q -> run q session
  ) in

  match result with
  | Ok ids ->
      Printf.printf "  Created nodes with IDs: ";
      List.iter (fun id -> Printf.printf "%Ld " id) ids;
      Printf.printf "\n  ✓ sequence works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Sequence failed: %s\n" (Error.to_string e)

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Cypher Fluent API Examples\n";
    Printf.printf "==========================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_basic_query session;
        example_query_with_params session;
        example_create_nodes session;
        example_expect_one session;
        example_first session;
        example_take session;
        example_map session;
        example_count session;
        example_filter session;
        example_exists session;
        example_find session;
        example_partition session;
        example_fold session;
        example_tap session;
        example_assert_non_empty session;
        example_assert_count session;
        example_recover session;
        example_complex_pipeline session;
        example_monadic_composition session;
        example_sequence session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All examples completed successfully!\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
