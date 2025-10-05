(* Neo4j connection configuration *)

type log_level =
  | Debug
  | Info
  | Warn
  | Error
  | Silent

type t = {
  uri : string;              (* Full connection URI (e.g., "bolt://localhost:7687") *)
  user : string;             (* Neo4j username *)
  password : string;         (* Neo4j password *)
  user_agent : string;       (* Driver user agent string *)
  fetch_size : int;          (* Number of records to fetch per batch *)
  use_tls : bool;            (* Whether to use TLS/SSL *)
  tls_ca : string option;    (* Path to TLS CA certificate file *)
  log_level : log_level;     (* Logging verbosity level *)
  protocols : int list;      (* Bolt protocol versions to negotiate, in order of preference *)
}

(* Default configuration matching docker-compose setup:
   - URI: bolt://127.0.0.1:7687
   - User: neo4j
   - Password: testpass
   - No TLS
   - Fetch size: 1000
   - User agent: neo4j_eio/0.1.0
   - Protocols: [5; 4; 3] (Bolt 5.x, 4.x, 3.x)
*)
val default : unit -> t

(* Create config from environment variables:
   - NEO4J_URI or NEO4J_HOST + NEO4J_PORT
   - NEO4J_USER or NEO4J_USERNAME
   - NEO4J_PASSWORD
   - NEO4J_TLS (1/true/yes to enable)
   - NEO4J_FETCH_SIZE
   - NEO4J_USER_AGENT
   - NEO4J_LOG_LEVEL (debug/info/warn/error/silent)
*)
val of_env : unit -> t

(* Parse URI into host and port *)
val parse_uri : string -> (string * int, string) result

(* Helper to create config with custom values *)
val make :
  ?uri:string ->
  ?user:string ->
  ?password:string ->
  ?user_agent:string ->
  ?fetch_size:int ->
  ?use_tls:bool ->
  ?tls_ca:string ->
  ?log_level:log_level ->
  ?protocols:int list ->
  unit ->
  t
