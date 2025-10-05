(** Monadic record field extraction with applicative composition.

    This module provides elegant field extraction from Neo4j records using
    monadic and applicative syntax, inspired by Haskell's parser combinators
    and hasbolt's extraction API.

    Example usage:
    {[
      let person_extractor =
        let open Extract in
        let+ name = text "name"
        and+ age = int "age"
        and+ email = optional (text "email") in
        { name; age; email }

      (* Usage *)
      match Extract.run person_extractor record with
      | Ok person -> Printf.printf "%s: %Ld\n" person.name person.age
      | Error e -> Format.eprintf "%a" Record.pp_decode_error e
    ]}
*)

(** {1 Core Types} *)

type 'a t
(** ['a t] is an extractor that extracts a value of type ['a] from a record. *)

(** {1 Monadic Operations} *)

val return : 'a -> 'a t
(** [return x] creates an extractor that always returns [x]. *)

val fail : Record.decode_error -> 'a t
(** [fail err] creates an extractor that always fails with [err]. *)

val bind : 'a t -> ('a -> 'b t) -> 'b t
(** [bind e f] sequences two extractors, passing the result of [e] to [f]. *)

(** {1 Let-Syntax Bindings} *)

val (let*) : 'a t -> ('a -> 'b t) -> 'b t
(** [let* x = e in f x] is monadic bind for extractors. *)

val (let+) : 'a t -> ('a -> 'b) -> 'b t
(** [let+ x = e in f x] is functor map for extractors. *)

val (and+) : 'a t -> 'b t -> ('a * 'b) t
(** [let+ x = e1 and+ y = e2 in (x, y)] combines extractors applicatively. *)

(** {1 Field Extractors} *)

