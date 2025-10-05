(** Low-level Bolt connection helpers.

    These functions implement the Bolt handshake, authentication and
    message framing (chunking/dechunking). Most users should prefer the
    {!Session} and higher-level APIs, but these are provided for tests
    and advanced scenarios.
*)

(** Perform a Bolt handshake and return the negotiated version. *)
val handshake :
  sw:Eio.Switch.t ->
  net:_ Eio.Net.t ->
  Config.t -> (Protocol.version, Error.t) result

(** Authenticate using HELLO (v3/v4) or HELLO+LOGON semantics (v5 family).
    Returns both the negotiated version and the underlying flow on success. *)
val authenticate :
  sw:Eio.Switch.t ->
  net:[> ([> `Generic ] as 'a) Eio.Net.ty ] Eio.Resource.t ->
  Config.t ->
  (Protocol.version * 'a Eio.Net.stream_socket_ty Eio.Resource.t, Error.t) result

(** Send a chunked Bolt message over the given flow. *)
val send_message : _ Eio.Flow.sink -> string -> unit

(** Receive and dechunks a single Bolt message from the flow and decode as a PackStream value. *)
val recv_response : _ Eio.Flow.source -> (Value.value, string) result

(** Send a GOODBYE and close the flow. *)
val goodbye : [> `Close | `Flow | `R | `Shutdown | `W ] Eio.Resource.t -> unit

(** Send a GOODBYE without closing. *)
val send_goodbye : _ Eio.Flow.two_way -> unit

(** Managed connection helper that performs handshake + auth and ensures
    GOODBYE/close on exit. *)
val with_connection :
  sw:Eio.Switch.t ->
  net:[> ([> `Generic ] as 'a) Eio.Net.ty ] Eio.Resource.t ->
  Config.t ->
  ('a Eio.Net.stream_socket_ty Eio.Resource.t -> Protocol.version -> ('b, Error.t) result) ->
  ('b, Error.t) result

(** Convenience function to run a single query and collect all results. *)
val run_query :
  _ Eio.Flow.two_way ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (Value.value list, Error.t) result
