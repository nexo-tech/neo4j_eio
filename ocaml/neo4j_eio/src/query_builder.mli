(** Declarative query builder DSL for constructing Cypher queries.

    This module provides a fluent interface for building Cypher queries
    in a type-safe, composable manner. It supports common query patterns
    like MATCH, WHERE, RETURN with parameters.

    {[
      open QueryBuilder

      (* Build a query declaratively *)
      let query =
        match_ "(p:Person)"
        |> where "p.age > $min_age"
        |> and_where "p.active = $active"
        |> return ["p.name AS name"; "p.age AS age"]
        |> order_by "p.age DESC"
        |> limit 10
        |> with_params ["min_age", Value.int 18L; "active", Value.bool true]
        |> build

      (* Execute the query *)
      let results = Cypher.query query |> Cypher.run_in session
    ]}
*)

(** {1 Core Types} *)

(** A query builder accumulates query components *)
type t

(** {1 Construction} *)

(** [raw cypher] starts a query builder with a raw Cypher string. *)
val raw : string -> t

(** [match_ pattern] starts a MATCH query. *)
val match_ : string -> t

(** [optional_match pattern] starts an OPTIONAL MATCH query. *)
val optional_match : string -> t

(** [create_node pattern] starts a CREATE query. *)
val create_node : string -> t

(** [merge pattern] starts a MERGE query. *)
val merge : string -> t

(** [unwind expr] starts an UNWIND query. *)
val unwind : string -> string -> t  (* expression, alias *)

(** {1 Filtering} *)

(** [where condition builder] adds a WHERE clause. *)
val where : string -> t -> t

(** [and_where condition builder] adds an AND condition to WHERE. *)
val and_where : string -> t -> t

(** [or_where condition builder] adds an OR condition to WHERE. *)
val or_where : string -> t -> t

(** {1 Return and Projection} *)

(** [return fields builder] adds a RETURN clause. *)
val return : string list -> t -> t

(** [return_distinct fields builder] adds a RETURN DISTINCT clause. *)
val return_distinct : string list -> t -> t

(** [with_ fields builder] adds a WITH clause. *)
val with_ : string list -> t -> t

(** {1 Ordering and Limiting} *)

(** [order_by expr builder] adds an ORDER BY clause. *)
val order_by : string -> t -> t

(** [order_by_desc expr builder] adds an ORDER BY ... DESC clause. *)
val order_by_desc : string -> t -> t

(** [limit n builder] adds a LIMIT clause. *)
val limit : int -> t -> t

(** [skip n builder] adds a SKIP clause. *)
val skip : int -> t -> t

(** {1 Mutations} *)

(** [create pattern builder] adds a CREATE clause. *)
val create : string -> t -> t

(** [set assignments builder] adds a SET clause. *)
val set : string list -> t -> t

(** [delete nodes builder] adds a DELETE clause. *)
val delete : string list -> t -> t

(** [detach_delete nodes builder] adds a DETACH DELETE clause. *)
val detach_delete : string list -> t -> t

(** {1 Parameters} *)

(** [with_params params builder] adds query parameters. *)
val with_params : (string * Value.value) list -> t -> t

(** [with_param name value builder] adds a single parameter. *)
val with_param : string * Value.value -> t -> t

(** {1 Building} *)

(** [build builder] produces the final Cypher query string. *)
val build : t -> string

(** [build_with_params builder] produces both query and parameters. *)
val build_with_params : t -> string * (string * Value.value) list

(** [to_string builder] is an alias for [build]. *)
val to_string : t -> string

(** {1 Execution Helpers} *)

(** [execute builder session] builds and executes the query, returning records. *)
val execute : t -> ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> (Record.t list, Error.t) result

(** [execute_unit builder session] executes the query, discarding results. *)
val execute_unit : t -> ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> (unit, Error.t) result

(** {1 Convenience Constructors} *)

(** [select fields pattern] creates a simple MATCH query.
    Use this as a starting point, then add WHERE, RETURN, etc.
    This is just an alias for [match_]. *)
val select : string list -> string -> t  (* fields (ignored), pattern *)

(** [insert pattern props] creates a CREATE query with properties. *)
val insert : string -> (string * Value.value) list -> t

(** [update pattern set_clause] creates a MATCH ... SET query. *)
val update : string -> string list -> t

(** [remove pattern] creates a DELETE query. *)
val remove : string -> t
