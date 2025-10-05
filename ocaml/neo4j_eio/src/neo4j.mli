(* High-level Neo4j API *)

(* Parameter building helpers *)

val (=:) : string -> Value.value -> string * Value.value
(* Create a key-value pair for query parameters.
   Example: "name" =: text "Alice" *)

val props : (string * Value.value) list -> Value.value Value.StringMap.t
(* Build a parameter map from a list of key-value pairs.
   Example: props ["name" =: text "Alice"; "age" =: int 30L] *)

(* Convenience helpers to wrap common types *)
val int : int64 -> Value.value
val text : string -> Value.value
val bool : bool -> Value.value
val float : float -> Value.value
val null : Value.value

(* Query execution functions *)

val query :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (Value.value list, Error.t) result
(* Execute a Cypher query, optionally with parameters, returning all records.
   Example: query session ~statement:"RETURN $n" ~parameters:(props ["n" =: int 42L]) () *)

val query_ :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (unit, Error.t) result
(* Execute a Cypher query, optionally with parameters, ignoring results.
   Example: query_ session ~statement:"CREATE (n {name: $name})" ~parameters:(props ["name" =: text "Alice"]) () *)

val query_records :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (Value.record list, Error.t) result
(* Execute a Cypher query, optionally with parameters, returning records with named fields.
   Use Value.at to extract field values by name.
   Example: query_records session ~statement:"RETURN 42 AS n" () >>= fun records ->
            match records with
            | [rec] -> Value.at rec "n"
            | _ -> None *)

(* Legacy aliases for backward compatibility *)
val query_p :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (Value.value list, Error.t) result

val query_p_ :
  [> `Flow | `R | `W ] Eio.Resource.t Session.t ->
  statement:string ->
  ?parameters:Value.value Value.StringMap.t ->
  unit ->
  (unit, Error.t) result
