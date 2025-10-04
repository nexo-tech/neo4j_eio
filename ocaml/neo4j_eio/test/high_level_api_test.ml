open Neo4j_eio

(* Test the high-level API similar to hasbolt examples *)

(* Test basic query without parameters *)
let test_query env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Simple query returns values - note: currently returns flat list of values, not structured records *)
      Neo4j.query session ~statement:"RETURN 1 AS n" ()
    ) with
    | Ok values ->
        Alcotest.(check int) "got 1 value" 1 (List.length values);
        Alcotest.(check bool) "has results" true (List.length values > 0)
    | Error e ->
        Alcotest.failf "Query failed: %s" (Error.to_string e)

(* Test query with parameters using props and =: *)
let test_query_with_params env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Use props and =: helper like hasbolt *)
      let open Neo4j in
      query_p session
        ~statement:"RETURN $name AS name"
        ~parameters:(props [
          "name" =: Value.text "Alice";
        ])
        ()
    ) with
    | Ok values ->
        Alcotest.(check int) "got 1 value" 1 (List.length values);
        Alcotest.(check bool) "has results" true (List.length values > 0)
    | Error e ->
        Alcotest.failf "Query with params failed: %s" (Error.to_string e)

(* Test nested props like hasbolt example *)
let test_nested_props env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Nested props like: props ["props" =: props ["name" =: ..., "age" =: ...]] *)
      let open Neo4j in
      query_p session
        ~statement:"RETURN $props.name AS name"
        ~parameters:(props [
          "props" =: Value.map (props [
            "name" =: Value.text "Bob";
            "age" =: Value.int_of_int 25
          ])
        ])
        ()
    ) with
    | Ok values ->
        Alcotest.(check int) "got 1 value" 1 (List.length values);
        Alcotest.(check bool) "has results" true (List.length values > 0)
    | Error e ->
        Alcotest.failf "Nested props failed: %s" (Error.to_string e)

(* Test query_ that ignores results *)
let test_query_ignore_results env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Neo4j in
      (* Create a node and ignore results *)
      match query_ session
        ~statement:"CREATE (n:TestNode {id: 'test_ignore'}) RETURN n"
        () with
      | Error e -> Error e
      | Ok () ->
          (* Now verify it was created by querying *)
          match query session
            ~statement:"MATCH (n:TestNode {id: 'test_ignore'}) DELETE n RETURN count(n) AS deleted"
            () with
          | Ok records ->
              Alcotest.(check int) "found and deleted node" 1 (List.length records);
              Ok ()
          | Error e ->
              Error e
    ) with
    | Ok () ->
        Alcotest.(check bool) "test passed" true true
    | Error e ->
        Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test queryP_ with parameters and ignore results *)
let test_query_p_ignore_results env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Neo4j in
      (* Create with parameters and ignore results *)
      match query_p_ session
        ~statement:"CREATE (n:TestNode {id: $id}) RETURN n"
        ~parameters:(props ["id" =: Value.text "test_ignore_p"])
        () with
      | Error e -> Error e
      | Ok () ->
          (* Cleanup *)
          match query session
            ~statement:"MATCH (n:TestNode {id: 'test_ignore_p'}) DELETE n RETURN count(n) AS deleted"
            () with
          | Ok records ->
              Alcotest.(check int) "found and deleted node" 1 (List.length records);
              Ok ()
          | Error e ->
              Error e
    ) with
    | Ok () ->
        Alcotest.(check bool) "test passed" true true
    | Error e ->
        Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test value constructors *)
let test_value_constructors () =
  let open Value in
  (* Test basic constructors *)
  let v_null = null in
  let v_bool = bool true in
  let v_int = int 42L in
  let v_int32 = int32 100l in
  let v_int_of_int = int_of_int 50 in
  let v_float = float 3.14 in
  let v_text = text "hello" in
  let v_list = list [int 1L; int 2L; int 3L] in
  let v_map = map (Value.StringMap.add "key" (text "value") Value.StringMap.empty) in

  (* Verify they have correct types *)
  Alcotest.(check bool) "null is Null" true (match v_null with Null -> true | _ -> false);
  Alcotest.(check bool) "bool is Bool" true (match v_bool with Bool _ -> true | _ -> false);
  Alcotest.(check bool) "int is Int" true (match v_int with Int _ -> true | _ -> false);
  Alcotest.(check bool) "int32 is Int" true (match v_int32 with Int _ -> true | _ -> false);
  Alcotest.(check bool) "int_of_int is Int" true (match v_int_of_int with Int _ -> true | _ -> false);
  Alcotest.(check bool) "float is Float" true (match v_float with Float _ -> true | _ -> false);
  Alcotest.(check bool) "text is Text" true (match v_text with Text _ -> true | _ -> false);
  Alcotest.(check bool) "list is List" true (match v_list with List _ -> true | _ -> false);
  Alcotest.(check bool) "map is Map" true (match v_map with Map _ -> true | _ -> false)

let () =
  Alcotest.run "high-level API"
    [ "query functions", [
        Test_helper.require_neo4j "basic query" `Quick test_query;
        Test_helper.require_neo4j "query with params" `Quick test_query_with_params;
        Test_helper.require_neo4j "nested props" `Quick test_nested_props;
        Test_helper.require_neo4j "query_ ignore results" `Quick test_query_ignore_results;
        Test_helper.require_neo4j "query_p_ ignore results" `Quick test_query_p_ignore_results;
        Alcotest.test_case "value constructors" `Quick test_value_constructors;
      ]
    ]
