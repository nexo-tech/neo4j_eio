(** {1 Session Management}

    Sessions provide the primary interface for executing queries and managing
    transactions against a Neo4j database. Each session represents a single
    authenticated Bolt connection with serialized request handling.

    {2 Usage Pattern}

    The recommended pattern is to use {!with_session} for automatic resource
    management:

    {[
      Eio_main.run @@ fun env ->
      let cfg = Config.of_env () in
      Eio.Switch.run @@ fun sw ->
        Session.with_session ~sw ~net:env#net cfg (fun session ->
          (* Use session here *)
          Session.run_records session ~statement:"MATCH (n) RETURN n" ()
        )
    ]}

    {2 Concurrency}

    Sessions serialize all operations using a mutex - only one request can be
    in flight at a time. For concurrent queries, create multiple sessions:

    {[
      Eio.Fiber.both
        (fun () -> Session.with_session ~sw ~net cfg query1)
        (fun () -> Session.with_session ~sw ~net cfg query2)
    ]}

    {2 Error Recovery}

    Sessions automatically handle FAILURE responses from the server. Outside of
    transactions, the driver issues RESET to clear failed state and allow
    subsequent queries to proceed.
*)

(** Abstract session type.

    The type parameter ['a] represents the underlying network flow resource.
    Most operations require flows with [`Flow | `R | `W] capabilities for
    bidirectional communication.

    Sessions are not thread-safe but are fiber-safe within Eio - they use a
    mutex to serialize concurrent operations from multiple fibers.
*)
type 'a t

(** Reset the session to clear failed state.

    Sends a RESET message to the server, clearing any error state and aborting
    any active transaction. This is automatically called after FAILURE responses
    outside of transactions, but can be manually invoked if needed.

    @param session The session to reset
    @return [Ok ()] if reset succeeds
    @return [Error e] if the reset fails or session is closed
    @since 0.1.0
*)
val reset : ([> `Flow | `R | `W ] Eio.Resource.t) t -> (unit, Error.t) result

(** Create a session, run a function, and ensure cleanup.

    This is the recommended way to use sessions. It handles the complete lifecycle:
    1. Establishes TCP connection to the server
    2. Performs Bolt handshake and authentication
    3. Runs your function with the authenticated session
    4. Sends GOODBYE and closes the connection on exit

    The connection is automatically closed when the function returns or if an
    exception is raised.

    @param sw Eio switch governing the session lifetime
    @param net Eio network capability for creating connections
    @param config Connection configuration (URI, credentials, etc.)
    @param f Function to run with the session. Should return [(result, Error.t) result]
    @return The result of [f] if successful, or an error from connection/auth

    {2 Example}

    {[
      Session.with_session ~sw ~net cfg (fun session ->
        match Session.run_records session ~statement:"RETURN 1 AS n" () with
        | Ok [record] ->
            Printf.printf "Got result\\n";
            Ok ()
        | Ok _ -> Error (Error.Protocol "Unexpected row count")
        | Error e -> Error e
      )
    ]}

    @since 0.1.0
*)
val with_session :
  sw:Eio.Switch.t ->
  net:[> ([> `Generic ] as 'a) Eio.Net.ty ] Eio.Resource.t ->
  Config.t ->
  ('a Eio.Net.stream_socket_ty Eio.Resource.t t -> ('b, Error.t) result) ->
  ('b, Error.t) result

(** Streaming API (raw PackStream values). *)
type stream = {
  fetch_next : unit -> (Value.value list, Error.t) result;
  mutable exhausted : bool;
}

(** Execute a query and create a streaming cursor over value lists.
    Use [~fetch_size] to control record batch size (default 1000). *)
val run_stream :
  ([> `Flow | `R | `W ] Eio.Resource.t) t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  ?fetch_size:int64 ->
  unit ->
  (stream, Error.t) result

(** Consume a complete [stream] into a single list of values. *)
val stream_to_list : stream -> (Value.value list, Error.t) result

(** Streaming API (decoded records). *)
type record_stream = {
  fetch_next_records : unit -> (Record.t list, Error.t) result;
  mutable exhausted : bool;
}

(** Execute a query and create a streaming cursor over records. *)
val run_stream_records :
  ([> `Flow | `R | `W ] Eio.Resource.t) t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  ?fetch_size:int64 ->
  unit ->
  (record_stream, Error.t) result

(** Consume a complete [record_stream] into a single list of records. *)
val record_stream_to_list : record_stream -> (Record.t list, Error.t) result

(** Strict materialization: execute a query and return all value rows.
    If [~fetch_size] is provided, the driver will PULL in chunks until complete. *)
val run :
  ([> `Flow | `R | `W ] Eio.Resource.t) t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  ?fetch_size:int64 ->
  unit ->
  (Value.value list, Error.t) result

(** Strict materialization: execute a query and return all records (with field names). *)
val run_records :
  ([> `Flow | `R | `W ] Eio.Resource.t) t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  ?fetch_size:int64 ->
  unit ->
  (Record.t list, Error.t) result

(** Begin a transaction. Optional [metadata] is attached to the BEGIN extra. *)
val begin_transaction : ([> `Flow | `R | `W ] Eio.Resource.t) t -> ?metadata:Value.value Value.StringMap.t -> unit -> (unit, Error.t) result

(** Commit the current transaction. *)
val commit : ([> `Flow | `R | `W ] Eio.Resource.t) t -> (unit, Error.t) result

(** Roll back the current transaction. *)
val rollback : ([> `Flow | `R | `W ] Eio.Resource.t) t -> (unit, Error.t) result

(** Run the given function inside a transaction, committing on success
    and rolling back on failure. *)
val transact :
  ([> `Flow | `R | `W ] as 'a) Eio.Resource.t t ->
  ('a Eio.Resource.t t -> ('b, Error.t) result) ->
  ('b, Error.t) result

(** Close the session: send GOODBYE and close the underlying flow. *)
val close : ([> `Close | `Flow | `R | `Shutdown | `W ] Eio.Resource.t) t -> unit
