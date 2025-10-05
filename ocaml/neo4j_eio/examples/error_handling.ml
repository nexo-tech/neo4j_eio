(* File: examples/error_handling.ml *)
(* Task 1.2: Demonstrates error handling patterns *)

open Neo4j_eio

(* Example 1: Syntax error handling (ClientError) *)
let example_syntax_error session =
  Printf.printf "Example 1: Syntax error (ClientError)\n";

  match Neo4j.query session
    ~statement:"INVALID CYPHER SYNTAX HERE"
    () with
  | Ok _ ->
      Printf.printf "  ✗ Unexpectedly succeeded\n"
  | Error (Error.ClientError { code; message }) ->
      Printf.printf "  ✓ Caught ClientError\n";
      Printf.printf "    Code: %s\n" code;
      Printf.printf "    Message: %s\n" (String.sub message 0 (min 60 (String.length message)));
      Printf.printf "  ✓ Syntax errors are properly classified\n"
  | Error e ->
      Printf.printf "  ✗ Got different error type: %s\n" (Error.to_string e)

(* Example 2: Using Error.to_string for display *)
let example_error_to_string session =
  Printf.printf "\nExample 2: Error.to_string usage\n";

  match Neo4j.query session
    ~statement:"MATCH (n:NonExistent) WHERE n.invalid RETURN invalid.field"
    () with
  | Ok _ ->
      Printf.printf "  ✗ Unexpectedly succeeded\n"
  | Error e ->
      Printf.printf "  ✓ Error caught and formatted:\n";
      Printf.printf "    %s\n" (Error.to_string e);
      Printf.printf "  ✓ Error.to_string provides readable output (auto-reset done)\n"

(* Example 3: Pattern matching on all error types *)
let example_error_pattern_matching session =
  Printf.printf "\nExample 3: Pattern matching on error types\n";

  let test_query statement description =
    Printf.printf "  Testing: %s\n" description;
    match Neo4j.query session ~statement () with
    | Ok _ ->
        Printf.printf "    Query succeeded\n"
    | Error (Error.ClientError { code; _ }) ->
        Printf.printf "    ClientError: %s (auto-reset)\n" code
    | Error (Error.Database { code; _ }) ->
        Printf.printf "    DatabaseError: %s (auto-reset)\n" code
    | Error (Error.Transient { code; _ }) ->
        Printf.printf "    TransientError: %s (auto-reset)\n" code
    | Error (Error.Protocol msg) ->
        Printf.printf "    Protocol error: %s (auto-reset)\n" (String.sub msg 0 (min 50 (String.length msg)))
    | Error (Error.Auth msg) ->
        Printf.printf "    Auth error: %s (auto-reset)\n" msg
    | Error (Error.Io msg) ->
        Printf.printf "    I/O error: %s (auto-reset)\n" msg
  in

  test_query "RETURN 1" "Valid query";
  test_query "SYNTAX ERROR" "Invalid syntax";
  Printf.printf "  ✓ All error types matched (session auto-resets)\n"

(* Example 4: Automatic recovery after error *)
let example_error_recovery session =
  Printf.printf "\nExample 4: Automatic recovery after error\n";

  (* First query fails *)
  (match Neo4j.query session ~statement:"INVALID SYNTAX" () with
   | Ok _ -> Printf.printf "  ✗ First query unexpectedly succeeded\n"
   | Error e ->
       Printf.printf "  ✓ First query failed: %s\n"
         (String.sub (Error.to_string e) 0 (min 40 (String.length (Error.to_string e))));
       Printf.printf "  ✓ Session automatically reset\n");

  (* Second query should work immediately (auto-reset done) *)
  match Neo4j.query session ~statement:"RETURN 42 AS answer" () with
  | Ok [record] ->
      (match Record.at_int record "answer" with
       | Ok n ->
           Printf.printf "  ✓ Next query works immediately, got: %Ld\n" n;
           Printf.printf "  ✓ No manual reset needed!\n"
       | Error e ->
           Printf.printf "  ✗ Decode error: %a\n" Record.pp_decode_error e)
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Recovery failed: %s\n" (Error.to_string e)

