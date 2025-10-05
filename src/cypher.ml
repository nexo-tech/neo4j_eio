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

(* Pipeline-friendly execution - curried session parameter *)

let execute session query = run query session

let execute_exn session query = run_exn query session

(* Pipeline operator for execution *)
let (|>>) query session = run query session

(* Convenient alias for pipeline execution *)
let run_in session query = run query session

let run_in_exn session query = run_exn query session

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

(* Parameter construction helpers *)

let props params = params

let text value = Value.Text value
let int value = Value.Int value
let float value = Value.Float value
let bool value = Value.Bool value
let null = Value.Null

let list values = Value.List values
let value_map values =
  let m = List.fold_left (fun acc (k, v) ->
    Value.StringMap.add k v acc
  ) Value.StringMap.empty values in
  Value.Map m

(* Query sequencing *)

let sequence queries =
  let rec seq_all acc = function
    | [] -> map (fun xs -> List.rev xs) (Base {
        statement = "";
        parameters = [];
        transform = (fun _ -> Ok [])
      })
    | q :: qs ->
        bind q (fun x ->
          bind (seq_all (x :: acc) qs) (fun xs ->
            Base {
              statement = "";
              parameters = [];
              transform = (fun _ -> Ok xs)
            }
          )
        )
  in
  seq_all [] queries

let sequence_unit queries =
  let rec seq_all = function
    | [] -> query_unit ""
    | q :: qs ->
        bind q (fun _ -> seq_all qs)
  in
  seq_all queries

(* Collection operations on query results *)

let concat_map f query =
  map (fun xs ->
    List.concat_map f xs
  ) query

let fold_left f init query =
  map (fun xs ->
    List.fold_left f init xs
  ) query

let fold_right f query init =
  map (fun xs ->
    List.fold_right f xs init
  ) query

let for_each f query =
  map (fun xs ->
    List.iter f xs;
    xs
  ) query

let partition pred query =
  map (fun xs ->
    List.partition pred xs
  ) query

let group_by key_fn query =
  map (fun xs ->
    let tbl = Hashtbl.create 16 in
    List.iter (fun x ->
      let k = key_fn x in
      let existing = try Hashtbl.find tbl k with Not_found -> [] in
      Hashtbl.replace tbl k (x :: existing)
    ) xs;
    Hashtbl.fold (fun k v acc -> (k, List.rev v) :: acc) tbl []
  ) query

let distinct query =
  map (fun xs ->
    let tbl = Hashtbl.create 16 in
    List.filter (fun x ->
      if Hashtbl.mem tbl x then false
      else (Hashtbl.add tbl x (); true)
    ) xs
  ) query

(* Error recovery *)

let or_else query default =
  let transform_fn = function
    | Ok x -> Ok x
    | Error _ -> Ok default
  in
  Transformed (query, transform_fn)

let catch handler query =
  let transform_fn = function
    | Ok x -> Ok x
    | Error e -> handler e
  in
  Transformed (query, transform_fn)

let recover f query =
  let transform_fn = function
    | Ok x -> Ok x
    | Error e -> f e
  in
  Transformed (query, transform_fn)

(* Conditional execution *)

let when_ok pred f query =
  bind query (fun x ->
    if pred x then f x
    else Base {
      statement = "";
      parameters = [];
      transform = (fun _ -> Ok x)
    }
  )

let unless_ok pred f query =
  when_ok (fun x -> not (pred x)) f query

(* Query assertion helpers *)

let assert_non_empty query =
  let transform_fn = function
    | Error e -> Error e
    | Ok [] -> Error (Error.ClientError {
        code = "Client.EmptyResult";
        message = "Expected non-empty result"
      })
    | Ok xs -> Ok xs
  in
  Transformed (query, transform_fn)

let assert_count n query =
  let transform_fn = function
    | Error e -> Error e
    | Ok xs when List.length xs = n -> Ok xs
    | Ok xs -> Error (Error.ClientError {
        code = "Client.UnexpectedCount";
        message = Printf.sprintf "Expected %d results, got %d" n (List.length xs)
      })
  in
  Transformed (query, transform_fn)

