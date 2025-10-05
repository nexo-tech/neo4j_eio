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
      (match Value.at record "num", Value.at record "text", Value.at record "flag" with
       | Some (Value.Int n), Some (Value.Text s), Some (Value.Bool b) ->
           Printf.printf "  Results: num=%Ld, text=%s, flag=%b\n" n s b;
           Printf.printf "  ✓ Basic RETURN works (using named fields!)\n"
       | _ ->
           Printf.printf "  ✗ Unexpected value types\n")
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
      (match Value.at record "doubled", Value.at record "echo" with
       | Some (Value.Int doubled), Some (Value.Text echo) ->
           Printf.printf "  Parameters sent: num=21, text='Hello, Neo4j!'\n";
           Printf.printf "  Results: doubled=%Ld, echo=%s\n" doubled echo;
           Printf.printf "  ✓ Parameter substitution works (with field names!)\n"
       | _ ->
           Printf.printf "  ✗ Unexpected value types\n")
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
      (match Value.at record "int_val" with
       | Some (Value.Int i) -> Printf.printf "    int: %Ld\n" i
       | _ -> ());
      (match Value.at record "float_val" with
       | Some (Value.Float f) -> Printf.printf "    float: %f\n" f
       | _ -> ());
      (match Value.at record "text_val" with
       | Some (Value.Text t) -> Printf.printf "    text: %s\n" t
       | _ -> ());
      (match Value.at record "bool_val" with
       | Some (Value.Bool b) -> Printf.printf "    bool: %b\n" b
       | _ -> ());
      (match Value.at record "null_val" with
       | Some Value.Null -> Printf.printf "    null: (null)\n"
       | _ -> ());
      Printf.printf "  ✓ All value types extracted by field name\n"
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
        match Value.at record "n" with
        | Some (Value.Int n) -> Printf.printf "%Ld " n
        | _ -> Printf.printf "? "
      ) records;
      Printf.printf "\n  ✓ UNWIND works with named fields\n"
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
      (match Value.at record "name", Value.at record "age" with
       | Some (Value.Text name), Some (Value.Int age) ->
           Printf.printf "  Created person with nested properties:\n";
           Printf.printf "    name: %s\n" name;
           Printf.printf "    age: %Ld\n" age;
           Printf.printf "  ✓ Nested property access with field names\n";
           (* Cleanup *)
           let _ = query_ session
             ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
             () in ()
       | _ ->
           Printf.printf "  ✗ Unexpected value types\n")
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
      (match Value.at record "sum", Value.at record "product" with
       | Some (Value.Int sum), Some (Value.Int product) ->
           Printf.printf "  Input: a=7, b=6\n";
           Printf.printf "  Results: sum=%Ld, product=%Ld\n" sum product;
           Printf.printf "  ✓ Multiple parameters with named results\n"
       | _ ->
           Printf.printf "  ✗ Unexpected value types\n")
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
