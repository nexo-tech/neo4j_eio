open Neo4j_eio

(* Check if Neo4j is available at localhost:7687 *)
let is_neo4j_available ~net cfg : bool =
  try
    Eio.Switch.run @@ fun sw ->
      match Connection.handshake ~sw ~net cfg with
      | Ok _ -> true
      | Error _ -> false
  with
  | _ -> false

(* Run a test that requires Neo4j, skipping if unavailable *)
let with_neo4j name speed test_fn =
  Alcotest.test_case name speed (fun () ->
    let cfg = Config.of_env () in
    Eio_main.run @@ fun env ->
      if is_neo4j_available ~net:env#net cfg then
        test_fn env cfg
      else
        Alcotest.skip ())

(* Run a test that requires Neo4j, failing if unavailable *)
let require_neo4j name speed test_fn =
  Alcotest.test_case name speed (fun () ->
    let cfg = Config.of_env () in
    Eio_main.run @@ fun env ->
      if not (is_neo4j_available ~net:env#net cfg) then
        Alcotest.failf
          "Neo4j required but unavailable at %s - ensure Docker container is running (docker compose up -d neo4j)"
          cfg.uri
      else
        test_fn env cfg)
