(** Error Handling - BETTER_API Edition

    This demonstrates error handling patterns using:
    - Transaction DSL with catch for error recovery
    - Query Builder DSL for clean query construction
    - Record.at_* for type-safe extraction
*)

open Neo4j_eio

(* Example 1: Syntax error handling with Transaction DSL catch *)
let example_syntax_error session =
  Printf.printf "Example 1: Syntax error (Transaction DSL catch)\n";

  let open Transaction_dsl in
  let tx = catch
    (exec_query_builder (Query_builder.raw "INVALID CYPHER SYNTAX HERE"))
    (fun err ->
       match err with
       | Error.ClientError { code; message } ->
           Printf.printf "  ✓ Caught ClientError\n";
           Printf.printf "    Code: %s\n" code;
           Printf.printf "    Message: %s\n" (String.sub message 0 (min 60 (String.length message)));
           Printf.printf "  ✓ Syntax errors are properly classified\n";
           return []
       | _ ->
           Printf.printf "  ✗ Got different error type: %s\n" (Error.to_string err);
           return [])
  in
  match run tx session with
  | Ok _ -> ()
  | Error e -> Printf.printf "  ✗ Unexpected error: %s\n" (Error.to_string e)

(* Example 2: Using Error.to_string for display *)
let example_error_to_string session =
  Printf.printf "\nExample 2: Error.to_string usage\n";

  let open Transaction_dsl in
  let tx = catch
    (exec_query_builder
       (Query_builder.raw "MATCH (n:NonExistent) WHERE n.invalid RETURN invalid.field"))
    (fun err ->
       Printf.printf "  ✓ Error caught and formatted:\n";
       Printf.printf "    %s\n" (Error.to_string err);
       Printf.printf "  ✓ Error.to_string provides readable output (auto-reset done)\n";
       return [])
  in
  match run tx session with
  | Ok _ -> ()
  | Error e -> Printf.printf "  ✗ Unexpected error: %s\n" (Error.to_string e)

(* Example 3: Pattern matching on all error types *)
let example_error_pattern_matching session =
  Printf.printf "\nExample 3: Pattern matching on error types\n";

  let test_query statement description =
    Printf.printf "  Testing: %s\n" description;
    let open Transaction_dsl in
    let tx = catch
      (let* records = exec_query_builder (Query_builder.raw statement) in
       Printf.printf "    Query succeeded\n";
       return records)
      (fun err ->
         match err with
         | Error.ClientError { code; _ } ->
             Printf.printf "    ClientError: %s (auto-reset)\n" code;
             return []
         | Error.Database { code; _ } ->
             Printf.printf "    DatabaseError: %s (auto-reset)\n" code;
             return []
         | Error.Transient { code; _ } ->
             Printf.printf "    TransientError: %s (auto-reset)\n" code;
             return []
         | Error.Protocol msg ->
             Printf.printf "    Protocol error: %s (auto-reset)\n" (String.sub msg 0 (min 50 (String.length msg)));
             return []
         | Error.Auth msg ->
             Printf.printf "    Auth error: %s (auto-reset)\n" msg;
             return []
         | Error.Io msg ->
             Printf.printf "    I/O error: %s (auto-reset)\n" msg;
             return [])
    in
    match run tx session with
    | Ok _ -> ()
    | Error e -> Printf.printf "    Outer error: %s\n" (Error.to_string e)
  in

  test_query "RETURN 1" "Valid query";
  test_query "SYNTAX ERROR" "Invalid syntax";
  Printf.printf "  ✓ All error types matched (session auto-resets)\n"

(* Example 4: Automatic recovery after error *)
let example_error_recovery session =
  Printf.printf "\nExample 4: Automatic recovery after error\n";

  let open Transaction_dsl in

  (* First query fails, then recover with catch *)
  let tx1 = catch
    (exec_query_builder_unit (Query_builder.raw "INVALID SYNTAX"))
    (fun err ->
       let err_str = Error.to_string err in
       Printf.printf "  ✓ First query failed: %s\n"
         (String.sub err_str 0 (min 40 (String.length err_str)));
       Printf.printf "  ✓ Session automatically reset\n";
       return ())
  in
  (match run tx1 session with
   | Ok () -> ()
   | Error e -> Printf.printf "  ✗ Error: %s\n" (Error.to_string e));

  (* Second query should work immediately (auto-reset done) *)
  let tx2 = let* records = exec_query_builder
      (Query_builder.raw "RETURN 42 AS answer") in
    match records with
    | [record] ->
        (match Record.at_int record "answer" with
         | Ok n ->
             Printf.printf "  ✓ Next query works immediately, got: %Ld\n" n;
             Printf.printf "  ✓ No manual reset needed!\n";
             return ()
         | Error e ->
             Format.printf "  ✗ Decode error: %a\n" Record.pp_decode_error e;
             return ())
    | _ -> return ()
  in
  match run tx2 session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Recovery failed: %s\n" (Error.to_string e)

