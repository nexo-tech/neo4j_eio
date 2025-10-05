(** {1 Neo4j Connection Configuration}

    This module defines configuration for connecting to Neo4j databases over the
    Bolt protocol. It provides utilities for creating configurations from environment
    variables, parsing URIs, and setting connection parameters.

    {2 Environment-Driven Configuration}

    For quick setup in development and testing, use {!of_env} which reads standard
    Neo4j environment variables. The defaults are designed to work with the
    docker-compose setup commonly used in Neo4j development.
*)

(** Logging verbosity levels.

    Controls the amount of diagnostic output from the driver. Currently defined
    but not fully implemented in all code paths.
*)
type log_level =
  | Debug   (** Verbose diagnostic information including protocol messages *)
  | Info    (** General informational messages about connections and queries *)
  | Warn    (** Warning messages for recoverable issues *)
  | Error   (** Error messages for failures *)
  | Silent  (** No logging output *)

(** Neo4j connection configuration.

    All fields except [tls_ca] are required. Use {!make} or {!of_env} to construct
    configurations with sensible defaults.
*)
type t = {
  uri : string;
    (** Full connection URI (e.g., ["bolt://localhost:7687"]).
        Supports schemes: [bolt://], [bolt+s://], [neo4j://], [neo4j+s://].
        The [+s] variants indicate TLS should be used. *)

  user : string;
    (** Neo4j username for authentication.
        Default database credentials are typically [neo4j]/[neo4j] or [neo4j]/[testpass]. *)

  password : string;
    (** Neo4j password for authentication. *)

  user_agent : string;
    (** Driver user agent string sent during HELLO.
        Identifies this driver in Neo4j server logs and monitoring. *)

  fetch_size : int;
    (** Number of records to fetch per PULL request.
        Larger values reduce round trips but increase memory usage.
        Default is 1000. *)

  use_tls : bool;
    (** Whether to use TLS/SSL encryption for the connection.
        Note: TLS support is currently limited; use [false] for now. *)

  tls_ca : string option;
    (** Path to TLS CA certificate file for verification.
        Only used when [use_tls = true]. *)

  log_level : log_level;
    (** Logging verbosity level.
        Default is [Info]. *)

  protocols : int list;
    (** Bolt protocol versions to propose during handshake, in order of preference.
        Default is [[5; 4; 3]] for maximum compatibility.
        The server will select the highest mutually supported version. *)
}

(** Create a default configuration for local development.

    Returns a configuration with sensible defaults matching the typical docker-compose
    Neo4j setup used in development:

    - URI: [bolt://127.0.0.1:7687]
    - User: [neo4j]
    - Password: [testpass]
    - TLS: disabled
    - Fetch size: [1000]
    - User agent: [neo4j_eio/0.1.0]
    - Log level: [Info]
    - Protocols: [[5; 4; 3]] (Bolt v5, v4, v3 in preference order)

    {2 Example}

    {[
      let cfg = Config.default () in
      let cfg' = { cfg with password = "my_password" } in
      Session.with_session ~sw ~net cfg' (fun session -> ...)
    ]}

    @return A configuration with development-friendly defaults
    @since 0.1.0
*)
val default : unit -> t

(** Create configuration from environment variables.

    Reads configuration from standard Neo4j environment variables, falling back
    to {!default} values when variables are not set. This is the recommended way
    to configure the driver in both development and production.

    {2 Environment Variables}

    - [NEO4J_URI]: Full connection URI (e.g., ["bolt://localhost:7687"])
    - [NEO4J_HOST]: Hostname (used if [NEO4J_URI] not set)
    - [NEO4J_PORT]: Port number (used with [NEO4J_HOST], default 7687)
    - [NEO4J_USER] or [NEO4J_USERNAME]: Username for authentication
    - [NEO4J_PASSWORD]: Password for authentication
    - [NEO4J_TLS]: Enable TLS if set to ["1"], ["true"], or ["yes"] (case-insensitive)
    - [NEO4J_TLS_CA]: Path to CA certificate file
    - [NEO4J_FETCH_SIZE]: Number of records to fetch per batch
    - [NEO4J_USER_AGENT]: Custom user agent string
    - [NEO4J_LOG_LEVEL]: One of [debug], [info], [warn], [error], or [silent]

    {2 Example}

    {[
      (* With environment variables set *)
      export NEO4J_URI=bolt://prod.example.com:7687
      export NEO4J_USER=app_user
      export NEO4J_PASSWORD=secure_pass

      (* In OCaml *)
      let cfg = Config.of_env () in
      Session.with_session ~sw ~net cfg (fun session -> ...)
    ]}

    @return Configuration populated from environment with defaults for missing values
    @since 0.1.0
*)
val of_env : unit -> t

(** Parse a Neo4j connection URI.

    Extracts the hostname and port from a connection URI. Supports multiple URI
    schemes and falls back to parsing as bare [host:port] if no scheme is present.

    {2 Supported URI Schemes}

    - [bolt://host:port] - Plain Bolt protocol
    - [bolt+s://host:port] - Bolt with TLS
    - [neo4j://host:port] - Neo4j URI (routes to Bolt)
    - [neo4j+s://host:port] - Neo4j URI with TLS
    - [host:port] - Bare host:port pair

    @param uri Connection URI string
    @return [Ok (host, port)] if parsing succeeds
    @return [Error msg] with descriptive error message if parsing fails

    {2 Example}

    {[
      match Config.parse_uri "bolt://db.example.com:7687" with
      | Ok (host, port) ->
          Printf.printf "Host: %s, Port: %d\\n" host port
      | Error msg ->
          Printf.eprintf "Parse error: %s\\n" msg
    ]}

    @since 0.1.0
*)
val parse_uri : string -> (string * int, string) result

(** Create a custom configuration.

    Constructs a configuration with specified values, using defaults from {!default}
    for any omitted optional parameters. This is useful when you need fine-grained
    control over configuration without using environment variables.

    @param uri Connection URI (default: ["bolt://127.0.0.1:7687"])
    @param user Neo4j username (default: ["neo4j"])
    @param password Neo4j password (default: ["testpass"])
    @param user_agent Driver identification string (default: ["neo4j_eio/0.1.0"])
    @param fetch_size Records per PULL request (default: [1000])
    @param use_tls Enable TLS encryption (default: [false])
    @param tls_ca Path to CA certificate (default: [None])
    @param log_level Logging verbosity (default: [Info])
    @param protocols Bolt versions to propose (default: [[5; 4; 3]])

    @return Configuration with specified values

    {2 Example}

    {[
      let cfg = Config.make
        ~uri:"bolt://prod.db:7687"
        ~user:"admin"
        ~password:"secret"
        ~fetch_size:500
        ~log_level:Config.Debug
        () in
      Session.with_session ~sw ~net cfg (fun session -> ...)
    ]}

    @since 0.1.0
*)
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
