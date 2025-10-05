(* Test suite for Result_ops module *)

open Neo4j_eio

let test_return () =
  let open Result_ops in
  assert (return 5 = Ok 5);
  assert (fail "error" = Error "error");
  Printf.printf "✓ return and fail work\n"

let test_bind () =
  let open Result_ops in
  let r1 = Ok 5 >>= fun x -> Ok (x + 1) in
  assert (r1 = Ok 6);

  let r2 = Error "err" >>= fun x -> Ok (x + 1) in
  assert (r2 = Error "err");

  Printf.printf "✓ bind (>>=) works\n"

let test_map () =
  let open Result_ops in
  let r1 = Ok 5 >>| (fun x -> x * 2) in
  assert (r1 = Ok 10);

  let r2 = Error "err" >>| (fun x -> x * 2) in
  assert (r2 = Error "err");

  Printf.printf "✓ map (>>|) works\n"

let test_let_syntax () =
  let open Result_ops in
  let r =
    let* x = Ok 5 in
    let* y = Ok 10 in
    return (x + y)
  in
  assert (r = Ok 15);

  let r2 =
    let* x = Ok 5 in
    let* y = Error "err" in
    return (x + y)
  in
  assert (r2 = Error "err");

  Printf.printf "✓ let* syntax works\n"

let test_applicative () =
  let open Result_ops in
  let r =
    let+ x = Ok 5
    and+ y = Ok 10
    and+ z = Ok 3 in
    x + y + z
  in
  assert (r = Ok 18);

  let r2 =
    let+ x = Ok 5
    and+ y = Error "err" in
    x + y
  in
  assert (r2 = Error "err");

  Printf.printf "✓ applicative (let+ and+) works\n"

let test_functor () =
  let open Result_ops in
  let r = (fun x -> x * 2) <$> Ok 5 in
  assert (r = Ok 10);

  Printf.printf "✓ functor (<$>) works\n"

let test_applicative_ops () =
  let open Result_ops in
  let r = Ok (fun x -> x * 2) <*> Ok 5 in
  assert (r = Ok 10);

  let r2 = lift2 (+) (Ok 5) (Ok 10) in
  assert (r2 = Ok 15);

  let r3 = lift3 (fun x y z -> x + y + z) (Ok 1) (Ok 2) (Ok 3) in
  assert (r3 = Ok 6);

  Printf.printf "✓ applicative operators (<*>, lift2, lift3) work\n"

let test_alternative () =
  let open Result_ops in
  let r1 = Ok 5 <|> Ok 10 in
  assert (r1 = Ok 5);

  let r2 = Error "err1" <|> Ok 10 in
  assert (r2 = Ok 10);

  let r3 = Error "err1" <|> Error "err2" in
  assert (r3 = Error "err2");

  Printf.printf "✓ alternative (<|>) works\n"

let test_kleisli () =
  let open Result_ops in
  let f x = Ok (x + 1) in
  let g x = Ok (x * 2) in

  let h = f >=> g in
  assert (h 5 = Ok 12);

  let h2 = g <=< f in
  assert (h2 5 = Ok 12);

  Printf.printf "✓ Kleisli composition (>=>, <=<) works\n"

let test_sequence () =
  let open Result_ops in
  let rs = [Ok 1; Ok 2; Ok 3] in
  assert (sequence rs = Ok [1; 2; 3]);

  let rs2 = [Ok 1; Error "err"; Ok 3] in
  assert (sequence rs2 = Error "err");

  Printf.printf "✓ sequence works\n"

let test_traverse () =
  let open Result_ops in
  let f x = Ok (x * 2) in
  let xs = [1; 2; 3] in
  assert (traverse f xs = Ok [2; 4; 6]);

  let f2 x = if x > 2 then Error "too big" else Ok (x * 2) in
  assert (traverse f2 xs = Error "too big");

  Printf.printf "✓ traverse works\n"

let test_fold () =
  let open Result_ops in
  let f acc x = Ok (acc + x) in
  assert (fold_left_m f 0 [1; 2; 3] = Ok 6);

  let f2 acc x = if x > 2 then Error "err" else Ok (acc + x) in
  assert (fold_left_m f2 0 [1; 2; 3] = Error "err");

  Printf.printf "✓ fold_left_m works\n"

