open Neo4j_eio

let test_handshake env cfg =
  Eio.Switch.run @@ fun sw ->
    match Connection.handshake ~sw ~net:env#net cfg with
    | Ok v ->
        Alcotest.(check bool) "v3+ negotiated" true (Protocol.is_new_version v)
    | Error e ->
        Alcotest.failf "Handshake failed: %s" (Error.to_string e)

let () =
  Alcotest.run "neo4j_eio"
    [ "handshake", [ Test_helper.with_neo4j "connect and negotiate" `Quick test_handshake ] ]
