(* Test suite for Extract module *)

open Neo4j_eio

(* Helper to create test records *)
let make_record pairs =
  Record.of_list pairs

(* Test basic field extraction *)
let test_basic_extraction () =
  let open Extract in

  let record = make_record [
    ("name", Value.Text "Alice");
    ("age", Value.Int 30L);
    ("active", Value.Bool true);
    ("score", Value.Float 95.5);
  ] in

  (* Text extraction *)
  (match run (text "name") record with
   | Ok "Alice" -> Printf.printf "✓ text extraction works\n"
   | _ -> assert false);

  (* Int extraction *)
  (match run (int "age") record with
   | Ok 30L -> Printf.printf "✓ int extraction works\n"
   | _ -> assert false);

  (* Bool extraction *)
  (match run (bool "active") record with
   | Ok true -> Printf.printf "✓ bool extraction works\n"
   | _ -> assert false);

  (* Float extraction *)
  (match run (float "score") record with
   | Ok 95.5 -> Printf.printf "✓ float extraction works\n"
   | _ -> assert false)

(* Test monadic composition with let* *)
let test_monadic_bind () =
  let open Extract in

  let record = make_record [
    ("first", Value.Int 5L);
    ("second", Value.Int 10L);
  ] in

  let extractor =
    let* x = int "first" in
    let* y = int "second" in
    return (Int64.add x y)
  in

  match run extractor record with
  | Ok 15L -> Printf.printf "✓ monadic bind (let*) works\n"
  | _ -> assert false

(* Test applicative composition with let+ and+ *)
let test_applicative () =
  let open Extract in

  let record = make_record [
    ("name", Value.Text "Bob");
    ("age", Value.Int 25L);
    ("email", Value.Text "bob@example.com");
  ] in

  let extractor =
    let+ name = text "name"
    and+ age = int "age"
    and+ email = text "email" in
    (name, age, email)
  in

  match run extractor record with
  | Ok ("Bob", 25L, "bob@example.com") ->
      Printf.printf "✓ applicative (let+ and+) works\n"
  | _ -> assert false

(* Test optional field extraction *)
let test_optional () =
  let open Extract in

  let record1 = make_record [
    ("name", Value.Text "Charlie");
    ("email", Value.Text "charlie@example.com");
  ] in

  let record2 = make_record [
    ("name", Value.Text "Dave");
  ] in

  let extractor =
    let+ name = text "name"
    and+ email = optional (text "email") in
    (name, email)
  in

  (match run extractor record1 with
   | Ok ("Charlie", Some "charlie@example.com") ->
       Printf.printf "✓ optional with present field works\n"
   | _ -> assert false);

  (match run extractor record2 with
   | Ok ("Dave", None) ->
       Printf.printf "✓ optional with missing field works\n"
   | _ -> assert false)

(* Test default values *)
let test_default () =
  let open Extract in

  let record = make_record [
    ("name", Value.Text "Eve");
  ] in

  let extractor =
    let+ name = text "name"
    and+ age = default 18L (int "age") in
    (name, age)
  in

  match run extractor record with
  | Ok ("Eve", 18L) ->
      Printf.printf "✓ default value works\n"
  | _ -> assert false

(* Test error propagation *)
let test_error_handling () =
  let open Extract in

  let record = make_record [
    ("name", Value.Text "Frank");
    ("age", Value.Text "not a number");
  ] in

  let extractor =
    let+ name = text "name"
    and+ age = int "age" in
    (name, age)
  in

  match run extractor record with
  | Error Record.NotInt ->
      Printf.printf "✓ type error propagates correctly\n"
  | _ -> assert false

(* Test missing key error *)
let test_missing_key () =
  let open Extract in

  let record = make_record [
    ("name", Value.Text "Grace");
  ] in

  match run (int "age") record with
  | Error (Record.KeyNotFound "age") ->
      Printf.printf "✓ missing key error works\n"
  | _ -> assert false

(* Test list extraction *)
let test_list_extraction () =
  let open Extract in

  let record = make_record [
    ("tags", Value.List [Value.Text "tag1"; Value.Text "tag2"; Value.Text "tag3"]);
  ] in

  match run (list "tags" Record.exact_text) record with
  | Ok ["tag1"; "tag2"; "tag3"] ->
      Printf.printf "✓ list extraction works\n"
  | _ -> assert false

(* Test maybe extractors *)
let test_maybe_extractors () =
  let open Extract in

  let record1 = make_record [
    ("name", Value.Text "Henry");
    ("age", Value.Int 40L);
  ] in

  let record2 = make_record [
    ("name", Value.Text "Iris");
  ] in

  let extractor =
    let+ name = text "name"
    and+ age = maybe_int "age" in
    (name, age)
  in

  (match run extractor record1 with
   | Ok ("Henry", Some 40L) ->
       Printf.printf "✓ maybe_int with present field works\n"
   | _ -> assert false);

  (match run extractor record2 with
   | Ok ("Iris", None) ->
       Printf.printf "✓ maybe_int with missing field works\n"
   | _ -> assert false)

(* Test sequence combinator *)
let test_sequence () =
  let open Extract in

  let record = make_record [
    ("a", Value.Int 1L);
    ("b", Value.Int 2L);
    ("c", Value.Int 3L);
  ] in

  let extractors = [int "a"; int "b"; int "c"] in

  match run (sequence extractors) record with
  | Ok [1L; 2L; 3L] ->
      Printf.printf "✓ sequence combinator works\n"
  | _ -> assert false

