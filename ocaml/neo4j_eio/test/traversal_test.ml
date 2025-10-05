open Neo4j_eio

(** Unit tests for traversal operations *)

(** Test basic traversal construction *)
let test_basic_traversals () =
  let open Traversal in

  (* Test each on simple list *)
  let numbers = [1; 2; 3; 4; 5] in
  Alcotest.(check (list int)) "each traversal" [1; 2; 3; 4; 5]
    (numbers ^.. each);

  (* Test filtered traversal *)
  let evens = numbers ^.. filtered (fun n -> n mod 2 = 0) in
  Alcotest.(check (list int)) "filtered evens" [2; 4] evens;

  (* Test ^? operator for first element *)
  let first = numbers ^? each in
  Alcotest.(check (option int)) "first element" (Some 1) first;

  (* Test empty list *)
  let empty = [] ^.. each in
  Alcotest.(check (list int)) "empty list" [] empty

(** Test traversal composition with lenses *)
let test_traversal_lens_composition () =
  let open Traversal in

  (* Create list of records *)
  let recs = [
    Record.of_list [("name", Value.Text "Alice"); ("age", Value.Int 30L)];
    Record.of_list [("name", Value.Text "Bob"); ("age", Value.Int 25L)];
    Record.of_list [("name", Value.Text "Charlie"); ("age", Value.Int 35L)];
  ] in

  (* Extract all names using traversal + lens *)
  let names_trav = Traversal.records >>> Lens.field_text "name" in
  let names = recs ^.. names_trav in
  Alcotest.(check (list string)) "extract names" ["Alice"; "Bob"; "Charlie"] names;

  (* Extract all ages *)
  let ages_trav = Traversal.records >>> Lens.field_int "age" in
  let ages = recs ^.. ages_trav in
  Alcotest.(check (list int64)) "extract ages" [30L; 25L; 35L] ages

(** Test fold operations *)
let test_folds () =
  let open Traversal in

  let numbers = [1L; 2L; 3L; 4L; 5L] in

  (* Test fold *)
  let sum = fold Int64.add 0L each numbers in
  Alcotest.(check int64) "fold sum" 15L sum;

  (* Test fold_right *)
  let product = fold_right Int64.mul each numbers 1L in
  Alcotest.(check int64) "fold_right product" 120L product;

  (* Test with empty list *)
  let empty_sum = fold Int64.add 0L each [] in
  Alcotest.(check int64) "fold empty" 0L empty_sum

(** Test aggregations *)
let test_aggregations () =
  let open Traversal in

  let int_values = [10L; 20L; 30L; 40L; 50L] in
  let float_values = [1.5; 2.5; 3.5; 4.5; 5.5] in

  (* Test sum_int *)
  Alcotest.(check int64) "sum_int" 150L (sum_int each int_values);

  (* Test sum_float *)
  Alcotest.(check (float 0.001)) "sum_float" 17.5 (sum_float each float_values);

  (* Test count *)
  Alcotest.(check int) "count" 5 (count each int_values);

  (* Test length *)
  Alcotest.(check int) "length" 5 (length each int_values);

  (* Test average_int *)
  Alcotest.(check (option int64)) "average_int" (Some 30L) (average_int each int_values);

  (* Test average_float *)
  let avg_f = average_float each float_values in
  Alcotest.(check (option (float 0.001))) "average_float" (Some 3.5) avg_f;

  (* Test average on empty *)
  Alcotest.(check (option int64)) "average_int empty" None (average_int each [])

(** Test min/max *)
let test_min_max () =
  let open Traversal in

  let numbers = [5L; 2L; 9L; 1L; 7L] in

  (* Test minimum *)
  Alcotest.(check (option int64)) "minimum" (Some 1L)
    (minimum Int64.compare each numbers);

  (* Test maximum *)
  Alcotest.(check (option int64)) "maximum" (Some 9L)
    (maximum Int64.compare each numbers);

  (* Test on empty *)
  Alcotest.(check (option int64)) "minimum empty" None
    (minimum Int64.compare each []);
  Alcotest.(check (option int64)) "maximum empty" None
    (maximum Int64.compare each [])

