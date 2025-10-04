open Neo4j_eio

(* Test default configuration *)
let test_default_config () =
  let cfg = Config.default () in
  Alcotest.(check string) "default uri" "bolt://127.0.0.1:7687" cfg.uri;
  Alcotest.(check string) "default user" "neo4j" cfg.user;
  Alcotest.(check string) "default password" "testpass" cfg.password;
  Alcotest.(check string) "default user_agent" "neo4j_eio/0.1.0" cfg.user_agent;
  Alcotest.(check int) "default fetch_size" 1000 cfg.fetch_size;
  Alcotest.(check bool) "default use_tls" false cfg.use_tls;
  Alcotest.(check bool) "default tls_ca" true (cfg.tls_ca = None);
  Alcotest.(check bool) "default log_level" true (cfg.log_level = Config.Info);
  Alcotest.(check bool) "default protocols" true (cfg.protocols = [5; 4; 3])

(* Test parse_uri function *)
let test_parse_uri () =
  (* Test bolt:// URI *)
  (match Config.parse_uri "bolt://localhost:7687" with
   | Ok ("localhost", 7687) -> ()
   | Ok (h, p) -> Alcotest.fail (Printf.sprintf "wrong parse: %s:%d" h p)
   | Error e -> Alcotest.fail e);

  (* Test bolt+s:// URI *)
  (match Config.parse_uri "bolt+s://example.com:7688" with
   | Ok ("example.com", 7688) -> ()
   | Ok (h, p) -> Alcotest.fail (Printf.sprintf "wrong parse: %s:%d" h p)
   | Error e -> Alcotest.fail e);

  (* Test plain host:port *)
  (match Config.parse_uri "192.168.1.1:7687" with
   | Ok ("192.168.1.1", 7687) -> ()
   | Ok (h, p) -> Alcotest.fail (Printf.sprintf "wrong parse: %s:%d" h p)
   | Error e -> Alcotest.fail e);

  (* Test host without port (should default to 7687) *)
  (match Config.parse_uri "bolt://myserver" with
   | Ok ("myserver", 7687) -> ()
   | Ok (h, p) -> Alcotest.fail (Printf.sprintf "wrong parse: %s:%d" h p)
   | Error e -> Alcotest.fail e);

  (* Test invalid URI *)
  match Config.parse_uri "not:a:valid:uri:format" with
  | Ok _ -> Alcotest.fail "should have failed to parse"
  | Error _ -> ()

(* Test make function with custom values *)
let test_make_config () =
  let cfg = Config.make
    ~uri:"bolt://custom:7688"
    ~user:"alice"
    ~password:"secret"
    ~user_agent:"my_app/1.0"
    ~fetch_size:500
    ~use_tls:true
    ~tls_ca:"/path/to/ca.pem"
    ~log_level:Config.Debug
    ~protocols:[5; 4]
    () in
  Alcotest.(check string) "custom uri" "bolt://custom:7688" cfg.uri;
  Alcotest.(check string) "custom user" "alice" cfg.user;
  Alcotest.(check string) "custom password" "secret" cfg.password;
  Alcotest.(check string) "custom user_agent" "my_app/1.0" cfg.user_agent;
  Alcotest.(check int) "custom fetch_size" 500 cfg.fetch_size;
  Alcotest.(check bool) "custom use_tls" true cfg.use_tls;
  Alcotest.(check bool) "custom tls_ca" true (cfg.tls_ca = Some "/path/to/ca.pem");
  Alcotest.(check bool) "custom log_level" true (cfg.log_level = Config.Debug);
  Alcotest.(check bool) "custom protocols" true (cfg.protocols = [5; 4])

(* Test make function with defaults *)
let test_make_config_defaults () =
  let cfg = Config.make () in
  Alcotest.(check string) "default uri" "bolt://127.0.0.1:7687" cfg.uri;
  Alcotest.(check string) "default user" "neo4j" cfg.user;
  Alcotest.(check string) "default password" "testpass" cfg.password;
  Alcotest.(check int) "default fetch_size" 1000 cfg.fetch_size;
  Alcotest.(check bool) "default use_tls" false cfg.use_tls

(* Test make function with partial custom values *)
let test_make_config_partial () =
  let cfg = Config.make ~user:"bob" ~fetch_size:2000 () in
  Alcotest.(check string) "custom user" "bob" cfg.user;
  Alcotest.(check int) "custom fetch_size" 2000 cfg.fetch_size;
  Alcotest.(check string) "default uri" "bolt://127.0.0.1:7687" cfg.uri;
  Alcotest.(check string) "default password" "testpass" cfg.password

(* Test that defaults match docker-compose *)
let test_defaults_match_compose () =
  let cfg = Config.default () in
  (* docker-compose uses bolt://127.0.0.1:7687, neo4j/testpass, no TLS *)
  Alcotest.(check string) "compose uri" "bolt://127.0.0.1:7687" cfg.uri;
  Alcotest.(check string) "compose user" "neo4j" cfg.user;
  Alcotest.(check string) "compose password" "testpass" cfg.password;
  Alcotest.(check bool) "compose no TLS" false cfg.use_tls;
  Alcotest.(check int) "compose fetch_size" 1000 cfg.fetch_size

(* Test of_env with environment variables *)
let test_of_env () =
  (* Save current env *)
  let save_env key = try Some (Sys.getenv key) with Not_found -> None in
  let saved_uri = save_env "NEO4J_URI" in
  let saved_user = save_env "NEO4J_USER" in
  let saved_password = save_env "NEO4J_PASSWORD" in
  let saved_fetch_size = save_env "NEO4J_FETCH_SIZE" in

  (* Set test env *)
  Unix.putenv "NEO4J_URI" "bolt://testhost:9999";
  Unix.putenv "NEO4J_USER" "testuser";
  Unix.putenv "NEO4J_PASSWORD" "testpass123";
  Unix.putenv "NEO4J_FETCH_SIZE" "2500";

  let cfg = Config.of_env () in
  Alcotest.(check string) "env uri" "bolt://testhost:9999" cfg.uri;
  Alcotest.(check string) "env user" "testuser" cfg.user;
  Alcotest.(check string) "env password" "testpass123" cfg.password;
  Alcotest.(check int) "env fetch_size" 2500 cfg.fetch_size;

  (* Restore env *)
  (match saved_uri with Some v -> Unix.putenv "NEO4J_URI" v | None -> Unix.putenv "NEO4J_URI" "");
  (match saved_user with Some v -> Unix.putenv "NEO4J_USER" v | None -> Unix.putenv "NEO4J_USER" "");
  (match saved_password with Some v -> Unix.putenv "NEO4J_PASSWORD" v | None -> Unix.putenv "NEO4J_PASSWORD" "");
  (match saved_fetch_size with Some v -> Unix.putenv "NEO4J_FETCH_SIZE" v | None -> Unix.putenv "NEO4J_FETCH_SIZE" "")

(* Test of_env with HOST+PORT instead of URI *)
let test_of_env_host_port () =
  let save_env key = try Some (Sys.getenv key) with Not_found -> None in
  let saved_uri = save_env "NEO4J_URI" in
  let saved_host = save_env "NEO4J_HOST" in
  let saved_port = save_env "NEO4J_PORT" in

  Unix.putenv "NEO4J_URI" "";
  Unix.putenv "NEO4J_HOST" "myhost";
  Unix.putenv "NEO4J_PORT" "8888";

  let cfg = Config.of_env () in
  Alcotest.(check string) "env host+port uri" "bolt://myhost:8888" cfg.uri;

  (* Restore env *)
  (match saved_uri with Some v -> Unix.putenv "NEO4J_URI" v | None -> Unix.putenv "NEO4J_URI" "");
  (match saved_host with Some v -> Unix.putenv "NEO4J_HOST" v | None -> Unix.putenv "NEO4J_HOST" "");
  (match saved_port with Some v -> Unix.putenv "NEO4J_PORT" v | None -> Unix.putenv "NEO4J_PORT" "")

let () =
  Alcotest.run "Config module"
    [ "default config", [
        Alcotest.test_case "default" `Quick test_default_config;
        Alcotest.test_case "defaults match compose" `Quick test_defaults_match_compose;
      ];
      "parse_uri", [
        Alcotest.test_case "parse various URIs" `Quick test_parse_uri;
      ];
      "make config", [
        Alcotest.test_case "make with custom values" `Quick test_make_config;
        Alcotest.test_case "make with defaults" `Quick test_make_config_defaults;
        Alcotest.test_case "make with partial values" `Quick test_make_config_partial;
      ];
      "of_env", [
        Alcotest.test_case "of_env with URI" `Quick test_of_env;
        Alcotest.test_case "of_env with HOST+PORT" `Quick test_of_env_host_port;
      ];
    ]
