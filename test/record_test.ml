open Neo4j_eio

let show_error e = Format.asprintf "%a" Record.pp_decode_error e

(* Test exact decoders *)
let test_exact_unit () =
  let open Record in
  (match exact_unit Value.Null with
   | Ok () -> ()
   | Error e -> Alcotest.fail ("exact_unit failed: " ^ show_error e));

  match exact_unit (Value.Bool true) with
  | Ok () -> Alcotest.fail "exact_unit should fail on Bool"
  | Error NotNull -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

let test_exact_bool () =
  let open Record in
  (match exact_bool (Value.Bool true) with
   | Ok true -> ()
   | Ok false -> Alcotest.fail "expected true"
   | Error e -> Alcotest.fail ("exact_bool failed: " ^ show_error e));

  match exact_bool Value.Null with
  | Ok _ -> Alcotest.fail "exact_bool should fail on Null"
  | Error NotBool -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

let test_exact_int () =
  let open Record in
  (match exact_int (Value.Int 42L) with
   | Ok 42L -> ()
   | Ok n -> Alcotest.fail ("expected 42, got " ^ Int64.to_string n)
   | Error e -> Alcotest.fail ("exact_int failed: " ^ show_error e));

  match exact_int (Value.Text "hello") with
  | Ok _ -> Alcotest.fail "exact_int should fail on Text"
  | Error NotInt -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

let test_exact_float () =
  let open Record in
  (match exact_float (Value.Float 3.14) with
   | Ok f -> Alcotest.(check (float 0.001)) "float value" 3.14 f
   | Error e -> Alcotest.fail ("exact_float failed: " ^ show_error e));

  (match exact_float (Value.Int 42L) with
   | Ok f -> Alcotest.(check (float 0.001)) "int to float" 42.0 f
   | Error e -> Alcotest.fail ("exact_float on int failed: " ^ show_error e));

  match exact_float (Value.Text "hello") with
  | Ok _ -> Alcotest.fail "exact_float should fail on Text"
  | Error NotFloat -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

let test_exact_text () =
  let open Record in
  (match exact_text (Value.Text "hello") with
   | Ok "hello" -> ()
   | Ok s -> Alcotest.fail ("expected 'hello', got '" ^ s ^ "'")
   | Error e -> Alcotest.fail ("exact_text failed: " ^ show_error e));

  match exact_text (Value.Int 42L) with
  | Ok _ -> Alcotest.fail "exact_text should fail on Int"
  | Error NotText -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

let test_exact_list () =
  let open Record in
  (match exact_list exact_int (Value.List [Value.Int 1L; Value.Int 2L; Value.Int 3L]) with
   | Ok [1L; 2L; 3L] -> ()
   | Ok lst -> Alcotest.fail ("unexpected list: " ^ (String.concat ", " (List.map Int64.to_string lst)))
   | Error e -> Alcotest.fail ("exact_list failed: " ^ show_error e));

  (match exact_list exact_int (Value.Int 42L) with
   | Ok _ -> Alcotest.fail "exact_list should fail on Int"
   | Error NotList -> ()
   | Error e -> Alcotest.fail ("wrong error: " ^ show_error e));

  match exact_list exact_int (Value.List [Value.Int 1L; Value.Text "bad"]) with
  | Ok _ -> Alcotest.fail "exact_list should fail on mixed types"
  | Error NotInt -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

let test_exact_map () =
  let open Record in
  let m = Value.StringMap.(add "key" (Value.Text "value") empty) in
  (match exact_map (Value.Map m) with
   | Ok m' ->
       (match Value.StringMap.find_opt "key" m' with
        | Some (Value.Text "value") -> ()
        | _ -> Alcotest.fail "wrong value in map")
   | Error e -> Alcotest.fail ("exact_map failed: " ^ show_error e));

  match exact_map (Value.Text "bad") with
  | Ok _ -> Alcotest.fail "exact_map should fail on Text"
  | Error NotMap -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

(* Test maybe_exact variants *)
let test_maybe_exact () =
  let open Record in
  (match maybe_exact_bool (Value.Bool true) with
   | Some true -> ()
   | _ -> Alcotest.fail "maybe_exact_bool should return Some true");

  (match maybe_exact_bool Value.Null with
   | None -> ()
   | Some _ -> Alcotest.fail "maybe_exact_bool should return None on Null");

  (match maybe_exact_int (Value.Int 42L) with
   | Some 42L -> ()
   | _ -> Alcotest.fail "maybe_exact_int should return Some 42");

  match maybe_exact_text (Value.Text "hello") with
  | Some "hello" -> ()
  | _ -> Alcotest.fail "maybe_exact_text should return Some 'hello'"

