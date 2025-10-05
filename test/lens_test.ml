open Neo4j_eio

(** Unit tests for lens-based accessors *)

(** Test basic value prisms *)
let test_value_prisms () =
  let open Lens in

  (* Test exact_bool *)
  let bool_val = Value.Bool true in
  Alcotest.(check (option bool)) "exact_bool on Bool" (Some true) (bool_val ^. exact_bool);
  Alcotest.(check (option bool)) "exact_bool on Int" None (Value.Int 42L ^. exact_bool);

  (* Test exact_int *)
  let int_val = Value.Int 42L in
  Alcotest.(check (option int64)) "exact_int on Int" (Some 42L) (int_val ^. exact_int);
  Alcotest.(check (option int64)) "exact_int on Text" None (Value.Text "hello" ^. exact_int);

  (* Test exact_float *)
  let float_val = Value.Float 3.14 in
  Alcotest.(check (option (float 0.001))) "exact_float on Float" (Some 3.14) (float_val ^. exact_float);
  Alcotest.(check (option (float 0.001))) "exact_float on Bool" None (Value.Bool true ^. exact_float);

  (* Test exact_text *)
  let text_val = Value.Text "hello" in
  Alcotest.(check (option string)) "exact_text on Text" (Some "hello") (text_val ^. exact_text);
  Alcotest.(check (option string)) "exact_text on Int" None (Value.Int 42L ^. exact_text);

  (* Test exact_list *)
  let list_val = Value.List [Value.Int 1L; Value.Int 2L; Value.Int 3L] in
  let extracted = list_val ^. exact_list in
  Alcotest.(check bool) "exact_list extracts list" true (Option.is_some extracted);

  (* Test exact_map *)
  let map_val = Value.Map (Value.StringMap.of_seq (List.to_seq [
    ("key1", Value.Int 1L);
    ("key2", Value.Text "value");
  ])) in
  let extracted = map_val ^. exact_map in
  Alcotest.(check bool) "exact_map extracts map" true (Option.is_some extracted)

(** Test record key accessors *)
let test_record_key_access () =
  let open Lens in

  let record = Record.of_list [
    ("name", Value.Text "Alice");
    ("age", Value.Int 30L);
    ("active", Value.Bool true);
    ("score", Value.Float 95.5);
  ] in

  (* Test key access *)
  Alcotest.(check (option string)) "key name" (Some "Alice")
    (record ^. (key "name" >>> exact_text));
  Alcotest.(check (option int64)) "key age" (Some 30L)
    (record ^. (key "age" >>> exact_int));
  Alcotest.(check (option bool)) "key active" (Some true)
    (record ^. (key "active" >>> exact_bool));
  Alcotest.(check (option (float 0.001))) "key score" (Some 95.5)
    (record ^. (key "score" >>> exact_float));

  (* Test missing key *)
  Alcotest.(check (option string)) "missing key" None
    (record ^. (key "missing" >>> exact_text));

  (* Test wrong type *)
  Alcotest.(check (option string)) "wrong type" None
    (record ^. (key "age" >>> exact_text))

(** Test record field accessors *)
let test_record_field_access () =
  let open Lens in

  let record = Record.of_list [
    ("name", Value.Text "Bob");
    ("age", Value.Int 25L);
    ("verified", Value.Bool false);
    ("balance", Value.Float 1234.56);
  ] in

  (* Test typed field accessors *)
  Alcotest.(check (option string)) "field_text" (Some "Bob")
    (record ^. field_text "name");
  Alcotest.(check (option int64)) "field_int" (Some 25L)
    (record ^. field_int "age");
  Alcotest.(check (option bool)) "field_bool" (Some false)
    (record ^. field_bool "verified");
  Alcotest.(check (option (float 0.001))) "field_float" (Some 1234.56)
    (record ^. field_float "balance");

  (* Test ^! operator (unsafe access) *)
  Alcotest.(check string) "^! operator" "Bob"
    (record ^! field_text "name");

  (* Test ^! raises Not_found for missing key *)
  Alcotest.check_raises "^! raises Not_found" Not_found (fun () ->
    let _ = record ^! field_text "missing" in ()
  )

