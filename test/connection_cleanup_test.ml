open Neo4j_eio

(* Test with_connection ensures GOODBYE is sent *)
let test_with_connection_normal env cfg =
  Eio.Switch.run @@ fun sw ->
    let result = Connection.with_connection ~sw ~net:env#net cfg (fun flow _version ->
      (* Run a simple query and return the result *)
      Ok (Connection.run_query flow ~statement:"RETURN 1" ())
    ) in
    match result with
    | Ok (Ok records) ->
        Alcotest.(check int) "got 1 record" 1 (List.length records)
    | Ok (Error e) ->
        Alcotest.failf "Query failed: %s" (Error.to_string e)
    | Error e ->
        Alcotest.failf "Connection failed: %s" (Error.to_string e)

(* Test with_connection handles exceptions properly *)
let test_with_connection_exception env cfg =
  Eio.Switch.run @@ fun sw ->
    let result = Connection.with_connection ~sw ~net:env#net cfg (fun _flow _version ->
      failwith "Intentional error"
    ) in
    match result with
    | Error (Error.Io msg) ->
        (* The exception message should be wrapped *)
        Alcotest.(check bool) "exception caught and wrapped"
          (String.length msg > 0 && (String.contains msg '(' || String.contains msg 'I')) true
    | Ok _ ->
        Alcotest.fail "Expected exception to be caught"
    | Error e ->
        Alcotest.failf "Wrong error type: %s" (Error.to_string e)

(* Test with_connection cleanup on auth failure *)
let test_with_connection_auth_fail env cfg =
  Eio.Switch.run @@ fun sw ->
    let bad_cfg = { cfg with Config.password = "wrongpassword" } in
    match Connection.with_connection ~sw ~net:env#net bad_cfg (fun _flow _version ->
      Ok ()
    ) with
    | Ok _ ->
        Alcotest.fail "Expected authentication to fail"
    | Error (Error.Auth _) ->
        Alcotest.(check bool) "auth error received" true true
    | Error e ->
        Alcotest.failf "Wrong error type: %s" (Error.to_string e)

let () =
  Alcotest.run "connection cleanup"
    [ "with_connection", [
        Test_helper.with_neo4j "normal flow" `Quick test_with_connection_normal;
        Test_helper.with_neo4j "exception handling" `Quick test_with_connection_exception;
        Test_helper.with_neo4j "auth failure cleanup" `Quick test_with_connection_auth_fail;
      ]
    ]