(* Test infix operators *)
let test_infix_operators () =
  let open Extract in

  let record = make_record [
    ("x", Value.Int 10L);
    ("y", Value.Int 20L);
  ] in

  (* Test >>= *)
  let bind_extractor =
    int "x" >>= fun x ->
    int "y" >>= fun y ->
    return (Int64.add x y)
  in

  (match run bind_extractor record with
   | Ok 30L -> Printf.printf "✓ >>= operator works\n"
   | _ -> assert false);

  (* Test >>| *)
  let map_extractor = int "x" >>| Int64.to_int in
  (match run map_extractor record with
   | Ok 10 -> Printf.printf "✓ >>| operator works\n"
   | _ -> assert false);

  (* Test <$> *)
  let fmap_extractor = Int64.to_int <$> int "x" in
  (match run fmap_extractor record with
   | Ok 10 -> Printf.printf "✓ <$> operator works\n"
   | _ -> assert false);

  (* Test <*> *)
  let apply_extractor =
    return Int64.add <*> int "x" <*> int "y"
  in
  (match run apply_extractor record with
   | Ok 30L -> Printf.printf "✓ <*> operator works\n"
   | _ -> assert false)

(* Test graph types extraction *)
let test_node_extraction () =
  let open Extract in

  let test_node = Value.{ node_id = 123L; labels = ["Person"]; props = Value.StringMap.empty } in
  let record = make_record [("n", Value.Node test_node)] in

  match run (node "n") record with
  | Ok n when n.Value.node_id = 123L && n.Value.labels = ["Person"] ->
      Printf.printf "✓ node extraction works\n"
  | _ -> assert false

(* Test relationship extraction *)
let test_relationship_extraction () =
  let open Extract in

  let test_rel = Value.{
    rel_id = 456L;
    start_node_id = 123L;
    end_node_id = 789L;
    rel_type = "KNOWS";
    rel_props = Value.StringMap.empty
  } in
  let record = make_record [("r", Value.Relationship test_rel)] in

  match run (relationship "r") record with
  | Ok r when r.Value.rel_id = 456L && r.Value.rel_type = "KNOWS" ->
      Printf.printf "✓ relationship extraction works\n"
  | _ -> assert false

(* Test complex nested extraction *)
type person = {
  name : string;
  age : int64;
  address : address option;
}
and address = {
  city : string;
  country : string;
} [@@warning "-69"]

let test_nested_extraction () =
  let open Extract in

  let record = make_record [
    ("name", Value.Text "Jack");
    ("age", Value.Int 35L);
    ("city", Value.Text "London");
    ("country", Value.Text "UK");
  ] in

  let address_extractor =
    let+ city = text "city"
    and+ country = text "country" in
    { city; country }
  in

  let person_extractor =
    let+ name = text "name"
    and+ age = int "age"
    and+ address = optional address_extractor in
    { name; age; address }
  in

  match run person_extractor record with
  | Ok p when p.name = "Jack" && p.age = 35L ->
      (match p.address with
       | Some addr when addr.city = "London" && addr.country = "UK" ->
           Printf.printf "✓ nested extraction works\n"
       | _ -> assert false)
  | _ -> assert false

(* Test run_exn *)
let test_run_exn () =
  let open Extract in

  let record = make_record [("name", Value.Text "Kate")] in

  let result = run_exn (text "name") record in
  assert (result = "Kate");

  (* Test that run_exn raises on error *)
  let raised = ref false in
  (try
     let _ = run_exn (int "missing") record in
     ()
   with Failure _ -> raised := true);

  if !raised then
    Printf.printf "✓ run_exn works (raises on error)\n"
  else
    assert false

(* Realistic example: User validation *)
type user_data = {
  username : string;
  email : string;
  age : int64;
  verified : bool;
  bio : string option;
} [@@warning "-69"]

let test_realistic_user_extraction () =
  let open Extract in

  let record = make_record [
    ("username", Value.Text "alice_smith");
    ("email", Value.Text "alice@example.com");
    ("age", Value.Int 28L);
    ("verified", Value.Bool true);
  ] in

  let user_extractor =
    let+ username = text "username"
    and+ email = text "email"
    and+ age = int "age"
    and+ verified = bool "verified"
    and+ bio = optional (text "bio") in
    { username; email; age; verified; bio }
  in

  match run user_extractor record with
  | Ok user when
      user.username = "alice_smith" &&
      user.email = "alice@example.com" &&
      user.age = 28L &&
      user.verified = true &&
      user.bio = None ->
      Printf.printf "✓ realistic user extraction works\n"
  | _ -> assert false

(* Run all tests *)
let () =
  Printf.printf "Testing Extract module...\n\n";
  test_basic_extraction ();
  test_monadic_bind ();
  test_applicative ();
  test_optional ();
  test_default ();
  test_error_handling ();
  test_missing_key ();
  test_list_extraction ();
  test_maybe_extractors ();
  test_sequence ();
  test_infix_operators ();
  test_node_extraction ();
  test_relationship_extraction ();
  test_nested_extraction ();
  test_run_exn ();
  test_realistic_user_extraction ();
  Printf.printf "\n✓ All Extract tests passed!\n"
