open Neo4j_eio

let test_auth_v5 env cfg =
  Eio.Switch.run @@ fun sw ->
    match Connection.authenticate ~sw ~net:env#net cfg with
    | Ok (version, flow) ->
        Alcotest.(check bool) "v5 or v4 negotiated" true
          (Protocol.is_new_version version);
        Connection.goodbye flow
    | Error e ->
        Alcotest.failf "Authentication failed: %s" (Error.to_string e)

let test_auth_goodbye env cfg =
  Eio.Switch.run @@ fun sw ->
    match Connection.authenticate ~sw ~net:env#net cfg with
    | Ok (_version, flow) ->
        (* Send GOODBYE and close *)
        Connection.goodbye flow;
        Alcotest.(check bool) "goodbye sent" true true
    | Error e ->
        Alcotest.failf "Authentication failed: %s" (Error.to_string e)

let test_auth_wrong_password env cfg =
  let bad_cfg : Config.t = { Config.host = cfg.Config.host; port = cfg.port; user = cfg.user;
                             password = "wrongpassword"; use_tls = cfg.use_tls } in
  Eio.Switch.run @@ fun sw ->
    match Connection.authenticate ~sw ~net:env#net bad_cfg with
    | Ok (_version, flow) ->
        Connection.goodbye flow;
        Alcotest.fail "Expected authentication to fail with wrong password"
    | Error (Error.Auth msg) ->
        Alcotest.(check bool) "auth error received" true (String.length msg > 0)
    | Error e ->
        Alcotest.failf "Expected Auth error, got: %s" (Error.to_string e)

let () =
  Alcotest.run "authentication"
    [ "auth flows", [
        Test_helper.with_neo4j "authenticate with v5/v4" `Quick test_auth_v5;
        Test_helper.with_neo4j "goodbye" `Quick test_auth_goodbye;
        Test_helper.with_neo4j "wrong password" `Quick test_auth_wrong_password;
      ]
    ]
