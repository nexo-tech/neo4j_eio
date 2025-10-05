open Neo4j_eio

(** Unit tests for query builder DSL *)

(** Test basic query construction *)
let test_basic_query_construction () =
  let open Query_builder in

  (* Test simple MATCH RETURN *)
  let q1 = match_ "(p:Person)"
           |> return ["p.name"; "p.age"]
           |> build in
  Alcotest.(check string) "simple match return"
    {|MATCH (p:Person)
RETURN p.name, p.age|} q1;

  (* Test MATCH WHERE RETURN *)
  let q2 = match_ "(p:Person)"
           |> where "p.age > 18"
           |> return ["p.name"]
           |> build in
  Alcotest.(check string) "match where return"
    {|MATCH (p:Person)
WHERE p.age > 18
RETURN p.name|} q2;

  (* Test CREATE *)
  let q3 = create_node "(p:Person {name: 'Alice'})"
           |> build in
  Alcotest.(check string) "create node"
    "CREATE (p:Person {name: 'Alice'})" q3

(** Test WHERE clause combinations *)
let test_where_combinations () =
  let open Query_builder in

  (* Test AND conditions *)
  let q1 = match_ "(p:Person)"
           |> where "p.age > 18"
           |> and_where "p.active = true"
           |> return ["p.name"]
           |> build in
  Alcotest.(check string) "where and"
    {|MATCH (p:Person)
WHERE p.age > 18 AND p.active = true
RETURN p.name|} q1;

  (* Test multiple AND *)
  let q2 = match_ "(p:Person)"
           |> where "p.age > 18"
           |> and_where "p.active = true"
           |> and_where "p.verified = true"
           |> return ["p.name"]
           |> build in
  Alcotest.(check string) "multiple and"
    {|MATCH (p:Person)
WHERE p.age > 18 AND p.active = true AND p.verified = true
RETURN p.name|} q2

(** Test ORDER BY and LIMIT *)
let test_order_limit () =
  let open Query_builder in

  (* Test ORDER BY *)
  let q1 = match_ "(p:Person)"
           |> return ["p.name"; "p.age"]
           |> order_by "p.age"
           |> build in
  Alcotest.(check string) "order by"
    {|MATCH (p:Person)
RETURN p.name, p.age
ORDER BY p.age|} q1;

  (* Test ORDER BY DESC *)
  let q2 = match_ "(p:Person)"
           |> return ["p.name"; "p.age"]
           |> order_by_desc "p.age"
           |> build in
  Alcotest.(check string) "order by desc"
    {|MATCH (p:Person)
RETURN p.name, p.age
ORDER BY p.age DESC|} q2;

  (* Test LIMIT *)
  let q3 = match_ "(p:Person)"
           |> return ["p.name"]
           |> limit 10
           |> build in
  Alcotest.(check string) "limit"
    {|MATCH (p:Person)
RETURN p.name
LIMIT 10|} q3;

  (* Test SKIP and LIMIT *)
  let q4 = match_ "(p:Person)"
           |> return ["p.name"]
           |> order_by "p.name"
           |> skip 20
           |> limit 10
           |> build in
  Alcotest.(check string) "skip and limit"
    {|MATCH (p:Person)
RETURN p.name
ORDER BY p.name
SKIP 20
LIMIT 10|} q4

(** Test mutation queries *)
let test_mutations () =
  let open Query_builder in

  (* Test SET *)
  let q1 = match_ "(p:Person {name: 'Alice'})"
           |> set ["p.age = 31"; "p.updated = timestamp()"]
           |> build in
  Alcotest.(check string) "set"
    {|MATCH (p:Person {name: 'Alice'})
SET p.age = 31, p.updated = timestamp()|} q1;

  (* Test DELETE *)
  let q2 = match_ "(p:Person {name: 'Bob'})"
           |> delete ["p"]
           |> build in
  Alcotest.(check string) "delete"
    {|MATCH (p:Person {name: 'Bob'})
DELETE p|} q2;

  (* Test DETACH DELETE *)
  let q3 = match_ "(p:Person {name: 'Charlie'})"
           |> detach_delete ["p"]
           |> build in
  Alcotest.(check string) "detach delete"
    {|MATCH (p:Person {name: 'Charlie'})
DETACH DELETE p|} q3

(** Test MERGE and UNWIND *)
let test_merge_unwind () =
  let open Query_builder in

  (* Test MERGE *)
  let q1 = merge "(p:Person {email: 'test@example.com'})"
           |> set ["p.lastSeen = timestamp()"]
           |> build in
  Alcotest.(check string) "merge"
    {|MERGE (p:Person {email: 'test@example.com'})
SET p.lastSeen = timestamp()|} q1;

  (* Test UNWIND *)
  let q2 = unwind "[1, 2, 3]" "x"
           |> return ["x"]
           |> build in
  Alcotest.(check string) "unwind"
    {|UNWIND [1, 2, 3] AS x
RETURN x|} q2

