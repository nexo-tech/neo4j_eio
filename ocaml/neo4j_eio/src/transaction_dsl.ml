(** Transaction DSL implementation *)

(** The transaction monad works with Neo4j sessions over network streams.

    We use Eio.Net.stream_socket_ty which provides all the capabilities needed.
    This is fully type-safe - no Obj.magic needed.
*)
type 'a t = Tx of (([ `Generic | `Unix ] Eio.Net.stream_socket_ty Eio.Resource.t) Session.t -> ('a, Error.t) result)

(** {1 Core Operations} *)

let return x = Tx (fun _session -> Ok x)

let fail error = Tx (fun _session -> Error error)

(** {1 Monadic Composition} *)

let bind (Tx m) f = Tx (fun session ->
  match m session with
  | Error e -> Error e
  | Ok x ->
      let (Tx g) = f x in
      g session
)

let (let*) = bind

let map f (Tx m) = Tx (fun session ->
  match m session with
  | Error e -> Error e
  | Ok x -> Ok (f x)
)

let (let+) m f = map f m

let product (Tx m1) (Tx m2) = Tx (fun session ->
  match m1 session with
  | Error e -> Error e
  | Ok x ->
      match m2 session with
      | Error e -> Error e
      | Ok y -> Ok (x, y)
)

let (and+) = product

(** {1 Query Execution} *)

let exec_cypher query = Tx (fun session ->
  Cypher.run query session
)

let exec_query_builder builder = Tx (fun session ->
  Query_builder.execute builder session
)

let exec_query_builder_unit builder = Tx (fun session ->
  Query_builder.execute_unit builder session
)

(** {1 Transaction Control} *)

let commit = Tx (fun session ->
  Session.commit session
)

let rollback = Tx (fun session ->
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

let catch (Tx action) handler = Tx (fun session ->
  match action session with
  | Ok x -> Ok x
  | Error e ->
      let (Tx h) = handler e in
      h session
)

let try_with (Tx action) ~on_error = Tx (fun session ->
  match action session with
  | Ok x -> Ok x
  | Error _ ->
      let (Tx on_err) = on_error in
      on_err session
)

(** {1 Execution} *)

let run (Tx tx) session =
  (* Start transaction *)
  match Session.begin_transaction session () with
  | Error e -> Error e
  | Ok () ->
      (* Run the transaction actions *)
      match tx session with
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

let get_session = Tx (fun session -> Ok session)

let lift_result = function
  | Ok x -> return x
  | Error e -> fail e
