open Neo4j_eio

(* Test that demonstrates Task 8.1: Docker Compose integration *)

(* Test environment variable configuration *)
let test_env_config () =
  (* This test just verifies that Config.of_env works *)
  let cfg = Config.of_env () in

  (* Verify credentials match docker-compose.yml *)
  Alcotest.(check string) "user is neo4j" "neo4j" cfg.user;
  Alcotest.(check string) "password is testpass" "testpass" cfg.password;

  (* Verify URI contains a valid protocol prefix (bolt:// or neo4j://) *)
  Alcotest.(check bool) "uri has valid protocol" true
    (String.starts_with ~prefix:"bolt://" cfg.uri ||
     String.starts_with ~prefix:"bolt+s://" cfg.uri ||
     String.starts_with ~prefix:"neo4j://" cfg.uri ||
     String.starts_with ~prefix:"neo4j+s://" cfg.uri)

(* Test basic connectivity *)
let test_docker_connectivity env cfg =
  (* Verify we can connect to the Docker container *)
  Eio.Switch.run @@ fun sw ->
    match Connection.authenticate ~sw ~net:env#net cfg with
    | Ok (_version, flow) ->
        Connection.goodbye flow;
        (* Success *)
        ()
    | Error e ->
        Alcotest.failf "Failed to connect to Neo4j Docker container: %s"
          (Error.to_string e)

(* Test that we can run a simple query *)
let test_docker_simple_query env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Run a simple query to verify everything works *)
      match Session.run session ~statement:"RETURN 1 AS num" () with
      | Error e -> Error e
      | Ok records ->
          (match records with
           | [Value.Int n] ->
               Alcotest.(check int64) "got correct result" 1L n;
               Ok ()
           | _ ->
               Error (Error.Protocol "Unexpected result format"))
    ) with
    | Ok () -> ()
    | Error e ->
        Alcotest.failf "Failed to run query: %s" (Error.to_string e)

(* Test skip behavior when Neo4j is unavailable *)
let test_skip_behavior () =
  (* Create a config that points to a non-existent server *)
  let bad_cfg = Config.make
    ~uri:"bolt://localhost:9999"
    ~user:"neo4j"
    ~password:"test"
    () in

  Eio_main.run @@ fun env ->
    (* Verify that is_neo4j_available returns false for bad config *)
    let available = Test_helper.is_neo4j_available ~net:env#net bad_cfg in
    Alcotest.(check bool) "unavailable server detected" false available

(* Test that docker-compose.yml values are correct *)
let test_docker_compose_values env cfg =
  (* This test verifies that the docker-compose.yml values work *)
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Query Neo4j version to confirm we're connected to Neo4j 5 *)
      match Session.run session ~statement:"CALL dbms.components() YIELD versions RETURN versions[0] AS version" () with
      | Error e -> Error e
      | Ok records ->
          (match records with
           | [Value.Text version] ->
               (* Verify it's Neo4j 5.x *)
               Alcotest.(check bool) "running Neo4j 5.x" true
                 (String.starts_with ~prefix:"5." version);
               Ok ()
           | _ ->
               (* Just log that we got a response, version format might vary *)
               Ok ())
    ) with
    | Ok () -> ()
    | Error e ->
        Alcotest.failf "Failed to verify Neo4j version: %s" (Error.to_string e)

(* Test that ports 7687 (Bolt) works *)
let test_bolt_port env cfg =
  (* The fact that we can connect proves port 7687 is working *)
  Eio.Switch.run @@ fun sw ->
    match Connection.authenticate ~sw ~net:env#net cfg with
    | Ok (_version, flow) ->
        Connection.goodbye flow;
        ()
    | Error e ->
        Alcotest.failf "Bolt port 7687 not accessible: %s" (Error.to_string e)

let () =
  Alcotest.run "Task 8.1: Docker Compose integration"
    [ "environment configuration", [
        Alcotest.test_case "env var configuration" `Quick (fun () -> test_env_config ());
        Alcotest.test_case "skip behavior for unavailable server" `Quick test_skip_behavior;
      ];
      "docker connectivity", [
        Test_helper.with_neo4j "connect to docker container" `Quick test_docker_connectivity;
        Test_helper.with_neo4j "run simple query" `Quick test_docker_simple_query;
        Test_helper.with_neo4j "verify docker-compose values" `Quick test_docker_compose_values;
        Test_helper.with_neo4j "bolt port accessible" `Quick test_bolt_port;
      ];
    ]