(* Example 5: Handling missing properties gracefully *)
let example_missing_property session =
  Printf.printf "\nExample 5: Handling missing properties\n";

  let label = Printf.sprintf "Test_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    (* Create node with only some properties *)
    let* records = exec_query_builder
        (Query_builder.create_node (Printf.sprintf "(n:%s {name: 'Alice'})" label)
         |> Query_builder.return ["n"]) in
    match records with
    | [record] ->
        (match Record.at_node record "n" with
         | Ok node ->
             (* Try to access missing property *)
             (match Value.StringMap.find_opt "age" node.props with
              | Some (Value.Int age) ->
                  Printf.printf "  Age: %Ld\n" age
              | Some _ ->
                  Printf.printf "  ✗ Age exists but wrong type\n"
              | None ->
                  Printf.printf "  ✓ Missing property handled gracefully (None)\n");

             (* Access existing property *)
             (match Value.StringMap.find_opt "name" node.props with
              | Some (Value.Text name) ->
                  Printf.printf "  ✓ Existing property retrieved: %s\n" name
              | _ ->
                  Printf.printf "  ✗ Failed to get name\n");

             (* Cleanup *)
             let* () = exec_query_builder_unit
                 (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
                  |> Query_builder.delete ["n"]) in
             Printf.printf "  ✓ Property access patterns demonstrated\n";
             return ()
         | Error e ->
             Format.printf "  ✗ Decode error: %a\n" Record.pp_decode_error e;
             return ())
    | _ -> return ()
  in
  match run tx session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Error: %s\n" (Error.to_string e)

(* Example 6: Type mismatch handling *)
let example_type_mismatch session =
  Printf.printf "\nExample 6: Type mismatch in result extraction\n";

  let open Transaction_dsl in
  let tx = let* records = exec_query_builder
      (Query_builder.raw "RETURN 'not a number' AS value") in
    match records with
    | [record] ->
        (match Value.at record "value" with
         | Some (Value.Int _n) ->
             Printf.printf "  ✗ Incorrectly matched as Int\n"
         | Some (Value.Text s) ->
             Printf.printf "  ✓ Correctly matched as Text: %s\n" s;
             Printf.printf "  ✓ Pattern matching prevents type errors\n"
         | _ ->
             Printf.printf "  ✗ Unexpected value type\n");
        return ()
    | _ -> return ()
  in
  match run tx session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 7: Handling empty results *)
let example_empty_results session =
  Printf.printf "\nExample 7: Handling empty results\n";

  let open Transaction_dsl in
  let tx = let* records = exec_query_builder
      (Query_builder.match_ "(n:NonExistentLabel)"
       |> Query_builder.return ["n"]) in
    match records with
    | [] ->
        Printf.printf "  ✓ Empty result handled correctly\n";
        Printf.printf "  ✓ No error for valid query with no results\n";
        return ()
    | values ->
        Printf.printf "  Got %d values (unexpected)\n" (List.length values);
        return ()
  in
  match run tx session with
  | Ok () -> ()
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 8: Defensive result handling with catch *)
let example_defensive_handling session =
  Printf.printf "\nExample 8: Defensive result handling pattern\n";

  let open Transaction_dsl in

  let handle_query statement =
    catch
      (let* records = exec_query_builder (Query_builder.raw statement) in
       match records with
       | [record] ->
           (* Try to extract first field *)
           (match List.hd (Value.StringMap.bindings record) with
            | (_, Value.Int n) ->
                Printf.printf "  Got single integer: %Ld\n" n;
                return ()
            | (_, Value.Text s) ->
                Printf.printf "  Got single text: %s\n" s;
                return ()
            | _ ->
                Printf.printf "  Got unexpected value type\n";
                return ())
       | [] ->
           Printf.printf "  Empty result\n";
           return ()
       | values ->
           Printf.printf "  Got %d values (processing differently)\n" (List.length values);
           return ())
      (fun err ->
         match err with
         | Error.ClientError { code; _ } ->
             Printf.printf "  Client error - user's fault: %s (auto-reset)\n" code;
             return ()
         | Error.Transient { code; _ } ->
             Printf.printf "  Transient error - could retry: %s (auto-reset)\n" code;
             return ()
         | Error.Database { code; _ } ->
             Printf.printf "  Database error - server issue: %s (auto-reset)\n" code;
             return ()
         | _ ->
             Printf.printf "  Other error: %s (auto-reset)\n" (Error.to_string err);
             return ())
  in

  let tx = let* () = handle_query "RETURN 123" in
           let* () = handle_query "RETURN 'text'" in
           let* () = handle_query "SYNTAX ERROR" in
           return () in

  (match run tx session with
   | Ok () -> Printf.printf "  ✓ Defensive pattern handles all cases\n"
   | Error e -> Printf.printf "  ✗ Error: %s\n" (Error.to_string e))

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Error Handling Patterns - BETTER_API Edition\n";
    Printf.printf "=============================================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_syntax_error session;
        example_error_to_string session;
        example_error_pattern_matching session;
        example_error_recovery session;
        example_missing_property session;
        example_type_mismatch session;
        example_empty_results session;
        example_defensive_handling session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All error handling examples completed!\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
