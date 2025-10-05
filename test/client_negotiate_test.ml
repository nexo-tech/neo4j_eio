open Neo4j_eio

let test_client_connect env cfg =
  Eio.Switch.run @@ fun sw ->
    match Client.connect_and_handshake ~sw ~net:env#net cfg with
    | Ok v ->
        Alcotest.(check bool) "v3+" true (Protocol.is_new_version v)
    | Error e ->
        Alcotest.failf "Client connect failed: %s" (Error.to_string e)

let () =
  Alcotest.run "client"
    [ "connect", [ Test_helper.with_neo4j "client handshake" `Quick test_client_connect ] ]