let test_filter () =
  let open Result_ops in
  let p x = Ok (x mod 2 = 0) in
  assert (filter_m p [1; 2; 3; 4] = Ok [2; 4]);

  Printf.printf "✓ filter_m works\n"

let test_guard () =
  let open Result_ops in
  assert (guard true "err" = Ok ());
  assert (guard false "err" = Error "err");

  Printf.printf "✓ guard works\n"

let test_conversion () =
  let open Result_ops in
  assert (from_option "err" (Some 5) = Ok 5);
  assert (from_option "err" None = Error "err");

  assert (to_option (Ok 5) = Some 5);
  assert (to_option (Error "err") = None);

  Printf.printf "✓ from_option and to_option work\n"

let test_catch () =
  let open Result_ops in
  let r1 = catch (fun () -> 5 / 1) (fun exn -> Printexc.to_string exn) in
  assert (r1 = Ok 5);

  let r2 = catch (fun () -> 5 / 0) (fun exn -> Printexc.to_string exn) in
  assert (is_error r2);

  Printf.printf "✓ catch works\n"

let test_utility () =
  let open Result_ops in
  assert (is_ok (Ok 5) = true);
  assert (is_ok (Error "err") = false);
  assert (is_error (Ok 5) = false);
  assert (is_error (Error "err") = true);

  Printf.printf "✓ is_ok and is_error work\n"

let test_when_unless () =
  let open Result_ops in
  assert (when_ true (fun () -> Ok ()) = Ok ());
  assert (when_ false (fun () -> Error "err") = Ok ());

  assert (unless false (fun () -> Ok ()) = Ok ());
  assert (unless true (fun () -> Error "err") = Ok ());

  Printf.printf "✓ when_ and unless work\n"

let test_bimap () =
  let open Result_ops in
  let r1 = bimap (fun x -> x * 2) (fun e -> e ^ "!") (Ok 5) in
  assert (r1 = Ok 10);

  let r2 = bimap (fun x -> x * 2) (fun e -> e ^ "!") (Error "err") in
  assert (r2 = Error "err!");

  Printf.printf "✓ bimap works\n"

let test_pair_ops () =
  let open Result_ops in
  assert (both (Ok 5) (Ok 10) = Ok (5, 10));
  assert (both (Error "err") (Ok 10) = Error "err");

  assert (fst (Ok (5, 10)) = Ok 5);
  assert (snd (Ok (5, 10)) = Ok 10);

  Printf.printf "✓ both, fst, snd work\n"

(* Real-world example: validating user input *)
type user = { name : string; age : int; email : string } [@@warning "-69"]

let test_realistic_example () =
  let open Result_ops in

  let validate_name name =
    if String.length name > 0 then Ok name
    else Error "Name cannot be empty"
  in
  let validate_age age =
    if age >= 18 && age <= 120 then Ok age
    else Error "Age must be between 18 and 120"
  in
  let validate_email email =
    if String.contains email '@' then Ok email
    else Error "Invalid email"
  in
  let create_user name age email =
    let+ name = validate_name name
    and+ age = validate_age age
    and+ email = validate_email email in
    { name; age; email }
  in
  let result1 = create_user "Alice" 25 "alice@example.com" in
  assert (is_ok result1);

  let result2 = create_user "" 25 "alice@example.com" in
  assert (result2 = Error "Name cannot be empty");

  let result3 = create_user "Alice" 150 "alice@example.com" in
  assert (result3 = Error "Age must be between 18 and 120");

  Printf.printf "✓ realistic validation example works\n"

(* Run all tests *)
let () =
  Printf.printf "Testing Result_ops module...\n\n";
  test_return ();
  test_bind ();
  test_map ();
  test_let_syntax ();
  test_applicative ();
  test_functor ();
  test_applicative_ops ();
  test_alternative ();
  test_kleisli ();
  test_sequence ();
  test_traverse ();
  test_fold ();
  test_filter ();
  test_guard ();
  test_conversion ();
  test_catch ();
  test_utility ();
  test_when_unless ();
  test_bimap ();
  test_pair_ops ();
  test_realistic_example ();
  Printf.printf "\n✓ All Result_ops tests passed!\n"