(** Test predicates *)
let test_predicates () =
  let open Traversal in

  let numbers = [1; 2; 3; 4; 5] in

  (* Test any *)
  Alcotest.(check bool) "any even" true
    (any (fun n -> n mod 2 = 0) each numbers);
  Alcotest.(check bool) "any > 10" false
    (any (fun n -> n > 10) each numbers);

  (* Test all *)
  Alcotest.(check bool) "all positive" true
    (all (fun n -> n > 0) each numbers);
  Alcotest.(check bool) "all even" false
    (all (fun n -> n mod 2 = 0) each numbers);

  (* Test none *)
  Alcotest.(check bool) "none negative" true
    (none (fun n -> n < 0) each numbers);
  Alcotest.(check bool) "none even" false
    (none (fun n -> n mod 2 = 0) each numbers);

  (* Test has *)
  Alcotest.(check bool) "has elements" true (has each numbers);
  Alcotest.(check bool) "has empty" false (has each [])

(** Test transformations *)
let test_transformations () =
  let open Traversal in

  let numbers = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10] in

  (* Test map *)
  let doubled = numbers ^.. map (fun n -> n * 2) each in
  Alcotest.(check (list int)) "map double" [2; 4; 6; 8; 10; 12; 14; 16; 18; 20] doubled;

  (* Test filter *)
  let evens = numbers ^.. filter (fun n -> n mod 2 = 0) each in
  Alcotest.(check (list int)) "filter evens" [2; 4; 6; 8; 10] evens;

  (* Test take *)
  let first_three = numbers ^.. take 3 each in
  Alcotest.(check (list int)) "take 3" [1; 2; 3] first_three;

  (* Test drop *)
  let skip_five = numbers ^.. drop 5 each in
  Alcotest.(check (list int)) "drop 5" [6; 7; 8; 9; 10] skip_five;

  (* Test take more than available *)
  let take_many = [1; 2] ^.. take 10 each in
  Alcotest.(check (list int)) "take more than length" [1; 2] take_many

(** Test head and last *)
let test_head_last () =
  let open Traversal in

  let numbers = [1; 2; 3; 4; 5] in

  (* Test head *)
  Alcotest.(check (option int)) "head" (Some 1) (head each numbers);

  (* Test last *)
  Alcotest.(check (option int)) "last" (Some 5) (last each numbers);

  (* Test on empty *)
  Alcotest.(check (option int)) "head empty" None (head each []);
  Alcotest.(check (option int)) "last empty" None (last each [])

(** Test utilities *)
let test_utilities () =
  let open Traversal in

  (* Test concat *)
  let nested = [[1; 2]; [3; 4]; [5; 6]] in
  let flattened = concat each nested in
  Alcotest.(check (list int)) "concat" [1; 2; 3; 4; 5; 6] flattened;

  (* Test concat_map *)
  let numbers = [1; 2; 3] in
  let expanded = concat_map (fun n -> [n; n * 10]) each numbers in
  Alcotest.(check (list int)) "concat_map" [1; 10; 2; 20; 3; 30] expanded;

  (* Test partition *)
  let numbers = [1; 2; 3; 4; 5; 6] in
  let (evens, odds) = partition (fun n -> n mod 2 = 0) each numbers in
  Alcotest.(check (list int)) "partition evens" [2; 4; 6] evens;
  Alcotest.(check (list int)) "partition odds" [1; 3; 5] odds

(** Test %~ operator *)
let test_modify_operator () =
  let open Traversal in

  let numbers = [1; 2; 3; 4; 5] in

  (* Test %~ to double all values *)
  let doubled = (each %~ (fun n -> n * 2)) numbers in
  Alcotest.(check (list int)) "%~ double" [2; 4; 6; 8; 10] doubled;

  (* Test filtered %~ *)
  let evens_doubled = (filtered (fun n -> n mod 2 = 0) %~ (fun n -> n * 2)) numbers in
  Alcotest.(check (list int)) "filtered %~" [4; 8] evens_doubled