let assert_at_least n query =
  let transform_fn = function
    | Error e -> Error e
    | Ok xs when List.length xs >= n -> Ok xs
    | Ok xs -> Error (Error.ClientError {
        code = "Client.InsufficientResults";
        message = Printf.sprintf "Expected at least %d results, got %d" n (List.length xs)
      })
  in
  Transformed (query, transform_fn)

let assert_at_most n query =
  let transform_fn = function
    | Error e -> Error e
    | Ok xs when List.length xs <= n -> Ok xs
    | Ok xs -> Error (Error.ClientError {
        code = "Client.TooManyResults";
        message = Printf.sprintf "Expected at most %d results, got %d" n (List.length xs)
      })
  in
  Transformed (query, transform_fn)

(* Execution with retries - NOTE: disabled as it requires access to Eio clock which isn't available in this API level *)
(* Users should implement retry logic at the application level where they have access to Eio.Time *)

(* Timing utilities *)

let with_timing query =
  bind query (fun result ->
    Base {
      statement = "";
      parameters = [];
      transform = (fun _ -> Ok (result, 0.0))
    }
  )

(* Tap for side effects *)

let tap f query =
  map (fun x ->
    f x;
    x
  ) query

(* Zip operations *)

let zip q1 q2 =
  bind q1 (fun xs ->
    map (fun ys -> List.combine xs ys) q2
  )

let zip_with f q1 q2 =
  bind q1 (fun xs ->
    map (fun ys -> List.map2 f xs ys) q2
  )

(* Optional extraction helper that returns None on error *)

let try_extract extractor query =
  let transform_fn = function
    | Error _ -> Ok []
    | Ok records ->
        List.filter_map (fun record ->
          match Extract.run extractor record with
          | Ok value -> Some value
          | Error _ -> None
        ) records
        |> Result.ok
  in
  Transformed (query, transform_fn)

(* Count helper *)

let count query =
  map List.length query

(* Exists helper *)

let exists pred query =
  map (fun xs -> List.exists pred xs) query

(* All helper *)

let for_all pred query =
  map (fun xs -> List.for_all pred xs) query

(* Find helpers *)

let find pred query =
  map (fun xs -> List.find_opt pred xs) query

let find_map f query =
  map (fun xs -> List.find_map f xs) query

(* Advanced transformation pipeline functions *)

(* Flatten nested query results *)
let flatten query =
  map List.flatten query

(* Map and flatten in one operation *)
let flat_map f query =
  map (List.concat_map f) query

(* Reduce/aggregate operations *)
let reduce f init query =
  map (List.fold_left f init) query

let sum_int query =
  map (List.fold_left Int64.add 0L) query

let sum_float query =
  map (List.fold_left (+.) 0.0) query

let average_int query =
  map (fun xs ->
    match xs with
    | [] -> 0L
    | _ ->
        let sum = List.fold_left Int64.add 0L xs in
        Int64.div sum (Int64.of_int (List.length xs))
  ) query

let average_float query =
  map (fun xs ->
    match xs with
    | [] -> 0.0
    | _ ->
        let sum = List.fold_left (+.) 0.0 xs in
        sum /. float_of_int (List.length xs)
  ) query

let min_by cmp query =
  map (function
    | [] -> None
    | x :: xs -> Some (List.fold_left (fun acc y -> if cmp y acc < 0 then y else acc) x xs)
  ) query

let max_by cmp query =
  map (function
    | [] -> None
    | x :: xs -> Some (List.fold_left (fun acc y -> if cmp y acc > 0 then y else acc) x xs)
  ) query

(* Sorting operations *)
let sort cmp query =
  map (List.sort cmp) query

let sort_by f query =
  map (List.sort (fun a b -> compare (f a) (f b))) query

let reverse query =
  map List.rev query

(* Chunking and batching *)
let chunk n query =
  let rec chunk_list acc current count = function
    | [] -> if current = [] then List.rev acc else List.rev (List.rev current :: acc)
    | x :: xs ->
        if count >= n then
          chunk_list (List.rev current :: acc) [x] 1 xs
        else
          chunk_list acc (x :: current) (count + 1) xs
  in
  map (chunk_list [] [] 0) query

let batch n query =
  chunk n query

(* Sliding window *)
let sliding_window n query =
  let rec windows acc xs =
    if List.length xs < n then List.rev acc
    else
      let window = List.filteri (fun i _ -> i < n) xs in
      let rest = List.tl xs in
      windows (window :: acc) rest
  in
  map (windows []) query

(* Deduplication with custom equality *)
let deduplicate_by eq query =
  map (fun xs ->
    let rec dedup acc = function
      | [] -> List.rev acc
      | x :: rest ->
          if List.exists (eq x) acc then dedup acc rest
          else dedup (x :: acc) rest
    in
    dedup [] xs
  ) query

(* Split at predicate *)
let span pred query =
  map (fun xs ->
    let rec span_list acc = function
      | [] -> (List.rev acc, [])
      | x :: rest as l ->
          if pred x then span_list (x :: acc) rest
          else (List.rev acc, l)
    in
    span_list [] xs
  ) query

let break_at pred query =
  span (fun x -> not (pred x)) query

(* Take/drop while *)
let take_while pred query =
  map (fun xs ->
    let rec take acc = function
      | [] -> List.rev acc
      | x :: rest ->
          if pred x then take (x :: acc) rest
          else List.rev acc
    in
    take [] xs
  ) query

let drop_while pred query =
  map (fun xs ->
    let rec drop = function
      | [] -> []
      | x :: rest as l ->
          if pred x then drop rest
          else l
    in
    drop xs
  ) query

(* Nth element *)
let nth n query =
  map (fun xs ->
    try Some (List.nth xs n)
    with _ -> None
  ) query

(* Index operations *)
let index_of eq x query =
  map (fun xs ->
    let rec find_index i = function
      | [] -> None
      | y :: rest ->
          if eq x y then Some i
          else find_index (i + 1) rest
    in
    find_index 0 xs
  ) query

let indexed query =
  map (List.mapi (fun i x -> (i, x))) query

(* Interleave two queries *)
let interleave q1 q2 =
  bind q1 (fun xs ->
    bind q2 (fun ys ->
      let rec interleave_lists acc xs ys =
        match xs, ys with
        | [], [] -> List.rev acc
        | x :: xs', [] -> List.rev_append acc (x :: xs')
        | [], y :: ys' -> List.rev_append acc (y :: ys')
        | x :: xs', y :: ys' -> interleave_lists (y :: x :: acc) xs' ys'
      in
      Base {
        statement = "";
        parameters = [];
        transform = (fun _ -> Ok (interleave_lists [] xs ys))
      }
    )
  )

(* Cons and snoc operations *)
let cons x query =
  map (fun xs -> x :: xs) query

let snoc query x =
  map (fun xs -> xs @ [x]) query

(* Replicate element n times *)
let replicate n query =
  map (fun xs ->
    List.concat (List.map (fun x -> List.init n (fun _ -> x)) xs)
  ) query

(* Unzip pairs *)
let unzip query =
  map (fun pairs ->
    let rec unzip_list acc1 acc2 = function
      | [] -> (List.rev acc1, List.rev acc2)
      | (a, b) :: rest -> unzip_list (a :: acc1) (b :: acc2) rest
    in
    unzip_list [] [] pairs
  ) query

(* Transpose list of lists *)
let transpose query =
  map (fun matrix ->
    if matrix = [] then []
    else
      let rec transpose_lists acc = function
        | [] :: _ -> List.rev acc
        | rows ->
            let heads = List.map List.hd rows in
            let tails = List.map List.tl rows in
            transpose_lists (heads :: acc) tails
      in
      transpose_lists [] matrix
  ) query