(** Test lens composition *)
let test_lens_composition () =
  let open Lens in

  (* Create a nested structure *)
  let person_props = Value.StringMap.of_seq (List.to_seq [
    ("name", Value.Text "Charlie");
    ("age", Value.Int 35L);
  ]) in
  let person_node = Value.Node {
    node_id = 123L;
    labels = ["Person"];
    props = person_props;
  } in
  let record = Record.of_list [
    ("person", person_node);
    ("status", Value.Text "active");
  ] in

  (* Compose lenses to access nested data *)
  let person_name = (key "person" >>> exact_node >>> node_prop_text "name") in
  let person_age = (key "person" >>> exact_node >>> node_prop_int "age") in

  Alcotest.(check (option string)) "composed lens for name" (Some "Charlie")
    (record ^. person_name);
  Alcotest.(check (option int64)) "composed lens for age" (Some 35L)
    (record ^. person_age)

(** Test node accessors *)
let test_node_accessors () =
  let open Lens in

  let node = Value.Node {
    node_id = 456L;
    labels = ["Person"; "Employee"];
    props = Value.StringMap.of_seq (List.to_seq [
      ("name", Value.Text "Diana");
      ("salary", Value.Int 75000L);
      ("active", Value.Bool true);
    ]);
  } in

  (* Test node_id *)
  Alcotest.(check (option int64)) "node_id" (Some 456L)
    (node ^. (exact_node >>> node_id));

  (* Test node_labels *)
  Alcotest.(check (option (list string))) "node_labels"
    (Some ["Person"; "Employee"])
    (node ^. (exact_node >>> node_labels));

  (* Test node property accessors *)
  Alcotest.(check (option string)) "node_prop_text" (Some "Diana")
    (node ^. (exact_node >>> node_prop_text "name"));
  Alcotest.(check (option int64)) "node_prop_int" (Some 75000L)
    (node ^. (exact_node >>> node_prop_int "salary"));
  Alcotest.(check (option bool)) "node_prop_bool" (Some true)
    (node ^. (exact_node >>> node_prop_bool "active"));

  (* Test missing property *)
  Alcotest.(check (option string)) "missing node prop" None
    (node ^. (exact_node >>> node_prop_text "missing"))

(** Test relationship accessors *)
let test_relationship_accessors () =
  let open Lens in

  let rel = Value.Relationship {
    rel_id = 789L;
    start_node_id = 100L;
    end_node_id = 200L;
    rel_type = "KNOWS";
    rel_props = Value.StringMap.of_seq (List.to_seq [
      ("since", Value.Int 2020L);
      ("strength", Value.Float 0.95);
    ]);
  } in

  (* Test relationship metadata *)
  Alcotest.(check (option int64)) "rel_id" (Some 789L)
    (rel ^. (exact_relationship >>> rel_id));
  Alcotest.(check (option string)) "rel_type" (Some "KNOWS")
    (rel ^. (exact_relationship >>> rel_type));
  Alcotest.(check (option int64)) "rel_start_id" (Some 100L)
    (rel ^. (exact_relationship >>> rel_start_id));
  Alcotest.(check (option int64)) "rel_end_id" (Some 200L)
    (rel ^. (exact_relationship >>> rel_end_id));

  (* Test relationship properties *)
  let since = rel ^. (exact_relationship >>> rel_prop "since" >>> exact_int) in
  Alcotest.(check (option int64)) "rel property since" (Some 2020L) since;

  let strength = rel ^. (exact_relationship >>> rel_prop "strength" >>> exact_float) in
  Alcotest.(check (option (float 0.001))) "rel property strength" (Some 0.95) strength

(** Test lens combinators *)
let test_lens_combinators () =
  let open Lens in

  let record = Record.of_list [
    ("name", Value.Text "Eve");
    ("nickname", Value.Null);
  ] in

  (* Test with_default *)
  let name_with_default = field_text "name" |> with_default "Unknown" in
  Alcotest.(check (option string)) "with_default on existing" (Some "Eve")
    (record ^. name_with_default);

  let missing_with_default = field_text "missing" |> with_default "Unknown" in
  Alcotest.(check (option string)) "with_default on missing" (Some "Unknown")
    (record ^. missing_with_default);

  (* Test try_both / <|> *)
  let name_or_nickname = field_text "missing" <|> field_text "name" in
  Alcotest.(check (option string)) "<|> fallback" (Some "Eve")
    (record ^. name_or_nickname);

  (* Test map *)
  let name_length = field_text "name" |> map String.length in
  Alcotest.(check (option int)) "map String.length" (Some 3)
    (record ^. name_length);

  let age_doubled = field_int "age" |> map (Int64.mul 2L) in
  Alcotest.(check (option int64)) "map on missing" None
    (record ^. age_doubled)

