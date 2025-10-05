(** Simple Queries - BETTER_API Edition

    This demonstrates the new BETTER_API approach using:
    - Query Builder DSL for declarative queries
    - Transaction DSL for monadic composition and error handling
    - Record.at_* for clean result extraction
*)

open Neo4j_eio

(* Example 1: Basic RETURN query with Query Builder *)
let example_basic_return session =
  Printf.printf "Example 1: Basic RETURN query (Query Builder)\n";

  let open Transaction_dsl in
  let tx = let* records = exec_query_builder
      (Query_builder.raw "RETURN 1 AS num, 'hello' AS text, true AS flag") in
    match records with
    | [record] ->
        (match Record.at_int record "num",
               Record.at_text record "text",
               Record.at_bool record "flag" with
         | Ok n, Ok s, Ok b ->
             Printf.printf "  Results: num=%Ld, text=%s, flag=%b\n" n s b;
             Printf.printf "  ✓ Basic RETURN works!\n";
             return ()
         | _ ->
             fail (Error.Protocol "Decode error"))
    | _ ->
        fail (Error.Protocol "Unexpected result format")
  in
  match run tx session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 2: Query with parameters using Query Builder *)
let example_query_with_params session =
  Printf.printf "\nExample 2: Query with parameters (Query Builder)\n";

  let open Transaction_dsl in
  let tx = let* records = exec_query_builder
      (Query_builder.raw "RETURN $num * 2 AS doubled, $text AS echo"
       |> Query_builder.with_params [
            ("num", Value.Int 21L);
            ("text", Value.Text "Hello, Neo4j!");
          ]) in
    match records with
    | [record] ->
        (match Record.at_int record "doubled",
               Record.at_text record "echo" with
         | Ok doubled, Ok echo ->
             Printf.printf "  Parameters sent: num=21, text='Hello, Neo4j!'\n";
             Printf.printf "  Results: doubled=%Ld, echo=%s\n" doubled echo;
             Printf.printf "  ✓ Parameter substitution works!\n";
             return ()
         | _ ->
             fail (Error.Protocol "Decode error"))
    | _ ->
        fail (Error.Protocol "Unexpected result format")
  in
  match run tx session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 3: CREATE with execute_unit (ignoring results) *)
let example_create_ignore_results session =
  Printf.printf "\nExample 3: CREATE node (execute_unit)\n";

  let label = Printf.sprintf "Temp_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    let* () = exec_query_builder_unit
        (Query_builder.create_node
           (Printf.sprintf "(n:%s {value: 42})" label)) in
    Printf.printf "  ✓ Node created (results ignored)\n";

    (* Cleanup *)
    let* () = exec_query_builder_unit
        (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
         |> Query_builder.detach_delete ["n"]) in
    Printf.printf "  ✓ Cleanup completed\n";
    return ()
  in
  match run tx session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e)

(* Example 4: Fluent Query Builder pipeline *)
let example_fluent_builder session =
  Printf.printf "\nExample 4: Fluent Query Builder\n";

  let label = Printf.sprintf "Temp_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    (* Create test data *)
    let* () = iter (fun (name, age) ->
        exec_query_builder_unit
          (Query_builder.create_node
             (Printf.sprintf "(p:%s {name: '%s', age: %Ld})" label name age))
      ) [("Alice", 30L); ("Bob", 35L); ("Charlie", 25L)] in

    (* Query with WHERE, ORDER BY, LIMIT *)
    let* records = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
         |> Query_builder.where "p.age >= 25"
         |> Query_builder.and_where "p.age < 40"
         |> Query_builder.return ["p.name AS name"; "p.age AS age"]
         |> Query_builder.order_by_desc "p.age"
         |> Query_builder.limit 2) in

    Printf.printf "  Found %d people (age 25-40, limit 2):\n" (List.length records);
    let () = List.iter (fun r ->
        match Record.at_text r "name", Record.at_int r "age" with
        | Ok name, Ok age -> Printf.printf "    - %s: %Ld\n" name age
        | _ -> ()
      ) records in

    (* Cleanup *)
    let* () = exec_query_builder_unit
        (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
         |> Query_builder.detach_delete ["n"]) in
    return ()
  in
  match run tx session with
  | Ok () -> Printf.printf "  ✓ Fluent builder works!\n"
  | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e)

