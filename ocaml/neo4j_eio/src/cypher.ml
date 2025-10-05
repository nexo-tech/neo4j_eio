(** Fluent query builder API for Cypher queries *)

(* Internal representation combining statement/params with transformations *)
type _ query_spec =
  | Base : {
      statement : string;
      parameters : (string * Value.value) list;
      transform : Record.t list -> ('a, Error.t) result;
    } -> 'a query_spec
  | Transformed : 'b query_spec * (('b, Error.t) result -> ('a, Error.t) result) -> 'a query_spec
  | Bound : 'b query_spec * ('b -> 'a query_spec) -> 'a query_spec
  | Transactional : (([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> ('a, Error.t) result) -> 'a query_spec

type 'a t = 'a query_spec

(* Helper to execute a base query - works with any flow type that has Flow/R/W capabilities *)
let execute_query statement parameters session =
  let params = List.fold_left (fun acc (k, v) ->
    Value.StringMap.add k v acc
  ) Value.StringMap.empty parameters in
  Session.run_records session ~statement ~parameters:params ()

(* Query construction *)

let query statement =
  Base {
    statement;
    parameters = [];
    transform = (fun records -> Ok records);
  }

let query_unit statement =
  Base {
    statement;
    parameters = [];
    transform = (fun _records -> Ok ());
  }

let rec with_params : type a. (string * Value.value) list -> a t -> a t =
  fun params query ->
    match query with
    | Base b -> Base { b with parameters = params @ b.parameters }
    | Transformed (q, f) -> Transformed (with_params params q, f)
    | Bound (q, cont) -> Bound (with_params params q, cont)
    | Transactional _ as t -> t

let param name value = (name, value)

let (=:) = param

(* Result transformation *)

let extract extractor query =
  let transform_fn = function
    | Error e -> Error e
    | Ok records ->
        let rec extract_all acc = function
          | [] -> Ok (List.rev acc)
          | record :: rest ->
              match Extract.run extractor record with
              | Error decode_err ->
                  let msg = Format.asprintf "Extraction failed: %a" Record.pp_decode_error decode_err in
                  Error (Error.ClientError { code = "Client.ExtractionError"; message = msg })
              | Ok value ->
                  extract_all (value :: acc) rest
        in
        extract_all [] records
  in
  Transformed (query, transform_fn)

let map f query =
  let transform_fn = function
    | Ok x -> Ok (f x)
    | Error e -> Error e
  in
  Transformed (query, transform_fn)

let bind query cont =
  Bound (query, cont)

(* Result combinators *)

let single query =
  let transform_fn = function
    | Error e -> Error e
    | Ok [] -> Ok None
    | Ok [x] -> Ok (Some x)
    | Ok _ -> Error (Error.ClientError {
        code = "Client.TooManyResults";
        message = "Expected zero or one result, got multiple"
      })
  in
  Transformed (query, transform_fn)

let expect_one query =
  let transform_fn = function
    | Error e -> Error e
    | Ok [] -> Error (Error.ClientError {
        code = "Client.NoResults";
        message = "Expected exactly one result, got zero"
      })
    | Ok [x] -> Ok x
    | Ok results -> Error (Error.ClientError {
        code = "Client.TooManyResults";
        message = Printf.sprintf "Expected exactly one result, got %d" (List.length results)
      })
  in
  Transformed (query, transform_fn)

let first query =
  let transform_fn = function
    | Error e -> Error e
    | Ok [] -> Ok None
    | Ok (x :: _) -> Ok (Some x)
  in
  Transformed (query, transform_fn)

let head = first

let take n query =
  let transform_fn = function
    | Error e -> Error e
    | Ok results ->
        let rec take_n acc count = function
          | [] -> Ok (List.rev acc)
          | x :: xs when count > 0 -> take_n (x :: acc) (count - 1) xs
          | _ -> Ok (List.rev acc)
        in
        take_n [] n results
  in
  Transformed (query, transform_fn)

let filter pred query =
  let transform_fn = function
    | Error e -> Error e
    | Ok results -> Ok (List.filter pred results)
  in
  Transformed (query, transform_fn)

(* Execution *)

let rec run : type a. a t -> ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> (a, Error.t) result =
  fun query session ->
    match query with
    | Base { statement; parameters; transform } ->
        (match execute_query statement parameters session with
         | Error e -> Error e
         | Ok records -> transform records)
    | Transformed (q, f) ->
        let result = run q session in
        f result
    | Bound (q, cont) ->
        (match run q session with
         | Error e -> Error e
         | Ok x -> run (cont x) session)
    | Transactional exec ->
        exec (Obj.magic session : ([> `Flow | `R | `W ] Eio.Resource.t) Session.t)

let run_exn query session =
  match run query session with
  | Ok x -> x
  | Error e ->
      let msg = Format.asprintf "Cypher.run_exn: %s" (Error.to_string e) in
      failwith msg

(* Transaction support *)

let in_transaction f =
  Transactional (fun session ->
    Session.transact session (fun tx -> f tx)
  )

(* Let-syntax *)

let (let*) = bind

let (let+) q f = map f q

let (and+) q1 q2 =
  bind q1 (fun x ->
    map (fun y -> (x, y)) q2)

(* Infix operators *)

let (>>=) = bind

let (>>|) q f = map f q

let (|>) q f = f q