val field : string -> (Record.t -> string -> ('a, Record.decode_error) result) -> 'a t
(** [field key decoder] extracts a field using a custom decoder function.
    The decoder function should be one of [Record.at_*] functions. *)

val text : string -> string t
(** [text key] extracts a text field. *)

val int : string -> int64 t
(** [int key] extracts an int64 field. *)

val int_as_int : string -> int t
(** [int_as_int key] extracts an int field. *)

val bool : string -> bool t
(** [bool key] extracts a boolean field. *)

val float : string -> float t
(** [float key] extracts a float field. *)

val bytes : string -> string t
(** [bytes key] extracts a bytes field. *)

val node : string -> Value.node t
(** [node key] extracts a node field. *)

val relationship : string -> Value.relationship t
(** [relationship key] extracts a relationship field. *)

val unbound_relationship : string -> Value.urelationship t
(** [unbound_relationship key] extracts an unbound relationship field. *)

val path : string -> Value.path t
(** [path key] extracts a path field. *)

val point2d : string -> Value.point2d t
(** [point2d key] extracts a 2D point field. *)

val point3d : string -> Value.point3d t
(** [point3d key] extracts a 3D point field. *)

val duration : string -> Value.duration t
(** [duration key] extracts a duration field. *)

val date : string -> Value.date t
(** [date key] extracts a date field. *)

val local_time : string -> Value.local_time t
(** [local_time key] extracts a local time field. *)

val time : string -> Value.time t
(** [time key] extracts a time field. *)

val local_datetime : string -> Value.local_datetime t
(** [local_datetime key] extracts a local datetime field. *)

val datetime_zone_id : string -> Value.datetime_zone_id t
(** [datetime_zone_id key] extracts a datetime with zone ID field. *)

val datetime_offset : string -> Value.datetime_offset t
(** [datetime_offset key] extracts a datetime with offset field. *)

val value : string -> Value.value t
(** [value key] extracts a raw value field. *)

val list : string -> (Value.value -> ('a, Record.decode_error) result) -> 'a list t
(** [list key decoder] extracts a list field with element decoder. *)

val map_field : string -> Value.value Value.StringMap.t t
(** [map_field key] extracts a map field. *)

(** {1 Optional Extractors} *)

val optional : 'a t -> 'a option t
(** [optional e] makes an extractor optional, returning [None] if the field
    is missing or null. Still fails on type mismatches. *)

val default : 'a -> 'a t -> 'a t
(** [default v e] provides a default value if extraction fails. *)

val maybe : string -> (Record.t -> string -> ('a option, Record.decode_error) result) -> 'a option t
(** [maybe key decoder] extracts an optional field using a maybe_at_* decoder. *)

val maybe_text : string -> string option t
(** [maybe_text key] extracts an optional text field. *)

val maybe_int : string -> int64 option t
(** [maybe_int key] extracts an optional int64 field. *)

val maybe_bool : string -> bool option t
(** [maybe_bool key] extracts an optional boolean field. *)

val maybe_float : string -> float option t
(** [maybe_float key] extracts an optional float field. *)

val maybe_node : string -> Value.node option t
(** [maybe_node key] extracts an optional node field. *)

val maybe_relationship : string -> Value.relationship option t
(** [maybe_relationship key] extracts an optional relationship field. *)

val maybe_path : string -> Value.path option t
(** [maybe_path key] extracts an optional path field. *)

(** {1 Combinators} *)

val both : 'a t -> 'b t -> ('a * 'b) t
(** [both e1 e2] combines two extractors into a pair.
    Equivalent to [and+]. *)

val sequence : 'a t list -> 'a list t
(** [sequence es] sequences a list of extractors into an extractor of a list. *)

val all : ('a -> 'b t) -> 'a list -> 'b list t
(** [all f xs] maps [f] over [xs] and sequences the results. *)

(** {1 Execution} *)

val run : 'a t -> Record.t -> ('a, Record.decode_error) result
(** [run e record] runs the extractor on a record, returning a Result. *)

val run_exn : 'a t -> Record.t -> 'a
(** [run_exn e record] runs the extractor on a record, raising on failure. *)

(** {1 Infix Operators} *)

val (>>=) : 'a t -> ('a -> 'b t) -> 'b t
(** [e >>= f] is infix bind. *)

val (>>|) : 'a t -> ('a -> 'b) -> 'b t
(** [e >>| f] is infix map. *)

val (<*>) : ('a -> 'b) t -> 'a t -> 'b t
(** [ef <*> ex] applies an extracted function to an extracted value. *)

val (<$>) : ('a -> 'b) -> 'a t -> 'b t
(** [f <$> e] is infix map (functor). *)

(** {1 Composite Extractors}

    These are higher-level extractors that combine common patterns,
    making the API easier to use for frequent use cases. *)

val pair : string -> string -> (Record.t -> string -> ('a, Record.decode_error) result) -> (Record.t -> string -> ('b, Record.decode_error) result) -> ('a * 'b) t
(** [pair k1 k2 d1 d2] extracts two fields as a tuple using the given decoders. *)

val triple : string -> string -> string -> (Record.t -> string -> ('a, Record.decode_error) result) -> (Record.t -> string -> ('b, Record.decode_error) result) -> (Record.t -> string -> ('c, Record.decode_error) result) -> ('a * 'b * 'c) t
(** [triple k1 k2 k3 d1 d2 d3] extracts three fields as a tuple using the given decoders. *)

val text_int : string -> string -> (string * int64) t
(** [text_int k1 k2] extracts two fields: text and int. Common for name+id patterns. *)

val text_list : string -> string list t
(** [text_list key] extracts a list of text values from a list field. *)

val int_list : string -> int64 list t
(** [int_list key] extracts a list of int64 values from a list field. *)

val node_props : string -> Value.value Value.StringMap.t t
(** [node_props key] extracts a node's properties map. *)

val node_labels : string -> string list t
(** [node_labels key] extracts a node's labels. *)

val node_id : string -> int64 t
(** [node_id key] extracts a node's ID. *)

val rel_type : string -> string t
(** [rel_type key] extracts a relationship's type. *)

val rel_props : string -> Value.value Value.StringMap.t t
(** [rel_props key] extracts a relationship's properties. *)

val rel_id : string -> int64 t
(** [rel_id key] extracts a relationship's ID. *)
