open Neo4j_eio

(* Test that RESET clears failed state and allows recovery *)
let test_reset_after_failure env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Execute invalid query to cause FAILURE *)
      let invalid_result = Session.run session ~statement:"INVALID CYPHER SYNTAX" () in

      (* Should get an error *)
      (match invalid_result with
      | Error (Error.ClientError { code; _ }) ->
          Alcotest.(check bool) "got client error"
            (String.starts_with ~prefix:"Neo.ClientError" code) true
      | Error e ->
          Alcotest.failf "Expected ClientError but got: %s" (Error.to_string e)
      | Ok _ ->
          Alcotest.failf "Expected error but query succeeded");

      (* Reset the session *)
      match Session.reset session with
      | Error e ->
          Alcotest.failf "RESET failed: %s" (Error.to_string e)
      | Ok () ->
          (* Now execute a valid query *)
          match Session.run session ~statement:"RETURN 1 AS n" () with
          | Ok records ->
              Alcotest.(check int) "got record after reset" 1 (List.length records);
              Ok ()
          | Error e ->
              Alcotest.failf "Query after RESET failed: %s" (Error.to_string e)
    ) with
    | Ok () ->
        Alcotest.(check bool) "reset recovery works" true true
    | Error e ->
        Alcotest.failf "Session failed: %s" (Error.to_string e)

(* Test that errors are properly typed *)
let test_error_classification env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Syntax error - should be ClientError *)
      (match Session.run session ~statement:"BAD SYNTAX" () with
      | Error (Error.ClientError { code; message }) ->
          Alcotest.(check bool) "is client error"
            (String.starts_with ~prefix:"Neo.ClientError" code) true;
          Alcotest.(check bool) "has error message"
            (String.length message > 0) true
      | Error e ->
          Alcotest.failf "Expected ClientError but got: %s" (Error.to_string e)
      | Ok _ ->
          Alcotest.failf "Expected error but query succeeded");

      (* Reset for next test *)
      let _ = Session.reset session in

      (* Undefined variable - should be ClientError *)
      (match Session.run session ~statement:"RETURN unknownVar" () with
      | Error (Error.ClientError _) ->
          ()
      | Error e ->
          Alcotest.failf "Expected ClientError but got: %s" (Error.to_string e)
      | Ok _ ->
          Alcotest.failf "Expected error but query succeeded");

      Ok ()
    ) with
    | Ok () ->
        Alcotest.(check bool) "error classification works" true true
    | Error e ->
        Alcotest.failf "Session failed: %s" (Error.to_string e)

(* Test multiple failures and resets *)
let test_multiple_resets env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      for i = 1 to 3 do
        (* Cause a failure *)
        let _ = Session.run session ~statement:"INVALID QUERY" () in

        (* Reset *)
        match Session.reset session with
        | Error e ->
            Alcotest.failf "RESET %d failed: %s" i (Error.to_string e)
        | Ok () ->
            (* Verify session is usable *)
            match Session.run session ~statement:(Printf.sprintf "RETURN %d AS n" i) () with
            | Ok records ->
                Alcotest.(check int) (Printf.sprintf "reset %d works" i) 1 (List.length records)
            | Error e ->
                Alcotest.failf "Query after RESET %d failed: %s" i (Error.to_string e)
      done;
      Ok ()
    ) with
    | Ok () ->
        Alcotest.(check bool) "multiple resets work" true true
    | Error e ->
        Alcotest.failf "Session failed: %s" (Error.to_string e)

let () =
  Alcotest.run "error handling and reset"
    [ "reset", [
        Test_helper.require_neo4j "reset after failure" `Quick test_reset_after_failure;
        Test_helper.require_neo4j "error classification" `Quick test_error_classification;
        Test_helper.require_neo4j "multiple resets" `Quick test_multiple_resets;
      ]
    ]
