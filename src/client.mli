(** {1 Client Connection Utilities}

    This module provides high-level utilities for establishing connections to Neo4j
    databases using the Bolt protocol. Most users should prefer the {!Session} module
    for complete session management.
*)

(** Establish a TCP connection and perform Bolt handshake.

    This function creates a TCP connection to the Neo4j server specified in the
    configuration and performs the Bolt protocol handshake to negotiate the protocol
    version. This is a lower-level operation; most applications should use
    {!Session.with_session} instead.

    {2 Handshake Process}

    The function:
    - Parses the host and port from {!Config.uri}
    - Opens a TCP connection using the provided [net] capability
    - Sends a Bolt handshake proposing versions [5; 4; 3; 2]
    - Receives and validates the server's version selection

    {2 Parameters}

    @param sw Eio switch that governs the connection lifetime. The connection
              will be automatically closed when this switch finishes.
    @param net Eio network capability used to open the TCP flow. Typically
               obtained from [env#net] in an Eio main function.
    @param Config.t Connection settings including URI and protocol preferences.
                    Only the [uri] and [protocols] fields are used; authentication
                    is not performed by this function.

    @return [Ok version] if handshake succeeds with the negotiated protocol version
    @return [Error e] if connection fails, handshake fails, or version negotiation fails

    {2 Example}

    {[
      Eio_main.run @@ fun env ->
      let cfg = Config.of_env () in
      Eio.Switch.run @@ fun sw ->
        match Client.connect_and_handshake ~sw ~net:env#net cfg with
        | Ok version ->
            Printf.printf "Connected using Bolt v%d\\n" version
        | Error e ->
            Printf.eprintf "Handshake failed: %s\\n" (Error.to_string e)
    ]}

    @see <https://neo4j.com/docs/bolt/current/> Bolt Protocol Specification
    @since 0.1.0
*)
val connect_and_handshake :
  sw:Eio.Switch.t ->
  net:_ Eio.Net.t ->
  Config.t ->
  (Protocol.version, Error.t) result