(* Example 5: Handling missing properties gracefully *)
let example_missing_property session =
  Printf.printf "\nExample 5: Handling missing properties\n";

  let label = Printf.sprintf "Test_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create node with only some properties *)
  match query session
    ~statement:(Printf.sprintf "CREATE (n:%s {name: 'Alice'}) RETURN n" label)
    () with
  | Error e ->
      Printf.eprintf "  ✗ Create failed: %s\n" (Error.to_string e)
  | Ok [record] ->
      (match Value.at record "n" with
       | Some (Value.Node node) ->
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
           let _ = query_ session
             ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
             () in
           Printf.printf "  ✓ Property access patterns demonstrated\n"
       | _ ->
           Printf.printf "  ✗ Unexpected value type\n")
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"

(* Example 6: Type mismatch handling *)
let example_type_mismatch session =
  Printf.printf "\nExample 6: Type mismatch in result extraction\n";

  match Neo4j.query session
    ~statement:"RETURN 'not a number' AS value"
    () with
  | Ok [record] ->
      (match Value.at record "value" with
       | Some (Value.Int _n) ->
           Printf.printf "  ✗ Incorrectly matched as Int\n"
       | Some (Value.Text s) ->
           Printf.printf "  ✓ Correctly matched as Text: %s\n" s;
           Printf.printf "  ✓ Pattern matching prevents type errors\n"
       | _ ->
           Printf.printf "  ✗ Unexpected value type\n")
  | Ok _ ->
      Printf.printf "  ✗ Unexpected result format\n"
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 7: Handling empty results *)
let example_empty_results session =
  Printf.printf "\nExample 7: Handling empty results\n";

  match Neo4j.query session
    ~statement:"MATCH (n:NonExistentLabel) RETURN n"
    () with
  | Ok [] ->
      Printf.printf "  ✓ Empty result handled correctly\n";
      Printf.printf "  ✓ No error for valid query with no results\n"
  | Ok values ->
      Printf.printf "  Got %d values (unexpected)\n" (List.length values)
  | Error e ->
      Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 8: Defensive result handling *)
let example_defensive_handling session =
  Printf.printf "\nExample 8: Defensive result handling pattern\n";

  let handle_query_result result =
    match result with
    | Ok [record] ->
        (* Try to extract as int first, then text *)
        (match Value.at record (List.hd (Value.StringMap.bindings record) |> fst) with
         | Some (Value.Int n) ->
             Printf.printf "  Got single integer: %Ld\n" n;
             Ok ()
         | Some (Value.Text s) ->
             Printf.printf "  Got single text: %s\n" s;
             Ok ()
         | _ ->
             Printf.printf "  Got unexpected value type\n";
             Ok ())
    | Ok [] ->
        Printf.printf "  Empty result\n";
        Ok ()
    | Ok values ->
        Printf.printf "  Got %d values (processing differently)\n" (List.length values);
        Ok ()
    | Error (Error.ClientError { code; message }) ->
        Printf.printf "  Client error - user's fault: %s (auto-reset)\n" code;
        Error message
    | Error (Error.Transient { code; _ }) ->
        Printf.printf "  Transient error - could retry: %s (auto-reset)\n" code;
        Error "Retry needed"
    | Error (Error.Database { code; _ }) ->
        Printf.printf "  Database error - server issue: %s (auto-reset)\n" code;
        Error "Server error"
    | Error e ->
        Printf.printf "  Other error: %s (auto-reset)\n" (Error.to_string e);
        Error "Generic error"
  in

  let _ = handle_query_result (Neo4j.query session ~statement:"RETURN 123" ()) in
  let _ = handle_query_result (Neo4j.query session ~statement:"RETURN 'text'" ()) in
  let _ = handle_query_result (Neo4j.query session ~statement:"SYNTAX ERROR" ()) in
  Printf.printf "  ✓ Defensive pattern handles all cases\n"

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Error Handling Patterns\n";
    Printf.printf "=======================\n\n";

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