(** Test temporal type accessors *)
let test_temporal_accessors () =
  let open Lens in

  let duration = Value.Duration {
    months = 12L;
    days = 365L;
    seconds = 86400L;
    nanoseconds = 1000000L;
  } in

  let date = Value.Date { days_since_epoch = 18000L } in

  let local_time = Value.LocalTime { nanoseconds_since_midnight = 43200000000000L } in

  (* Test extraction *)
  Alcotest.(check bool) "exact_duration" true
    (Option.is_some (duration ^. exact_duration));
  Alcotest.(check bool) "exact_date" true
    (Option.is_some (date ^. exact_date));
  Alcotest.(check bool) "exact_local_time" true
    (Option.is_some (local_time ^. exact_local_time));

  (* Test wrong type *)
  Alcotest.(check bool) "duration on date" false
    (Option.is_some (date ^. exact_duration))

(** Test spatial type accessors *)
let test_spatial_accessors () =
  let open Lens in

  let point2d = Value.Point2D {
    srid = 4326L;
    x = 12.34;
    y = 56.78;
  } in

  let point3d = Value.Point3D {
    srid = 4979L;
    x = 12.34;
    y = 56.78;
    z = 100.0;
  } in

  (* Test extraction *)
  let extracted_2d = point2d ^. exact_point2d in
  Alcotest.(check bool) "exact_point2d" true (Option.is_some extracted_2d);

  let extracted_3d = point3d ^. exact_point3d in
  Alcotest.(check bool) "exact_point3d" true (Option.is_some extracted_3d);

  (* Verify SRID access through extraction *)
  match extracted_2d with
  | Some p -> Alcotest.(check int64) "point2d srid" 4326L p.srid
  | None -> Alcotest.fail "Failed to extract point2d"

(** Integration test with Neo4j *)
let test_lens_with_neo4j env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let open Lens in
      let label = Printf.sprintf "LensTest_%d" (Random.int 1000000) in

      (* Create test data *)
      let _ = Cypher.(
        query_unit (Printf.sprintf
          "CREATE (p:Person:%s {name: 'Frank', age: 40, city: 'New York'})" label)
        |> run_in session
      ) in

      (* Query and extract using lenses *)
      let result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age, p.city AS city" label)
        |> extract Extract.(
          let+ name = text "name"
          and+ age = int "age"
          and+ city = text "city" in
          (name, age, city)
        )
        |> first
        |> run_in session
      ) in

      (* Use lenses on the raw record for comparison *)
      let lens_result = Cypher.(
        query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age, p.city AS city" label)
        |> run_in session
      ) in

      let _ = Cypher.(
        query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
        |> run_in session
      ) in

      match result, lens_result with
      | Ok (Some ("Frank", 40L, "New York")), Ok records ->
          (* Verify lens extraction works on raw records *)
          (match records with
           | [record] ->
               let name = record ^. field_text "name" in
               let age = record ^. field_int "age" in
               let city = record ^. field_text "city" in
               if name = Some "Frank" && age = Some 40L && city = Some "New York" then
                 Ok ()
               else
                 Error (Error.Protocol "Lens extraction mismatch")
           | _ -> Error (Error.Protocol "Expected one record"))
      | _ -> Error (Error.Protocol "Integration test failed")
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();

  let open Alcotest in
  run "Lens Module Tests" [
    "prisms", [
      test_case "value prisms" `Quick test_value_prisms;
      test_case "temporal accessors" `Quick test_temporal_accessors;
      test_case "spatial accessors" `Quick test_spatial_accessors;
    ];
    "records", [
      test_case "record key access" `Quick test_record_key_access;
      test_case "record field access" `Quick test_record_field_access;
      test_case "lens composition" `Quick test_lens_composition;
    ];
    "nodes", [
      test_case "node accessors" `Quick test_node_accessors;
    ];
    "relationships", [
      test_case "relationship accessors" `Quick test_relationship_accessors;
    ];
    "combinators", [
      test_case "lens combinators" `Quick test_lens_combinators;
    ];
    "integration", [
      Test_helper.require_neo4j "lens with Neo4j" `Quick test_lens_with_neo4j;
    ];
  ]
