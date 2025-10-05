(** Traversals for working with collections of values and records.

    This module provides traversals (a generalization of lenses) that
    can focus on multiple values within a structure. Traversals are
    useful for accessing, modifying, or aggregating over collections.

    {[
      open Traversal

      (* Extract all names from a list of records *)
      let names = records ^.. each >>> Lens.field_text "name"

      (* Sum all ages *)
      let total_age = records |> fold_int (each >>> Lens.field_int "age") 0L (+)

      (* Map over all values *)
      let incremented = values |> each %~ (fun x -> x + 1)
    ]}
*)

(** {1 Core Types} *)

(** A traversal that can focus on zero or more ['a] values within ['s]. *)
type ('s, 'a) t

(** {1 Construction} *)

(** [traverse f] creates a traversal from a function that extracts a list of values. *)
val traverse : ('s -> 'a list) -> ('s, 'a) t

(** [each] is a traversal that focuses on each element in a list. *)
val each : ('a list, 'a) t

(** [records] is a traversal for lists of records. *)
val records : (Record.t list, Record.t) t

(** [values] is a traversal for lists of values. *)
val values : (Value.value list, Value.value) t

(** [filtered pred] creates a traversal that only focuses on elements matching [pred]. *)
val filtered : ('a -> bool) -> ('a list, 'a) t

(** {1 Operators} *)

(** [s ^.. trav] extracts all focused values as a list. *)
val (^..) : 's -> ('s, 'a) t -> 'a list

(** [s ^? trav] extracts the first focused value, if any. *)
val (^?) : 's -> ('s, 'a) t -> 'a option

(** [trav %~ f] applies function [f] to all focused values.
    Note: This returns a modified list, not the original structure. *)
val (%~) : ('a list, 'a) t -> ('a -> 'a) -> 'a list -> 'a list

(** {1 Composition} *)

(** [trav >>> lens] composes a traversal with a lens. *)
val (>>>) : ('s, 'a) t -> ('a -> 'b option) -> ('s, 'b) t

(** [compose_lens trav lens] is an alias for [>>>]. *)
val compose_lens : ('s, 'a) t -> ('a -> 'b option) -> ('s, 'b) t

(** [compose_traversals t1 t2] composes two traversals. *)
val compose_traversals : ('s, 'a) t -> ('a, 'b) t -> ('s, 'b) t

(** {1 Extraction} *)

(** [to_list s trav] extracts all focused values as a list. *)
val to_list : 's -> ('s, 'a) t -> 'a list

(** [to_option s trav] extracts the first focused value, if any. *)
val to_option : 's -> ('s, 'a) t -> 'a option

(** [head trav s] gets the first element. *)
val head : ('s, 'a) t -> 's -> 'a option

(** [last trav s] gets the last element. *)
val last : ('s, 'a) t -> 's -> 'a option

(** {1 Folds} *)

(** [fold f init trav s] folds over all focused values. *)
val fold : ('b -> 'a -> 'b) -> 'b -> ('s, 'a) t -> 's -> 'b

(** [fold_right f trav s init] folds from the right. *)
val fold_right : ('a -> 'b -> 'b) -> ('s, 'a) t -> 's -> 'b -> 'b

(** [fold_int trav init f s] folds over int64 values. *)
val fold_int : ('s, int64) t -> int64 -> (int64 -> int64 -> int64) -> 's -> int64

(** [fold_float trav init f s] folds over float values. *)
val fold_float : ('s, float) t -> float -> (float -> float -> float) -> 's -> float

(** {1 Aggregations} *)

(** [sum_int trav s] sums all int64 values. *)
val sum_int : ('s, int64) t -> 's -> int64

(** [sum_float trav s] sums all float values. *)
val sum_float : ('s, float) t -> 's -> float

(** [count trav s] counts the number of focused values. *)
val count : ('s, 'a) t -> 's -> int

(** [length trav s] is an alias for [count]. *)
val length : ('s, 'a) t -> 's -> int

(** [average_int trav s] computes the average of int64 values.
    Returns [None] if the traversal is empty. *)
val average_int : ('s, int64) t -> 's -> int64 option

(** [average_float trav s] computes the average of float values.
    Returns [None] if the traversal is empty. *)
val average_float : ('s, float) t -> 's -> float option

(** [minimum compare trav s] finds the minimum value.
    Returns [None] if the traversal is empty. *)
val minimum : ('a -> 'a -> int) -> ('s, 'a) t -> 's -> 'a option

(** [maximum compare trav s] finds the maximum value.
    Returns [None] if the traversal is empty. *)
val maximum : ('a -> 'a -> int) -> ('s, 'a) t -> 's -> 'a option

(** {1 Predicates} *)

(** [any pred trav s] tests if any focused value satisfies [pred]. *)
val any : ('a -> bool) -> ('s, 'a) t -> 's -> bool

(** [all pred trav s] tests if all focused values satisfy [pred]. *)
val all : ('a -> bool) -> ('s, 'a) t -> 's -> bool

(** [none pred trav s] tests if no focused value satisfies [pred]. *)
val none : ('a -> bool) -> ('s, 'a) t -> 's -> bool

(** [has trav s] tests if the traversal focuses on at least one value. *)
val has : ('s, 'a) t -> 's -> bool

(** {1 Transformations} *)

(** [map f trav] maps a function over each focused value. *)
val map : ('a -> 'b) -> ('s, 'a) t -> ('s, 'b) t

(** [filter pred trav] filters focused values by predicate. *)
val filter : ('a -> bool) -> ('s, 'a) t -> ('s, 'a) t

(** [take n trav] limits the traversal to the first [n] elements. *)
val take : int -> ('s, 'a) t -> ('s, 'a) t

(** [drop n trav] skips the first [n] elements. *)
val drop : int -> ('s, 'a) t -> ('s, 'a) t

(** {1 Utilities} *)

(** [concat trav s] concatenates all list values focused by the traversal. *)
val concat : ('s, 'a list) t -> 's -> 'a list

(** [concat_map f trav s] maps [f] over focused values and concatenates results. *)
val concat_map : ('a -> 'b list) -> ('s, 'a) t -> 's -> 'b list

(** [partition pred trav s] partitions focused values by predicate.
    Returns [(matching, non_matching)]. *)
val partition : ('a -> bool) -> ('s, 'a) t -> 's -> 'a list * 'a list
