(* High-level Neo4j API *)

(* Parameter building helpers *)

(* Build a (key, value) pair for parameters - value is already a Value.value *)
let (=:) key value = (key, value)

(* Polymorphic parameter helpers - automatically wrap common types *)
let int n = Value.Int n
let text s = Value.Text s
let bool b = Value.Bool b
let float f = Value.Float f
let null = Value.Null

(* Build a parameter map from list of key-value pairs *)
let props pairs =
  List.fold_left (fun acc (k, v) ->
    Value.StringMap.add k v acc
  ) Value.StringMap.empty pairs

(* Query execution functions *)

(* Execute a Cypher query, optionally with parameters, returning records *)
let query session ~statement ?parameters () =
  let params = match parameters with
    | None -> Value.StringMap.empty
    | Some p -> p
  in
  Session.run_records session ~statement ~parameters:params ()

(* Execute a Cypher query, optionally with parameters, ignoring results *)
let query_ session ~statement ?parameters () =
  match query session ~statement ?parameters () with
  | Ok _ -> Ok ()
  | Error e -> Error e

(* Legacy aliases for compatibility - will be removed *)
let query_p = query
let query_p_ = query_
