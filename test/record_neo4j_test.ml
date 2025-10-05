open Neo4j_eio

(* Test querying and decoding structured records from Neo4j *)
let test_query_with_record_decoding env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Query that returns a record-like structure *)
      match Query_builder.execute
        (Query_builder.raw "RETURN 'Alice' AS name, 30 AS age, true AS active")
        session with
      | Ok [record] ->
          (* Now the query returns records with named fields *)
          (match Value.at record "name", Value.at record "age", Value.at record "active" with
           | Some (Value.Text name), Some (Value.Int age), Some (Value.Bool active) ->
               if name = "Alice" && age = 30L && active = true then
                 Ok ()
               else
                 Error (Error.Protocol "Unexpected values")
           | _ -> Error (Error.Protocol "Unexpected value types"))
      | Ok _ -> Error (Error.Protocol "Expected single record")
      | Error e -> Error e
    ) with
    | Ok () -> ()
    | Error e -> Alcotest.failf "Query with record decoding failed: %s" (Error.to_string e)

(* Test using Record.at with values extracted from query results *)
let test_record_at_with_values () =
  let open Record in
  (* Simulate a record from a Neo4j result *)
  let record = of_list [
    ("name", Value.Text "Bob");
    ("age", Value.Int 25L);
    ("score", Value.Float 95.5);
    ("active", Value.Bool true);
  ] in

  (* Test at_text *)
  (match at_text record "name" with
   | Ok "Bob" -> ()
   | Ok s -> Alcotest.fail ("expected 'Bob', got '" ^ s ^ "'")
   | Error e -> Alcotest.fail ("at_text failed: " ^ Format.asprintf "%a" pp_decode_error e));

  (* Test at_int *)
  (match at_int record "age" with
   | Ok 25L -> ()
   | Ok n -> Alcotest.fail ("expected 25, got " ^ Int64.to_string n)
   | Error e -> Alcotest.fail ("at_int failed: " ^ Format.asprintf "%a" pp_decode_error e));

  (* Test at_float *)
  (match at_float record "score" with
   | Ok f -> Alcotest.(check (float 0.001)) "score" 95.5 f
   | Error e -> Alcotest.fail ("at_float failed: " ^ Format.asprintf "%a" pp_decode_error e));

  (* Test at_bool *)
  match at_bool record "active" with
  | Ok true -> ()
  | Ok false -> Alcotest.fail "expected true"
  | Error e -> Alcotest.fail ("at_bool failed: " ^ Format.asprintf "%a" pp_decode_error e)

(* Test maybe_at for optional fields *)
let test_maybe_at_optional_fields () =
  let open Record in
  let record = of_list [
    ("name", Value.Text "Charlie");
  ] in

  (* Field exists *)
  (match maybe_at_text record "name" with
   | Ok (Some "Charlie") -> ()
   | Ok None -> Alcotest.fail "expected Some 'Charlie'"
   | Ok (Some s) -> Alcotest.fail ("expected 'Charlie', got '" ^ s ^ "'")
   | Error e -> Alcotest.fail ("maybe_at_text failed: " ^ Format.asprintf "%a" pp_decode_error e));

  (* Field missing *)
  match maybe_at_text record "missing" with
  | Ok None -> ()
  | Ok (Some _) -> Alcotest.fail "expected None for missing field"
  | Error e -> Alcotest.fail ("maybe_at_text failed: " ^ Format.asprintf "%a" pp_decode_error e)

(* Test exact_list for decoding list values *)
let test_exact_list_from_query () =
  let open Record in
  let record = of_list [
    ("tags", Value.List [Value.Text "tag1"; Value.Text "tag2"; Value.Text "tag3"]);
  ] in

  match at_list exact_text record "tags" with
  | Ok ["tag1"; "tag2"; "tag3"] -> ()
  | Ok tags -> Alcotest.fail ("unexpected tags: " ^ String.concat ", " tags)
  | Error e -> Alcotest.fail ("at_list failed: " ^ Format.asprintf "%a" pp_decode_error e)

(* Test decode error for type mismatch *)
let test_type_mismatch_error () =
  let open Record in
  let record = of_list [
    ("name", Value.Text "Dave");
  ] in

  (* Try to decode text field as int *)
  match at_int record "name" with
  | Ok _ -> Alcotest.fail "at_int should fail on Text value"
  | Error NotInt -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ Format.asprintf "%a" pp_decode_error e)

(* Test key not found error *)
let test_key_not_found_error () =
  let open Record in
  let record = of_list [
    ("name", Value.Text "Eve");
  ] in

  match at_text record "age" with
  | Ok _ -> Alcotest.fail "at_text should fail on missing key"
  | Error (KeyNotFound "age") -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ Format.asprintf "%a" pp_decode_error e)

let () =
  Alcotest.run "Record Neo4j integration"
    [ "record decoding", [
        Test_helper.require_neo4j "query with record decoding" `Quick test_query_with_record_decoding;
        Alcotest.test_case "record at with values" `Quick test_record_at_with_values;
        Alcotest.test_case "maybe_at optional fields" `Quick test_maybe_at_optional_fields;
        Alcotest.test_case "exact_list from query" `Quick test_exact_list_from_query;
        Alcotest.test_case "type mismatch error" `Quick test_type_mismatch_error;
        Alcotest.test_case "key not found error" `Quick test_key_not_found_error;
      ];
    ]