(** Integration test with Neo4j *)
let test_traversal_with_neo4j env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Traversal in
      let label = Printf.sprintf "TravTest_%d" (Random.int 1000000) in

      (* Create test data *)
      let _ = Cypher.(
        query_unit (Printf.sprintf
          "UNWIND [{name: 'Alice', score: 85},
                  {name: 'Bob', score: 92},
                  {name: 'Charlie', score: 78},
                  {name: 'Diana', score: 95},
                  {name: 'Eve', score: 88}] AS person
           CREATE (p:Person:%s {name: person.name, score: person.score})" label)
        |> run_in session
      ) in

      (* Query all records *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.score AS score ORDER BY p.score DESC" label)
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result with
      | Ok records ->
          (* Test extracting all names *)
          let names_trav = Traversal.(records >>> Lens.field_text "name") in
          let names = records ^.. names_trav in

          (* Test extracting all scores *)
          let scores_trav = Traversal.(records >>> Lens.field_int "score") in
          let scores = records ^.. scores_trav in

          (* Test aggregations *)
          let score_trav = Traversal.(records >>> Lens.field_int "score") in
          let total_score = sum_int score_trav records in
          let avg_score = average_int score_trav records in
          let max_score = maximum Int64.compare score_trav records in
          let min_score = minimum Int64.compare score_trav records in

          (* Test predicates *)
          let has_high_score = any (fun s -> s >= 90L) score_trav records in
          let all_passing = all (fun s -> s >= 70L) score_trav records in

          (* Verify results *)
          if List.length names = 5 &&
             List.length scores = 5 &&
             total_score = 438L &&
             avg_score = Some 87L &&
             max_score = Some 95L &&
             min_score = Some 78L &&
             has_high_score &&
             all_passing
          then Ok ()
          else Error (Error.Protocol "Traversal integration test failed")
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(** Test composed traversals *)
let test_composed_traversals () =
  let open Traversal in

  (* Create nested structure: list of records, each with a list field *)
  let records = [
    Record.of_list [
      ("name", Value.Text "Group1");
      ("items", Value.List [Value.Int 1L; Value.Int 2L; Value.Int 3L]);
    ];
    Record.of_list [
      ("name", Value.Text "Group2");
      ("items", Value.List [Value.Int 4L; Value.Int 5L]);
    ];
  ] in

  (* Extract all items from all records *)
  let items_trav = Traversal.(records >>> Lens.field_list "items") in
  let all_items = records ^.. items_trav in

  (* This gives us a list of lists, let's flatten it *)
  let flattened = concat each all_items in

  (* Extract integers from the flattened list *)
  let int_values = List.filter_map (fun v -> Lens.(v ^. exact_int)) flattened in

  Alcotest.(check (list int64)) "composed traversals" [1L; 2L; 3L; 4L; 5L] int_values

let () =
  Random.self_init ();

  let open Alcotest in
  run "Traversal Module Tests" [
    "basic", [
      test_case "basic traversals" `Quick test_basic_traversals;
      test_case "head and last" `Quick test_head_last;
    ];
    "composition", [
      test_case "traversal lens composition" `Quick test_traversal_lens_composition;
      test_case "composed traversals" `Quick test_composed_traversals;
    ];
    "folds", [
      test_case "fold operations" `Quick test_folds;
      test_case "aggregations" `Quick test_aggregations;
      test_case "min and max" `Quick test_min_max;
    ];
    "predicates", [
      test_case "predicates" `Quick test_predicates;
    ];
    "transformations", [
      test_case "transformations" `Quick test_transformations;
      test_case "modify operator" `Quick test_modify_operator;
    ];
    "utilities", [
      test_case "utilities" `Quick test_utilities;
    ];
    "integration", [
      Test_helper.require_neo4j "traversal with Neo4j" `Quick test_traversal_with_neo4j;
    ];
  ]
