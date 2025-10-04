(* High-level Neo4j API *)

(* Parameter building helpers *)

val (=:) : string -> Value.value -> string * Value.value
(* Create a key-value pair for query parameters.
   Example: "name" =: Value.text "Alice" *)

val props : (string * Value.value) list -> Value.value Value.StringMap.t
(* Build a parameter map from a list of key-value pairs.
   Example: props ["name" =: Value.text "Alice"; "age" =: Value.int 30] *)

(* Query execution functions *)

val query_p :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (Value.value list, Error.t) result
(* Execute a Cypher query with parameters, returning all records *)

val query :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  unit ->
  (Value.value list, Error.t) result
(* Execute a Cypher query without parameters, returning all records *)

val query_p_ :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (unit, Error.t) result
(* Execute a Cypher query with parameters, ignoring results *)

val query_ :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  unit ->
  (unit, Error.t) result
(* Execute a Cypher query without parameters, ignoring results *)
