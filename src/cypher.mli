(** Fluent, composable Cypher queries with transformation pipeline.

    Build queries with {!query}/{!with_params}, transform results with
    {!extract}, {!map}, {!single}, etc., and execute with {!run}.
*)

(** Abstract query type. ['a] is the final result type after transformations. *)
type 'a t

(** {1 Construction} *)

val query : string -> Record.t list t
(** [query stmt] creates a base query that yields the raw record list. *)

val query_unit : string -> unit t
(** [query_unit stmt] creates a base query that discards results. *)

val with_params : (string * Value.value) list -> 'a t -> 'a t
(** Attach parameters to a query. Later calls are appended (left-biased). *)

val param : string -> Value.value -> string * Value.value
(** Helper to build a [(name, value)] parameter pair. *)

val ( =: ) : string -> Value.value -> string * Value.value
(** Infix alias for {!param}. *)

(** {1 Value Constructors}

    Re-exported from {!Value} for convenience in building parameters. *)

val int : int64 -> Value.value
(** Construct an integer value. Alias for {!Value.int}. *)

val text : string -> Value.value
(** Construct a text value. Alias for {!Value.text}. *)

val bool : bool -> Value.value
(** Construct a boolean value. Alias for {!Value.bool}. *)

val float : float -> Value.value
(** Construct a float value. Alias for {!Value.float}. *)

val list : Value.value list -> Value.value
(** Construct a list value. Alias for {!Value.list}. *)

val props : (string * Value.value) list -> (string * Value.value) list
(** Identity function for parameter lists. Useful for clarity when building params.

    {[
      query "CREATE (n {name: $name})"
      |> with_params (props ["name" =: text "Alice"])
    ]}
*)

(** {1 Transformations} *)

val extract : 'a Extract.t -> Record.t list t -> 'a list t
(** Apply an {!Extract.t} to each record, collecting results. Fails on decode error. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** Map over the final result. *)

val bind : 'a t -> ('a -> 'b t) -> 'b t
(** Monadic bind for sequencing dependent queries. *)

val single : 'a list t -> 'a option t
(** Convert a list result to an option (expects zero or one element). *)

val expect_one : 'a list t -> 'a t
(** Expect exactly one element, otherwise fail with a client error. *)

val first : 'a list t -> 'a option t
val head : 'a list t -> 'a option t
(** Aliases to get the first element as an option. *)

val take : int -> 'a list t -> 'a list t
(** Take the first [n] elements. *)

val filter : ('a -> bool) -> 'a list t -> 'a list t
(** Filter elements by predicate. *)

val flat_map : ('a -> 'b list) -> 'a list t -> 'b list t
(** Apply a function that returns a list to each element and flatten the results.

    {[
      query "RETURN 'a,b,c' AS csv"
      |> extract Extract.(text "csv")
      |> flat_map (String.split_on_char ',')
      (* Results in ["a"; "b"; "c"] *)
    ]}
*)

val reverse : 'a list t -> 'a list t
(** Reverse the order of elements in a list result. *)

val sort_by : ('a -> 'b) -> 'a list t -> 'a list t
(** Sort elements by a key function. Uses OCaml's polymorphic compare. *)

val sum_int : int64 list t -> int64 t
(** Sum a list of integers. Returns 0L for empty lists. *)

val average_int : int64 list t -> int64 t
(** Compute the average of a list of integers. Returns 0L for empty lists. *)

val count : 'a list t -> int64 t
(** Count the number of elements in a list result. *)

val group_by : ('a -> 'b) -> 'a list t -> ('b * 'a list) list t
(** Group elements by a key function. Returns a list of [(key, elements)] pairs. *)

val recover : (Error.t -> ('a, Error.t) result) -> 'a t -> 'a t
(** Recover from errors by providing a fallback function.

    {[
      query "MATCH (n:Missing) RETURN n"
      |> recover (fun _ -> Ok [])
      (* Returns empty list instead of failing *)
    ]}
*)

val sequence : 'a t list -> 'a list t
(** Execute multiple queries in sequence and collect their results.
    Stops at the first error. *)

val sequence_unit : unit t list -> unit t
(** Execute multiple unit queries in sequence. Stops at the first error. *)

val sort : ('a -> 'a -> int) -> 'a list t -> 'a list t
(** Sort elements using a custom comparison function.

    {[
      query "RETURN [3, 1, 2] AS numbers"
      |> extract Extract.(list int "numbers")
      |> sort Int64.compare
    ]}
*)

val min_by : ('a -> 'b) -> 'a list t -> 'a option t
(** Find the minimum element by a key function. Returns None for empty lists. *)

val sliding_window : int -> 'a list t -> 'a list list t
(** Create sliding windows of the given size over the list.

    {[
      [1; 2; 3; 4] |> sliding_window 2
      (* Results in [[1; 2]; [2; 3]; [3; 4]] *)
    ]}
*)

val max_by : ('a -> 'b) -> 'a list t -> 'a option t
(** Find the maximum element by a key function. Returns None for empty lists. *)

val chunk : int -> 'a list t -> 'a list list t
(** Split a list into chunks of the given size. *)

val deduplicate_by : ('a -> 'b) -> 'a list t -> 'a list t
(** Remove duplicates based on a key function, keeping the first occurrence. *)

val exists : ('a -> bool) -> 'a list t -> bool t
(** Check if any element satisfies the predicate. *)

val for_all : ('a -> bool) -> 'a list t -> bool t
(** Check if all elements satisfy the predicate. *)

val indexed : 'a list t -> (int * 'a) list t
(** Add zero-based indices to each element. *)

val nth : int -> 'a list t -> 'a option t
(** Get the nth element (zero-based). Returns None if index is out of bounds. *)

val take_while : ('a -> bool) -> 'a list t -> 'a list t
(** Take elements from the start while the predicate is true. *)

val drop_while : ('a -> bool) -> 'a list t -> 'a list t
(** Drop elements from the start while the predicate is true. *)

val span : ('a -> bool) -> 'a list t -> ('a list * 'a list) t
(** Split a list at the point where the predicate becomes false.
    Returns (prefix, suffix) where all elements in prefix satisfy the predicate. *)

val assert_non_empty : 'a list t -> 'a list t
(** Assert that the result is non-empty. Fails with ClientError if empty. *)

val assert_at_least : int -> 'a list t -> 'a list t
(** Assert that the result has at least n elements. *)

val assert_at_most : int -> 'a list t -> 'a list t
(** Assert that the result has at most n elements. *)

val assert_count : int -> 'a list t -> 'a list t
(** Assert that the result has exactly n elements. *)

val find : ('a -> bool) -> 'a list t -> 'a option t
(** Find the first element matching the predicate. Returns None if not found. *)

val with_timing : 'a t -> ('a * float) t
(** Wrap a query result with timing information (result, duration_in_seconds). *)

val partition : ('a -> bool) -> 'a list t -> ('a list * 'a list) t
(** Partition a list into two lists based on a predicate.
    Returns (elements_satisfying_predicate, elements_not_satisfying_predicate). *)

val distinct : 'a list t -> 'a list t
(** Remove duplicate elements from a list. *)

val reduce : ('b -> 'a -> 'b) -> 'b -> 'a list t -> 'b t
(** Fold/reduce over a list with an accumulator function and initial value. *)

val fold_left : ('b -> 'a -> 'b) -> 'b -> 'a list t -> 'b t
(** Alias for {!reduce}. Fold left over a list. *)

val tap : ('a -> unit) -> 'a t -> 'a t
(** Execute a side-effect function on the result without changing it.
    Useful for debugging or logging in the middle of a pipeline. *)

(** {1 Execution} *)

val run : 'a t -> ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> ('a, Error.t) result
(** Execute a query in a session. *)

val run_exn : 'a t -> ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> 'a
(** Execute a query, raising on error. *)

val execute : ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> 'a t -> ('a, Error.t) result
(** Curried execution for pipelines: [session |> execute query]. *)

val execute_exn : ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> 'a t -> 'a
(** Curried execution that raises on error. *)

val ( |>> ) : 'a t -> ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> ('a, Error.t) result
(** Pipeline operator: [query |>> session] = [run query session]. *)

val run_in : ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> 'a t -> ('a, Error.t) result
val run_in_exn : ([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> 'a t -> 'a
(** Aliases for curried execution. *)

(** {1 Transactional} *)

val in_transaction :
  (([> `Flow | `R | `W ] Eio.Resource.t) Session.t -> ('a, Error.t) result) -> 'a t
(** Lift a function that operates in a transaction into a query value. *)

(** {1 Let-syntax and operators} *)

val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
val ( and+ ) : 'a t -> 'b t -> ('a * 'b) t
val ( >>= ) : 'a t -> ('a -> 'b t) -> 'b t
