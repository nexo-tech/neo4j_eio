(** Monadic record field extraction with applicative composition *)

(* Core type: extractor is a function from Record to Result *)
type 'a t = Record.t -> ('a, Record.decode_error) result

(* Monadic operations *)

let return x = fun _record -> Ok x

let fail err = fun _record -> Error err

let bind e f = fun record ->
  match e record with
  | Ok x -> f x record
  | Error err -> Error err

let map_extract f e = fun record ->
  match e record with
  | Ok x -> Ok (f x)
  | Error err -> Error err

(* Let-syntax bindings *)

let (let*) = bind

let (let+) e f = map_extract f e

let (and+) e1 e2 = fun record ->
  match e1 record, e2 record with
  | Ok x, Ok y -> Ok (x, y)
  | Error e, _ -> Error e
  | _, Error e -> Error e

(* Field extractors *)

let field key decoder = fun record -> decoder record key

let text key = field key Record.at_text
let int key = field key Record.at_int
let int_as_int key = field key Record.at_int_as_int
let bool key = field key Record.at_bool
let float key = field key Record.at_float
let bytes key = field key Record.at_bytes
let node key = field key Record.at_node
let relationship key = field key Record.at_relationship
let unbound_relationship key = field key Record.at_unbound_relationship
let path key = field key Record.at_path
let point2d key = field key Record.at_point2d
let point3d key = field key Record.at_point3d
let duration key = field key Record.at_duration
let date key = field key Record.at_date
let local_time key = field key Record.at_local_time
let time key = field key Record.at_time
let local_datetime key = field key Record.at_local_datetime
let datetime_zone_id key = field key Record.at_datetime_zone_id
let datetime_offset key = field key Record.at_datetime_offset
let value key = field key Record.at_value

let list key decoder = fun record -> Record.at_list decoder record key
let map_field key = field key Record.at_map

(* Optional extractors *)

let optional e = fun record ->
  match e record with
  | Ok x -> Ok (Some x)
  | Error (Record.KeyNotFound _) -> Ok None
  | Error err -> Error err

let default v e = fun record ->
  match e record with
  | Ok x -> Ok x
  | Error _ -> Ok v

let maybe key decoder = fun record -> decoder record key

let maybe_text key = maybe key Record.maybe_at_text
let maybe_int key = maybe key Record.maybe_at_int
let maybe_bool key = maybe key Record.maybe_at_bool
let maybe_float key = maybe key Record.maybe_at_float
let maybe_node key = maybe key Record.maybe_at_node
let maybe_relationship key = maybe key Record.maybe_at_relationship
let maybe_path key = maybe key Record.maybe_at_path

(* Combinators *)

let both = (and+)

let sequence es = fun record ->
  let rec go acc = function
    | [] -> Ok (List.rev acc)
    | e :: es ->
        match e record with
        | Ok x -> go (x :: acc) es
        | Error err -> Error err
  in
  go [] es

let all f xs = fun record ->
  let rec go acc = function
    | [] -> Ok (List.rev acc)
    | x :: xs ->
        match f x record with
        | Ok y -> go (y :: acc) xs
        | Error err -> Error err
  in
  go [] xs

(* Execution *)

let run e record = e record

let run_exn e record =
  match e record with
  | Ok x -> x
  | Error err ->
      let msg = Format.asprintf "Extract.run_exn: %a" Record.pp_decode_error err in
      failwith msg

(* Infix operators *)

let (>>=) = bind
let (>>|) e f = map_extract f e

let (<*>) ef ex = fun record ->
  match ef record, ex record with
  | Ok f, Ok x -> Ok (f x)
  | Error e, _ -> Error e
  | _, Error e -> Error e

let (<$>) f e = map_extract f e
