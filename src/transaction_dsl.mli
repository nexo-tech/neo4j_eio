(** Transaction DSL for composable transaction workflows.

    This module provides a monadic DSL for building transaction workflows
    that can be composed and executed atomically.
*)

(** The transaction monad type. A value of type ['a t] represents a
    transaction computation that, when run, will produce a value of
    type ['a] or fail with an error. *)
type 'a t

(** {1 Core Operations} *)

(** [return x] creates a transaction that immediately succeeds with value [x]. *)
val return : 'a -> 'a t

(** [fail error] creates a transaction that immediately fails with the given error. *)
val fail : Error.t -> 'a t

(** {1 Monadic Composition} *)

(** [bind m f] sequences two transactions. The result of [m] is passed to [f]. *)
val bind : 'a t -> ('a -> 'b t) -> 'b t

(** [let*] is the monadic bind operator for let-syntax. *)
val (let*) : 'a t -> ('a -> 'b t) -> 'b t

(** [let+] is the applicative map operator. *)
val (let+) : 'a t -> ('a -> 'b) -> 'b t

(** [and+] is the applicative product operator. *)
val (and+) : 'a t -> 'b t -> ('a * 'b) t

(** {1 Query Execution} *)

(** [exec_cypher query] executes a Cypher query within the transaction context.
    This is the primary way to run queries in a transaction. *)
val exec_cypher : 'a Cypher.t -> 'a t

(** [exec_query_builder builder] executes a query builder within the transaction. *)
val exec_query_builder : Query_builder.t -> Record.t list t

(** [exec_query_builder_unit builder] executes a query builder, discarding results. *)
val exec_query_builder_unit : Query_builder.t -> unit t

(** {1 Transaction Control} *)

(** [commit] commits the current transaction. This should be the final
    operation in a transaction workflow. *)
val commit : unit t

(** [rollback] rolls back the current transaction. Use this to explicitly
    abort a transaction. *)
val rollback : unit t

(** {1 Control Flow} *)

(** [when_ condition action] executes [action] only if [condition] is true. *)
val when_ : bool -> unit t -> unit t

(** [unless condition action] executes [action] only if [condition] is false. *)
val unless : bool -> unit t -> unit t

(** [sequence actions] runs a list of actions in sequence, collecting results. *)
val sequence : 'a t list -> 'a list t

(** [sequence_ actions] runs a list of actions in sequence, discarding results. *)
val sequence_ : unit t list -> unit t

(** [iter f list] applies [f] to each element of [list] in sequence. *)
val iter : ('a -> unit t) -> 'a list -> unit t

(** [map f list] maps [f] over [list] in sequence, collecting results. *)
val map : ('a -> 'b t) -> 'a list -> 'b list t

(** {1 Error Handling} *)

(** [catch action handler] runs [action], and if it fails, runs [handler]. *)
val catch : 'a t -> (Error.t -> 'a t) -> 'a t

(** [try_with action ~on_error] runs [action], falling back to [on_error] on failure. *)
val try_with : 'a t -> on_error:'a t -> 'a t

(** {1 Execution} *)

(** [run transaction session] executes a transaction workflow.
    This automatically handles:
    - BEGIN TRANSACTION
    - Running all transaction actions
    - COMMIT on success
    - ROLLBACK on failure

    Returns the result of the transaction or an error.
*)
val run : 'a t -> ([ `Generic | `Unix ] Eio.Net.stream_socket_ty Eio.Resource.t) Session.t -> ('a, Error.t) result

(** [run_exn transaction session] executes a transaction, raising an exception on failure. *)
val run_exn : 'a t -> ([ `Generic | `Unix ] Eio.Net.stream_socket_ty Eio.Resource.t) Session.t -> 'a

(** {1 Utility Functions} *)

(** [get_session] provides access to the session within a transaction context.
    This is an escape hatch for advanced use cases. *)
val get_session : ([ `Generic | `Unix ] Eio.Net.stream_socket_ty Eio.Resource.t) Session.t t

(** [lift_result result] lifts a Result into the transaction monad. *)
val lift_result : ('a, Error.t) result -> 'a t
