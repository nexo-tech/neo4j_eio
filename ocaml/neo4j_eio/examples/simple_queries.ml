(* File: examples/simple_queries.ml *)
(* Task 1.1: Demonstrates basic queries and parameter substitution *)

open Neo4j_eio

(* Example 1: Basic RETURN query *)
let example_basic_return session =
  Printf.printf "Example 1: Basic RETURN query\n";

  match Neo4j.query session
    ~statement:"RETURN 1 AS num, 'hello' AS text, true AS flag"
    () with
  | Ok [record] ->
      (match Record.at_int record "num", Record.at_text record "text", Record.at_bool record "flag" with
       | Ok n, Ok s, Ok b ->
           Printf.printf "  Results: num=%Ld, text=%s, flag=%b\n" n s b;
           Printf.printf "  ✓ Basic RETURN works!\n"
       | _ ->
           Printf.printf "  ✗ Decode error\n")
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 2: Using query with parameters *)
let example_query_with_params session =
  Printf.printf "\nExample 2: Query with parameters\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN $num * 2 AS doubled, $text AS echo"
    ~parameters:(props [
      "num" =: int 21L;
      "text" =: text "Hello, Neo4j!";
    ])
    () with
  | Ok [record] ->
      (match Record.at_int record "doubled", Record.at_text record "echo" with
       | Ok doubled, Ok echo ->
           Printf.printf "  Parameters sent: num=21, text='Hello, Neo4j!'\n";
           Printf.printf "  Results: doubled=%Ld, echo=%s\n" doubled echo;
           Printf.printf "  ✓ Parameter substitution works!\n"
       | _ ->
           Printf.printf "  ✗ Decode error\n")
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 3: Using query_ to ignore results *)
let example_query_ignore_results session =
  Printf.printf "\nExample 3: Ignoring results (query_)\n";

  let label = Printf.sprintf "Temp_%d" (Random.int 1000000) in
  let open Neo4j in

  match query_ session
    ~statement:(Printf.sprintf "CREATE (n:%s {value: 42})" label)
    () with
  | Ok () ->
      Printf.printf "  ✓ Node created (results ignored)\n";
      (* Cleanup *)
      (match query_ session
         ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
         () with
       | Ok () -> Printf.printf "  ✓ Cleanup completed\n"
       | Error e -> Printf.eprintf "  Cleanup failed: %s\n" (Error.to_string e))
  | Error e ->
      Printf.eprintf "  ✗ Create failed: %s\n" (Error.to_string e)

(* Example 4: Using query_ with parameters and ignoring results *)
let example_query_p_ignore_results session =
  Printf.printf "\nExample 4: Parameters with ignored results\n";

  let label = Printf.sprintf "Temp_%d" (Random.int 1000000) in
  let open Neo4j in

  match query_ session
    ~statement:(Printf.sprintf "CREATE (n:%s {name: $name, value: $value})" label)
    ~parameters:(props [
      "name" =: text "Test";
      "value" =: int 123L;
    ])
    () with
  | Ok () ->
      Printf.printf "  ✓ Node created with parameters (cleaner syntax!)\n";
      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"
  | Error e ->
      Printf.eprintf "  ✗ Create failed: %s\n" (Error.to_string e)

(* Example 5: Extracting different value types *)
let example_value_extraction session =
  Printf.printf "\nExample 5: Extracting different value types\n";

  match Neo4j.query session
    ~statement:"RETURN 42 AS int_val, 3.14 AS float_val, 'text' AS text_val, true AS bool_val, null AS null_val"
    () with
  | Ok [record] ->
      Printf.printf "  Extracted values:\n";
      (match Record.at_int record "int_val" with
       | Ok i -> Printf.printf "    int: %Ld\n" i
       | Error _ -> ());
      (match Record.at_float record "float_val" with
       | Ok f -> Printf.printf "    float: %f\n" f
       | Error _ -> ());
      (match Record.at_text record "text_val" with
       | Ok t -> Printf.printf "    text: %s\n" t
       | Error _ -> ());
      (match Record.at_bool record "bool_val" with
       | Ok b -> Printf.printf "    bool: %b\n" b
       | Error _ -> ());
      (match Record.at_unit record "null_val" with
       | Ok () -> Printf.printf "    null: (null)\n"
       | Error _ -> ());
      Printf.printf "  ✓ All value types extracted!\n"
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 6: Using UNWIND to get multiple values *)
let example_unwind_multiple_values session =
  Printf.printf "\nExample 6: UNWIND - multiple values in result\n";

  match Neo4j.query session
    ~statement:"UNWIND [1, 2, 3, 4, 5] AS n RETURN n"
    () with
  | Ok records ->
      Printf.printf "  UNWIND returned %d records: " (List.length records);
      List.iter (fun record ->
        match Record.at_int record "n" with
        | Ok n -> Printf.printf "%Ld " n
        | Error _ -> Printf.printf "? "
      ) records;
      Printf.printf "\n  ✓ UNWIND works!\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 7: Nested property access with parameters *)
let example_nested_properties session =
  Printf.printf "\nExample 7: Nested property access\n";

  let label = Printf.sprintf "Person_%d" (Random.int 1000000) in
  let open Neo4j in

  match query session
    ~statement:(Printf.sprintf
      "CREATE (p:%s {name: $person.name, age: $person.age}) RETURN p.name AS name, p.age AS age"
      label)
    ~parameters:(props [
      "person" =: Value.Map (props [
        "name" =: text "Alice";
        "age" =: int 30L;
      ])
    ])
    () with
  | Ok [record] ->
      (match Record.at_text record "name", Record.at_int record "age" with
       | Ok name, Ok age ->
           Printf.printf "  Created person with nested properties:\n";
           Printf.printf "    name: %s\n" name;
           Printf.printf "    age: %Ld\n" age;
           Printf.printf "  ✓ Nested property access works!\n";
           (* Cleanup *)
           let _ = query_ session
             ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
             () in ()
       | _ ->
           Printf.printf "  ✗ Decode error\n")
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 8: Using props helper with multiple parameters *)
let example_multiple_params session =
  Printf.printf "\nExample 8: Multiple parameters with props helper\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN $a + $b AS sum, $a * $b AS product"
    ~parameters:(props [
      "a" =: int 7L;
      "b" =: int 6L;
    ])
    () with
  | Ok [record] ->
      (match Record.at_int record "sum", Record.at_int record "product" with
       | Ok sum, Ok product ->
           Printf.printf "  Input: a=7, b=6\n";
           Printf.printf "  Results: sum=%Ld, product=%Ld\n" sum product;
           Printf.printf "  ✓ Multiple parameters work!\n"
       | _ ->
           Printf.printf "  ✗ Decode error\n")
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Simple Queries and Parameter Substitution\n";
    Printf.printf "==========================================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_basic_return session;
        example_query_with_params session;
        example_query_ignore_results session;
        example_query_p_ignore_results session;
        example_value_extraction session;
        example_unwind_multiple_values session;
        example_nested_properties session;
        example_multiple_params session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All examples completed successfully!\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
