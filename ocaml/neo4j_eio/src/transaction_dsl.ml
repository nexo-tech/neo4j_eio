(** Transaction DSL implementation *)

(** The transaction monad represents a computation that runs within a transaction context.
    We use Obj.magic internally to work around the polymorphic flow type in Session.t.
    This is safe because we never expose the session outside of the transaction. *)
type 'a t = Tx of ((Obj.t -> ('a, Error.t) result))

(* Helper to create a transaction from a function *)
let make_tx f = Tx (fun session -> f (Obj.magic session))

(* Helper to run a transaction action *)
let run_action (Tx f) session = f (Obj.obj session)

(** {1 Core Operations} *)

let return x = make_tx (fun _session -> Ok x)

let fail error = make_tx (fun _session -> Error error)

(** {1 Monadic Composition} *)

let bind m f = make_tx (fun session ->
  match run_action m session with
  | Error e -> Error e
  | Ok x -> run_action (f x) session
)

let (let*) = bind

let map f m = make_tx (fun session ->
  match run_action m session with
  | Error e -> Error e
  | Ok x -> Ok (f x)
)

let (let+) m f = map f m

let product m1 m2 = make_tx (fun session ->
  match run_action m1 session with
  | Error e -> Error e
  | Ok x ->
      match run_action m2 session with
      | Error e -> Error e
      | Ok y -> Ok (x, y)
)

let (and+) = product

(** {1 Query Execution} *)

let exec_cypher query = make_tx (fun session ->
  Cypher.run query session
)

let exec_query_builder builder = make_tx (fun session ->
  Query_builder.execute builder session
)

let exec_query_builder_unit builder = make_tx (fun session ->
  Query_builder.execute_unit builder session
)

(** {1 Transaction Control} *)

let commit = make_tx (fun session ->
  Session.commit session
)

let rollback = make_tx (fun session ->
  Session.rollback session
)

(** {1 Control Flow} *)

let when_ condition action =
  if condition then action else return ()

let unless condition action =
  if condition then return () else action

let rec sequence = function
  | [] -> return []
  | action :: rest ->
      let* x = action in
      let* xs = sequence rest in
      return (x :: xs)

let sequence_ actions =
  let* _ = sequence actions in
  return ()

let rec iter f = function
  | [] -> return ()
  | x :: xs ->
      let* () = f x in
      iter f xs

let rec map f = function
  | [] -> return []
  | x :: xs ->
      let* y = f x in
      let* ys = map f xs in
      return (y :: ys)

(** {1 Error Handling} *)

let catch action handler = make_tx (fun session ->
  match run_action action session with
  | Ok x -> Ok x
  | Error e -> run_action (handler e) session
)

let try_with action ~on_error = make_tx (fun session ->
  match run_action action session with
  | Ok x -> Ok x
  | Error _ -> run_action on_error session
)

(** {1 Execution} *)

let run tx session =
  (* Start transaction *)
  match Session.begin_transaction session () with
  | Error e -> Error e
  | Ok () ->
      (* Run the transaction actions *)
      match run_action tx (Obj.repr session) with
      | Error e ->
          (* Action failed - rollback *)
          (match Session.rollback session with
           | Ok () -> Error e
           | Error _ -> Error e)
      | Ok result ->
          (* Action succeeded - commit *)
          match Session.commit session with
          | Ok () -> Ok result
          | Error e -> Error e

let run_exn tx session =
  match run tx session with
  | Ok x -> x
  | Error e ->
      let msg = Format.asprintf "Transaction failed: %s" (Error.to_string e) in
      failwith msg

(** {1 Utility Functions} *)

let get_session = make_tx (fun session -> Ok session)

let lift_result = function
  | Ok x -> return x
  | Error e -> fail e
