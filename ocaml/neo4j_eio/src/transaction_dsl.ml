(** Transaction DSL implementation *)

(** Transaction result that can signal commit/rollback intent *)
type 'a tx_result =
  | TxValue of 'a
  | TxCommit of 'a
  | TxRollback of 'a
  | TxError of Error.t

(** The transaction monad works with Neo4j sessions over network streams.

    We use Eio.Net.stream_socket_ty which provides all the capabilities needed.
    This is fully type-safe - no Obj.magic needed.
*)
type 'a t = Tx of (([ `Generic | `Unix ] Eio.Net.stream_socket_ty Eio.Resource.t) Session.t -> 'a tx_result)

(** {1 Core Operations} *)

let return x = Tx (fun _session -> TxValue x)

let fail error = Tx (fun _session -> TxError error)

(** {1 Monadic Composition} *)

let bind (Tx m) f = Tx (fun session ->
  match m session with
  | TxError e -> TxError e
  | TxCommit x ->
      let (Tx g) = f x in
      (match g session with
       | TxValue y -> TxCommit y
       | other -> other)
  | TxRollback x ->
      let (Tx g) = f x in
      (match g session with
       | TxValue y -> TxRollback y
       | other -> other)
  | TxValue x ->
      let (Tx g) = f x in
      g session
)

let (let*) = bind

let map f (Tx m) = Tx (fun session ->
  match m session with
  | TxError e -> TxError e
  | TxCommit x -> TxCommit (f x)
  | TxRollback x -> TxRollback (f x)
  | TxValue x -> TxValue (f x)
)

let (let+) m f = map f m

let product (Tx m1) (Tx m2) = Tx (fun session ->
  match m1 session with
  | TxError e -> TxError e
  | TxCommit x ->
      (match m2 session with
       | TxValue y -> TxCommit (x, y)
       | TxCommit y -> TxCommit (x, y)
       | TxRollback y -> TxRollback (x, y)
       | TxError e -> TxError e)
  | TxRollback x ->
      (match m2 session with
       | TxValue y -> TxRollback (x, y)
       | TxCommit y -> TxCommit (x, y)
       | TxRollback y -> TxRollback (x, y)
       | TxError e -> TxError e)
  | TxValue x ->
      (match m2 session with
       | TxValue y -> TxValue (x, y)
       | TxCommit y -> TxCommit (x, y)
       | TxRollback y -> TxRollback (x, y)
       | TxError e -> TxError e)
)

let (and+) = product

(** {1 Query Execution} *)

let exec_cypher query = Tx (fun session ->
  match Cypher.run query session with
  | Ok v -> TxValue v
  | Error e -> TxError e
)

let exec_query_builder builder = Tx (fun session ->
  match Query_builder.execute builder session with
  | Ok v -> TxValue v
  | Error e -> TxError e
)

let exec_query_builder_unit builder = Tx (fun session ->
  match Query_builder.execute_unit builder session with
  | Ok v -> TxValue v
  | Error e -> TxError e
)

(** {1 Transaction Control} *)

let commit = Tx (fun _session -> TxCommit ())

let rollback = Tx (fun _session -> TxRollback ())

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
  | TxError e ->
      (* On error, rollback the transaction and run handler in a new transaction *)
      (match Session.rollback session with
       | Ok () ->
           (* Start a new transaction for the handler *)
           (match Session.begin_transaction session () with
            | Ok () ->
                let (Tx h) = handler e in
                h session
            | Error e2 -> TxError e2)
       | Error _ -> TxError e)
  | other -> other
)

let try_with (Tx action) ~on_error = Tx (fun session ->
  match action session with
  | TxError e ->
      (* On error, rollback the transaction and run on_error in a new transaction *)
      (match Session.rollback session with
       | Ok () ->
           (* Start a new transaction for on_error *)
           (match Session.begin_transaction session () with
            | Ok () ->
                let (Tx on_err) = on_error in
                on_err session
            | Error e2 -> TxError e2)
       | Error _ -> TxError e)
  | other -> other
)

(** {1 Execution} *)

let run (Tx tx) session =
  (* Start transaction *)
  match Session.begin_transaction session () with
  | Error e -> Error e
  | Ok () ->
      (* Run the transaction actions *)
      match tx session with
      | TxError e ->
          (* Action failed - rollback *)
          (match Session.rollback session with
           | Ok () -> Error e
           | Error _ -> Error e)
      | TxCommit result ->
          (* Explicit commit requested *)
          (match Session.commit session with
           | Ok () -> Ok result
           | Error e -> Error e)
      | TxRollback result ->
          (* Explicit rollback requested *)
          (match Session.rollback session with
           | Ok () -> Ok result
           | Error e -> Error e)
      | TxValue result ->
          (* No explicit commit/rollback - auto commit *)
          (match Session.commit session with
           | Ok () -> Ok result
           | Error e -> Error e)

let run_exn tx session =
  match run tx session with
  | Ok x -> x
  | Error e ->
      let msg = Format.asprintf "Transaction failed: %s" (Error.to_string e) in
      failwith msg

(** {1 Utility Functions} *)

let get_session = Tx (fun session -> TxValue session)

let lift_result = function
  | Ok x -> return x
  | Error e -> fail e