(** Test convenience constructors *)
let test_convenience_constructors () =
  let open Query_builder in

  (* Test select *)
  let q1 = match_ "(p:Person)"
           |> where "p.active = true"
           |> return ["p.name"; "p.age"]
           |> build in
  Alcotest.(check string) "select"
    {|MATCH (p:Person)
WHERE p.active = true
RETURN p.name, p.age|} q1;

  (* Test update *)
  let q2 = update "(p:Person {id: 1})" ["p.name = 'Updated'"]
           |> build in
  Alcotest.(check string) "update"
    {|MATCH (p:Person {id: 1})
SET p.name = 'Updated'|} q2

(** Test WITH clause *)
let test_with_clause () =
  let open Query_builder in

  let q = match_ "(p:Person)"
          |> with_ ["p"; "count(*) AS friendCount"]
          |> where "friendCount > 5"
          |> return ["p.name"; "friendCount"]
          |> build in
  Alcotest.(check string) "with clause"
    {|MATCH (p:Person)
WITH p, count(*) AS friendCount
WHERE friendCount > 5
RETURN p.name, friendCount|} q

(** Test RETURN DISTINCT *)
let test_return_distinct () =
  let open Query_builder in

  let q = match_ "(p:Person)"
          |> return_distinct ["p.city"]
          |> build in
  Alcotest.(check string) "return distinct"
    {|MATCH (p:Person)
RETURN DISTINCT p.city|} q

(** Integration test with Neo4j *)
let test_query_builder_integration env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Query_builder in
      let label = Printf.sprintf "QB_%d" (Random.int 1000000) in

      (* Create test data using query builder *)
      let create_builder = create_node (Printf.sprintf "(p:%s {name: $name, age: $age})" label)
                           |> with_params [("name", Value.text "Alice"); ("age", Value.int 30L)] in
      let _ = execute_unit create_builder session in

      (* Query using query builder *)
      let select_query = match_ (Printf.sprintf "(p:%s)" label)
                         |> where "p.age >= $min_age"
                         |> return ["p.name AS name"; "p.age AS age"]
                         |> order_by_desc "p.age" in

      let result = execute
        (select_query |> with_param ("min_age", Value.int 25L))
        session in

      (* Cleanup *)
      let cleanup_builder = match_ (Printf.sprintf "(p:%s)" label)
                            |> detach_delete ["p"] in
      let _ = execute_unit cleanup_builder session in

      match result with
      | Ok [record] ->
          (match Record.at_text record "name", Record.at_int record "age" with
           | Ok "Alice", Ok 30L -> Ok ()
           | _ -> Error (Error.Protocol "Unexpected values"))
      | Ok _ -> Error (Error.Protocol "Expected one record")
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(** Test complex query composition *)
let test_complex_composition env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Query_builder in
      let label = Printf.sprintf "Complex_%d" (Random.int 1000000) in

      (* Create multiple nodes *)
      let create_builder = unwind "[{name: 'Alice', score: 85}, {name: 'Bob', score: 92}, {name: 'Charlie', score: 78}]" "person"
                           |> create (Printf.sprintf "(p:%s {name: person.name, score: person.score})" label) in
      let _ = execute_unit create_builder session in

      (* Complex query with multiple clauses *)
      let query = match_ (Printf.sprintf "(p:%s)" label)
                  |> where "p.score >= $min_score"
                  |> return ["p.name AS name"; "p.score AS score"]
                  |> order_by_desc "p.score"
                  |> limit 2
                  |> with_param ("min_score", Value.int 80L) in

      let result = execute query session in

      (* Cleanup *)
      let cleanup_builder = match_ (Printf.sprintf "(p:%s)" label)
                            |> detach_delete ["p"] in
      let _ = execute_unit cleanup_builder session in

      match result with
      | Ok records when List.length records = 2 -> Ok ()
      | Ok _ -> Error (Error.Protocol "Expected two records")
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();

  let open Alcotest in
  run "Query Builder DSL Tests" [
    "construction", [
      test_case "basic query construction" `Quick test_basic_query_construction;
      test_case "where combinations" `Quick test_where_combinations;
      test_case "order by and limit" `Quick test_order_limit;
    ];
    "mutations", [
      test_case "mutation queries" `Quick test_mutations;
      test_case "merge and unwind" `Quick test_merge_unwind;
    ];
    "advanced", [
      test_case "convenience constructors" `Quick test_convenience_constructors;
      test_case "with clause" `Quick test_with_clause;
      test_case "return distinct" `Quick test_return_distinct;
    ];
    "integration", [
      Test_helper.require_neo4j "query builder integration" `Quick test_query_builder_integration;
      Test_helper.require_neo4j "complex composition" `Quick test_complex_composition;
    ];
  ]