(* Example 5: Parameters with arithmetic *)
let example_arithmetic session =
  Printf.printf "\nExample 5: Arithmetic with parameters\n";

  let open Transaction_dsl in
  let tx = let* records = exec_query_builder
      (Query_builder.raw "RETURN $a + $b AS sum, $a * $b AS product"
       |> Query_builder.with_params [
            ("a", Value.Int 7L);
            ("b", Value.Int 6L);
          ]) in
    match records with
    | [record] ->
        (match Record.at_int record "sum",
               Record.at_int record "product" with
         | Ok sum, Ok product ->
             Printf.printf "  Input: a=7, b=6\n";
             Printf.printf "  Results: sum=%Ld, product=%Ld\n" sum product;
             Printf.printf "  ✓ Arithmetic with parameters works!\n";
             return ()
         | _ ->
             fail (Error.Protocol "Decode error"))
    | _ ->
        fail (Error.Protocol "Unexpected result")
  in
  match run tx session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e)

(* Example 6: Transaction error handling with catch *)
let example_error_handling session =
  Printf.printf "\nExample 6: Error handling (Transaction DSL)\n";

  let label = Printf.sprintf "Error_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    catch
      (let* () = exec_query_builder_unit
           (Query_builder.create_node
              (Printf.sprintf "(p:%s {value: 1})" label)) in
       (* This will fail *)
       exec_query_builder_unit
         (Query_builder.raw "INVALID CYPHER SYNTAX"))
      (fun err ->
         let err_str = Error.to_string err in
         let display = if String.length err_str > 50 then String.sub err_str 0 50 ^ "..." else err_str in
         Printf.printf "  ✓ Caught error: %s\n" display;
         (* Create fallback node *)
         exec_query_builder_unit
           (Query_builder.create_node
              (Printf.sprintf "(p:%s {value: 2, fallback: true})" label)))
  in

  (match run tx session with
   | Ok () ->
       Printf.printf "  ✓ Error handling works!\n";
       (* Cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.detach_delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e))

(* Example 7: Applicative composition with and+ *)
let example_applicative session =
  Printf.printf "\nExample 7: Applicative composition (and+)\n";

  let label = Printf.sprintf "Applic_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    let* () = exec_query_builder_unit
        (Query_builder.create_node
           (Printf.sprintf "(a:%s {name: 'Alice', value: 10})" label)) in
    let* () = exec_query_builder_unit
        (Query_builder.create_node
           (Printf.sprintf "(b:%s {name: 'Bob', value: 20})" label)) in

    (* Use and+ to combine queries *)
    let+ r1 = exec_query_builder
                (Query_builder.match_ (Printf.sprintf "(a:%s {name: 'Alice'})" label)
                 |> Query_builder.return ["a.value AS v"])
    and+ r2 = exec_query_builder
                (Query_builder.match_ (Printf.sprintf "(b:%s {name: 'Bob'})" label)
                 |> Query_builder.return ["b.value AS v"]) in

    match r1, r2 with
    | [rec1], [rec2] ->
        (match Record.at_int rec1 "v", Record.at_int rec2 "v" with
         | Ok v1, Ok v2 ->
             Printf.printf "  Alice: %Ld, Bob: %Ld, Total: %Ld\n" v1 v2 (Int64.add v1 v2);
             ()
         | _ -> ())
    | _ -> ()
  in

  (match run tx session with
   | Ok () ->
       Printf.printf "  ✓ Applicative composition works!\n";
       (* Cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.detach_delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e))

(* Example 8: Conditional execution with when_ *)
let example_conditional session =
  Printf.printf "\nExample 8: Conditional execution (when_)\n";

  let label = Printf.sprintf "Cond_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let should_create_alice = true in
  let should_create_bob = false in

  let tx =
    let* () = when_ should_create_alice
        (exec_query_builder_unit
           (Query_builder.create_node
              (Printf.sprintf "(p:%s {name: 'Alice'})" label))) in
    let* () = when_ should_create_bob
        (exec_query_builder_unit
           (Query_builder.create_node
              (Printf.sprintf "(p:%s {name: 'Bob'})" label))) in

    let* records = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
         |> Query_builder.return ["count(p) AS cnt"]) in

    match records with
    | [r] ->
        (match Record.at_int r "cnt" with
         | Ok 1L ->
             Printf.printf "  ✓ Conditional execution works (created Alice only)!\n";
             return ()
         | Ok n ->
             Printf.printf "  Unexpected count: %Ld\n" n;
             return ()
         | Error _ -> return ())
    | _ -> return ()
  in

  (match run tx session with
   | Ok () ->
       (* Cleanup *)
       let _ = Query_builder.execute_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.detach_delete ["n"])
           session in ()
   | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e))

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Simple Queries - BETTER_API Edition\n";
    Printf.printf "====================================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_basic_return session;
        example_query_with_params session;
        example_create_ignore_results session;
        example_fluent_builder session;
        example_arithmetic session;
        example_error_handling session;
        example_applicative session;
        example_conditional session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All examples completed successfully!\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
