(* High-level Neo4j API *)

(* Parameter building helpers *)

(* Build a (key, value) pair for parameters *)
let (=:) key value = (key, value)

(* Build a parameter map from list of key-value pairs *)
let props pairs =
  List.fold_left (fun acc (k, v) ->
    Value.StringMap.add k v acc
  ) Value.StringMap.empty pairs

(* Query execution functions *)

(* Execute a Cypher query with parameters, returning records *)
let query_p session ~statement ?(parameters = Value.StringMap.empty) () =
  Session.run session ~statement ~parameters ()

(* Execute a Cypher query without parameters, returning records *)
let query session ~statement () =
  query_p session ~statement ()

(* Execute a Cypher query with parameters, ignoring results *)
let query_p_ session ~statement ?(parameters = Value.StringMap.empty) () =
  match Session.run session ~statement ~parameters () with
  | Ok _ -> Ok ()
  | Error e -> Error e

(* Execute a Cypher query without parameters, ignoring results *)
let query_ session ~statement () =
  query_p_ session ~statement ()
