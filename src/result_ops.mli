(** Result monad combinators and operators for elegant error handling.

    This module provides monadic operations, let-syntax bindings, and
    combinators for working with Result types, inspired by Haskell's
    Either monad and OCaml's modern monadic syntax.

    Example usage:
    {[
      let open Result_ops in
      let* x = Ok 5 in
      let* y = Ok 10 in
      return (x + y)
      (* Result: Ok 15 *)
    ]}
*)

(** {1 Core Monadic Operations} *)

val return : 'a -> ('a, 'e) result
(** [return x] wraps a value in the Result monad.
    Equivalent to [Ok x]. *)

val fail : 'e -> ('a, 'e) result
(** [fail e] creates a failure in the Result monad.
    Equivalent to [Error e]. *)

val bind : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
(** [bind r f] applies [f] to the value in [r] if it's [Ok],
    or propagates the error. *)

val map : ('a -> 'b) -> ('a, 'e) result -> ('b, 'e) result
(** [map f r] applies [f] to the value in [r] if it's [Ok]. *)

val map_error : ('e1 -> 'e2) -> ('a, 'e1) result -> ('a, 'e2) result
(** [map_error f r] applies [f] to the error in [r] if it's [Error]. *)

val join : (('a, 'e) result, 'e) result -> ('a, 'e) result
(** [join r] flattens a nested Result. *)

(** {1 Let-Syntax Bindings} *)

val (let*) : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
(** [let* x = r in f x] is monadic bind.
    Equivalent to [bind r f]. *)

val (let+) : ('a, 'e) result -> ('a -> 'b) -> ('b, 'e) result
(** [let+ x = r in f x] is monadic map.
    Equivalent to [map f r]. *)

val (and+) : ('a, 'e) result -> ('b, 'e) result -> ('a * 'b, 'e) result
(** [let+ x = r1 and+ y = r2 in (x, y)] combines two Results.
    Fails if either fails. *)

(** {1 Infix Operators} *)

val (>>=) : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
(** [r >>= f] is infix bind. *)

val (>>|) : ('a, 'e) result -> ('a -> 'b) -> ('b, 'e) result
(** [r >>| f] is infix map. *)

val (>=>) : ('a -> ('b, 'e) result) -> ('b -> ('c, 'e) result) -> ('a -> ('c, 'e) result)
(** [f >=> g] is Kleisli composition.
    [(f >=> g) x = f x >>= g]. *)

val (<=<) : ('b -> ('c, 'e) result) -> ('a -> ('b, 'e) result) -> ('a -> ('c, 'e) result)
(** [g <=< f] is reverse Kleisli composition.
    Equivalent to [f >=> g]. *)

(** {1 Applicative Operations} *)

val pure : 'a -> ('a, 'e) result
(** [pure x] is an alias for [return x]. *)

val apply : ('a -> 'b, 'e) result -> ('a, 'e) result -> ('b, 'e) result
(** [apply rf r] applies the function in [rf] to the value in [r]. *)

val (<*>) : ('a -> 'b, 'e) result -> ('a, 'e) result -> ('b, 'e) result
(** [rf <*> r] is infix apply. *)

val (<$>) : ('a -> 'b) -> ('a, 'e) result -> ('b, 'e) result
(** [f <$> r] is infix map (functor map). *)

val lift2 : ('a -> 'b -> 'c) -> ('a, 'e) result -> ('b, 'e) result -> ('c, 'e) result
(** [lift2 f r1 r2] lifts a binary function into Result. *)

val lift3 : ('a -> 'b -> 'c -> 'd) -> ('a, 'e) result -> ('b, 'e) result -> ('c, 'e) result -> ('d, 'e) result
(** [lift3 f r1 r2 r3] lifts a ternary function into Result. *)

(** {1 Alternative Operations} *)

val (<|>) : ('a, 'e) result -> ('a, 'e) result -> ('a, 'e) result
(** [r1 <|> r2] returns [r1] if it's [Ok], otherwise [r2]. *)

val alt : ('a, 'e) result list -> ('a, 'e) result
(** [alt rs] returns the first [Ok] in [rs], or the last [Error]. *)

val guard : bool -> 'e -> (unit, 'e) result
(** [guard cond err] returns [Ok ()] if [cond] is true, [Error err] otherwise. *)

(** {1 Combinators} *)

val sequence : ('a, 'e) result list -> ('a list, 'e) result
(** [sequence rs] converts a list of Results into a Result of list.
    Fails if any Result fails. *)

val traverse : ('a -> ('b, 'e) result) -> 'a list -> ('b list, 'e) result
(** [traverse f xs] maps [f] over [xs] and sequences the results. *)

val fold_left_m : ('b -> 'a -> ('b, 'e) result) -> 'b -> 'a list -> ('b, 'e) result
(** [fold_left_m f init xs] monadic left fold. *)

val fold_right_m : ('a -> 'b -> ('b, 'e) result) -> 'a list -> 'b -> ('b, 'e) result
(** [fold_right_m f xs init] monadic right fold. *)

val filter_m : ('a -> (bool, 'e) result) -> 'a list -> ('a list, 'e) result
(** [filter_m p xs] filters [xs] with monadic predicate [p]. *)

val map_m : ('a -> ('b, 'e) result) -> 'a list -> ('b list, 'e) result
(** [map_m f xs] is an alias for [traverse f xs]. *)

val iter_m : ('a -> (unit, 'e) result) -> 'a list -> (unit, 'e) result
(** [iter_m f xs] iterates [f] over [xs], sequencing effects. *)

(** {1 Utility Functions} *)

val is_ok : ('a, 'e) result -> bool
(** [is_ok r] returns true if [r] is [Ok]. *)

val is_error : ('a, 'e) result -> bool
(** [is_error r] returns true if [r] is [Error]. *)

val from_option : 'e -> 'a option -> ('a, 'e) result
(** [from_option err opt] converts an option to Result. *)

val to_option : ('a, 'e) result -> 'a option
(** [to_option r] converts a Result to option, discarding errors. *)

val catch : (unit -> 'a) -> (exn -> 'e) -> ('a, 'e) result
(** [catch f handler] catches exceptions from [f] and converts to Result. *)

val or_else : ('a, 'e) result -> (unit -> ('a, 'e) result) -> ('a, 'e) result
(** [or_else r f] returns [r] if Ok, otherwise evaluates [f ()]. *)

val unless : bool -> (unit -> (unit, 'e) result) -> (unit, 'e) result
(** [unless cond f] evaluates [f ()] unless [cond] is true. *)

val when_ : bool -> (unit -> (unit, 'e) result) -> (unit, 'e) result
(** [when_ cond f] evaluates [f ()] when [cond] is true. *)

(** {1 Bimap and Swap} *)

val bimap : ('a -> 'b) -> ('e1 -> 'e2) -> ('a, 'e1) result -> ('b, 'e2) result
(** [bimap f g r] maps [f] over Ok values and [g] over Error values. *)

val swap : ('a, 'e) result -> ('e, 'a) result
(** [swap r] swaps Ok and Error. *)

(** {1 Pair Operations} *)

val both : ('a, 'e) result -> ('b, 'e) result -> ('a * 'b, 'e) result
(** [both r1 r2] combines two Results into a pair.
    Fails if either fails. Equivalent to [and+]. *)

val fst : ('a * 'b, 'e) result -> ('a, 'e) result
(** [fst r] extracts the first element from a pair Result. *)

val snd : ('a * 'b, 'e) result -> ('b, 'e) result
(** [snd r] extracts the second element from a pair Result. *)
