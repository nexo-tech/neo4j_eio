(* Integration tests for composite extractors *)

open Neo4j_eio

(* Helper to convert decode errors to Neo4j errors *)
let decode_to_error = function
  | Ok v -> Ok v
  | Error decode_err ->
      let msg = Format.asprintf "Extraction failed: %a" Record.pp_decode_error decode_err in
      Error (Error.Protocol msg)

(* Test text_int composite extractor *)
let test_text_int env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s {name: 'Alice', id: 123})" label))
        session
      in

      (* Test text_int extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.id AS id" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (text_int "name" "id") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok ("Alice", 123L) -> Ok ()
      | Ok _ -> Error (Error.Protocol "text_int test failed - wrong values")
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test text_list composite extractor *)
let test_text_list env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s {tags: ['tag1', 'tag2', 'tag3']})" label))
        session
      in

      (* Test text_list extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p.tags AS tags" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (text_list "tags") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok ["tag1"; "tag2"; "tag3"] -> Ok ()
      | Ok lst -> Error (Error.Protocol (Printf.sprintf "Expected ['tag1', 'tag2', 'tag3'], got %d items" (List.length lst)))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test int_list composite extractor *)
let test_int_list env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s {values: [10, 20, 30]})" label))
        session
      in

      (* Test int_list extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p.values AS values" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (int_list "values") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok [10L; 20L; 30L] -> Ok ()
      | _ -> Error (Error.Protocol "int_list test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test node_id composite extractor *)
let test_node_id env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s {name: 'Bob'})" label))
        session
      in

      (* Test node_id extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (node_id "p") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok id when id >= 0L -> Ok ()
      | _ -> Error (Error.Protocol "node_id test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test node_labels composite extractor *)
let test_node_labels env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup - create node with multiple labels *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s:Person:User {name: 'Charlie'})" label))
        session
      in

      (* Test node_labels extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (node_labels "p") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok labels when List.mem label labels && List.mem "Person" labels && List.mem "User" labels -> Ok ()
      | Ok labels -> Error (Error.Protocol (Printf.sprintf "Expected labels containing %s, Person, User; got %s" label (String.concat ", " labels)))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test node_props composite extractor *)
let test_node_props env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s {name: 'Dave', age: 25})" label))
        session
      in

      (* Test node_props extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (node_props "p") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok props ->
          (match Value.StringMap.find_opt "name" props, Value.StringMap.find_opt "age" props with
           | Some (Value.Text "Dave"), Some (Value.Int 25L) -> Ok ()
           | _ -> Error (Error.Protocol "node_props test failed - wrong property values"))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test rel_type and rel_id composite extractors *)
let test_relationship_extractors env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (a:%s {name: 'A'})-[r:KNOWS {since: 2020}]->(b:%s {name: 'B'})" label label))
        session
      in

      (* Test rel_type extractor *)
      let type_result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (a:%s)-[r]->(b) RETURN r" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (rel_type "r") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Test rel_id extractor *)
      let id_result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (a:%s)-[r]->(b) RETURN r" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (rel_id "r") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Test rel_props extractor *)
      let props_result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (a:%s)-[r]->(b) RETURN r" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (rel_props "r") record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label))
        session
      in

      match type_result, id_result, props_result with
      | Ok "KNOWS", Ok id, Ok props when id >= 0L ->
          (match Value.StringMap.find_opt "since" props with
           | Some (Value.Int 2020L) -> Ok ()
           | _ -> Error (Error.Protocol "rel_props test failed"))
      | _ -> Error (Error.Protocol "relationship extractors test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test pair composite extractor *)
let test_pair env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s {name: 'Eve', active: true})" label))
        session
      in

      (* Test pair extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.active AS active" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (pair "name" "active" Record.at_text Record.at_bool) record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok ("Eve", true) -> Ok ()
      | _ -> Error (Error.Protocol "pair test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test triple composite extractor *)
let test_triple env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (p:%s {name: 'Frank', age: 30, score: 95.5})" label))
        session
      in

      (* Test triple extractor *)
      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age, p.score AS score" label))
        session with
        | Ok [record] -> decode_to_error (Extract.(run (triple "name" "age" "score" Record.at_text Record.at_int Record.at_float) record))
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok ("Frank", 30L, 95.5) -> Ok ()
      | _ -> Error (Error.Protocol "triple test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Real-world example: User extraction with composite extractors *)
let test_realistic_user_extraction env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "CompTest_%d" (Random.int 1000000) in

      (* Setup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "CREATE (u:%s:User {username: 'alice123', email: 'alice@example.com', tags: ['developer', 'admin']})" label))
        session
      in

      (* Extract user data using composite extractors *)
      let extractor = Extract.(
        let+ username = text "username"
        and+ email = text "email"
        and+ tags = text_list "tags" in
        (username, email, tags)
      ) in

      let result = match Query_builder.execute
        (Query_builder.raw (Printf.sprintf "MATCH (u:%s) RETURN u.username AS username, u.email AS email, u.tags AS tags" label))
        session with
        | Ok [record] -> decode_to_error (Extract.run extractor record)
        | Ok _ -> Error (Error.Protocol "Expected single record")
        | Error e -> Error e
      in

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session
      in

      match result with
      | Ok ("alice123", "alice@example.com", ["developer"; "admin"]) -> Ok ()
      | Ok (username, email, tags) ->
          Error (Error.Protocol (Printf.sprintf "Got username=%s, email=%s, tags=[%s]" username email (String.concat ", " tags)))
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();
  let cfg = Config.of_env () in
  Alcotest.run "Composite Extractors tests" [
    "Composite extractors", [
      Alcotest.test_case "text_int" `Quick (fun () -> Eio_main.run (fun env -> test_text_int env cfg));
      Alcotest.test_case "text_list" `Quick (fun () -> Eio_main.run (fun env -> test_text_list env cfg));
      Alcotest.test_case "int_list" `Quick (fun () -> Eio_main.run (fun env -> test_int_list env cfg));
      Alcotest.test_case "node_id" `Quick (fun () -> Eio_main.run (fun env -> test_node_id env cfg));
      Alcotest.test_case "node_labels" `Quick (fun () -> Eio_main.run (fun env -> test_node_labels env cfg));
      Alcotest.test_case "node_props" `Quick (fun () -> Eio_main.run (fun env -> test_node_props env cfg));
      Alcotest.test_case "relationship_extractors" `Quick (fun () -> Eio_main.run (fun env -> test_relationship_extractors env cfg));
      Alcotest.test_case "pair" `Quick (fun () -> Eio_main.run (fun env -> test_pair env cfg));
      Alcotest.test_case "triple" `Quick (fun () -> Eio_main.run (fun env -> test_triple env cfg));
      Alcotest.test_case "realistic_user_extraction" `Quick (fun () -> Eio_main.run (fun env -> test_realistic_user_extraction env cfg));
    ];
  ]