(* Test at accessors *)
let test_at_accessors () =
  let open Record in
  let record = of_list [
    ("name", Value.Text "Alice");
    ("age", Value.Int 30L);
    ("active", Value.Bool true);
  ] in

  (match at_text record "name" with
   | Ok "Alice" -> ()
   | Ok s -> Alcotest.fail ("expected 'Alice', got '" ^ s ^ "'")
   | Error e -> Alcotest.fail ("at_text failed: " ^ show_error e));

  (match at_int record "age" with
   | Ok 30L -> ()
   | Ok n -> Alcotest.fail ("expected 30, got " ^ Int64.to_string n)
   | Error e -> Alcotest.fail ("at_int failed: " ^ show_error e));

  (match at_bool record "active" with
   | Ok true -> ()
   | Ok false -> Alcotest.fail "expected true"
   | Error e -> Alcotest.fail ("at_bool failed: " ^ show_error e));

  (match at_text record "missing" with
   | Ok _ -> Alcotest.fail "at_text should fail on missing key"
   | Error (KeyNotFound "missing") -> ()
   | Error e -> Alcotest.fail ("wrong error: " ^ show_error e));

  match at_int record "name" with
  | Ok _ -> Alcotest.fail "at_int should fail on Text value"
  | Error NotInt -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

(* Test maybe_at accessors *)
let test_maybe_at_accessors () =
  let open Record in
  let record = of_list [
    ("name", Value.Text "Bob");
    ("age", Value.Int 25L);
  ] in

  (match maybe_at_text record "name" with
   | Ok (Some "Bob") -> ()
   | Ok None -> Alcotest.fail "maybe_at_text should return Some 'Bob'"
   | Ok (Some s) -> Alcotest.fail ("expected 'Bob', got '" ^ s ^ "'")
   | Error e -> Alcotest.fail ("maybe_at_text failed: " ^ show_error e));

  (match maybe_at_text record "missing" with
   | Ok None -> ()
   | Ok (Some _) -> Alcotest.fail "maybe_at_text should return None for missing key"
   | Error e -> Alcotest.fail ("maybe_at_text failed: " ^ show_error e));

  match maybe_at_int record "name" with
  | Ok _ -> Alcotest.fail "maybe_at_int should fail on Text value"
  | Error NotInt -> ()
  | Error e -> Alcotest.fail ("wrong error: " ^ show_error e)

(* Test at_list with decoder *)
let test_at_list_with_decoder () =
  let open Record in
  let record = of_list [
    ("numbers", Value.List [Value.Int 1L; Value.Int 2L; Value.Int 3L]);
  ] in

  match at_list exact_int record "numbers" with
  | Ok [1L; 2L; 3L] -> ()
  | Ok lst -> Alcotest.fail ("unexpected list: " ^ (String.concat ", " (List.map Int64.to_string lst)))
  | Error e -> Alcotest.fail ("at_list failed: " ^ show_error e)

(* Test exact_int_as_int *)
let test_exact_int_as_int () =
  let open Record in
  match exact_int_as_int (Value.Int 42L) with
  | Ok 42 -> ()
  | Ok n -> Alcotest.fail ("expected 42, got " ^ string_of_int n)
  | Error e -> Alcotest.fail ("exact_int_as_int failed: " ^ show_error e)

(* Test record with nested map *)
let test_nested_map () =
  let open Record in
  let nested = Value.StringMap.(add "city" (Value.Text "NYC") empty) in
  let record = of_list [
    ("address", Value.Map nested);
  ] in

  match at_map record "address" with
  | Ok m ->
      (match Value.StringMap.find_opt "city" m with
       | Some (Value.Text "NYC") -> ()
       | _ -> Alcotest.fail "wrong value in nested map")
  | Error e -> Alcotest.fail ("at_map failed: " ^ show_error e)

let () =
  Alcotest.run "Record module"
    [ "exact decoders", [
        Alcotest.test_case "exact_unit" `Quick test_exact_unit;
        Alcotest.test_case "exact_bool" `Quick test_exact_bool;
        Alcotest.test_case "exact_int" `Quick test_exact_int;
        Alcotest.test_case "exact_float" `Quick test_exact_float;
        Alcotest.test_case "exact_text" `Quick test_exact_text;
        Alcotest.test_case "exact_list" `Quick test_exact_list;
        Alcotest.test_case "exact_map" `Quick test_exact_map;
        Alcotest.test_case "exact_int_as_int" `Quick test_exact_int_as_int;
      ];
      "maybe_exact variants", [
        Alcotest.test_case "maybe_exact" `Quick test_maybe_exact;
      ];
      "at accessors", [
        Alcotest.test_case "at_accessors" `Quick test_at_accessors;
        Alcotest.test_case "at_list_with_decoder" `Quick test_at_list_with_decoder;
        Alcotest.test_case "nested_map" `Quick test_nested_map;
      ];
      "maybe_at accessors", [
        Alcotest.test_case "maybe_at_accessors" `Quick test_maybe_at_accessors;
      ];
    ]
