(** Record abstraction for Neo4j query results.

    A record is a string-keyed map of {!Value.value} as returned by Cypher
    queries. This module provides type-directed decoders and field accessors
    that return precise errors on mismatch. *)

(** A record is an ordered map from string keys to values. *)
type t = Value.value Value.StringMap.t

(** Decode errors describing why a value could not be decoded. *)
type decode_error =
  | NotNull
  | NotBool
  | NotInt
  | NotFloat
  | NotText
  | NotBytes
  | NotList
  | NotMap
  | NotStruct
  | NotNode
  | NotRelationship
  | NotUnboundRelationship
  | NotPath
  | NotPoint2D
  | NotPoint3D
  | NotDuration
  | NotDate
  | NotLocalTime
  | NotTime
  | NotLocalDateTime
  | NotDateTimeZoneId
  | NotDateTimeOffset
  | KeyNotFound of string

val pp_decode_error : Format.formatter -> decode_error -> unit
(** Pretty printer for decode errors. *)

(** {1 Type-directed decoders}
    Exact variants return [Result]. *)

val exact_unit : Value.value -> (unit, decode_error) result
val exact_bool : Value.value -> (bool, decode_error) result
val exact_int : Value.value -> (int64, decode_error) result
val exact_int_as_int : Value.value -> (int, decode_error) result
val exact_float : Value.value -> (float, decode_error) result
val exact_text : Value.value -> (string, decode_error) result
val exact_bytes : Value.value -> (string, decode_error) result
val exact_list : (Value.value -> ('a, decode_error) result) -> Value.value -> ('a list, decode_error) result
val exact_map : Value.value -> (Value.value Value.StringMap.t, decode_error) result
val exact_node : Value.value -> (Value.node, decode_error) result
val exact_relationship : Value.value -> (Value.relationship, decode_error) result
val exact_unbound_relationship : Value.value -> (Value.urelationship, decode_error) result
val exact_path : Value.value -> (Value.path, decode_error) result
val exact_point2d : Value.value -> (Value.point2d, decode_error) result
val exact_point3d : Value.value -> (Value.point3d, decode_error) result
val exact_duration : Value.value -> (Value.duration, decode_error) result
val exact_date : Value.value -> (Value.date, decode_error) result
val exact_local_time : Value.value -> (Value.local_time, decode_error) result
val exact_time : Value.value -> (Value.time, decode_error) result
val exact_local_datetime : Value.value -> (Value.local_datetime, decode_error) result
val exact_datetime_zone_id : Value.value -> (Value.datetime_zone_id, decode_error) result
val exact_datetime_offset : Value.value -> (Value.datetime_offset, decode_error) result
val exact_value : Value.value -> (Value.value, decode_error) result

(** Maybe variants return [None] instead of [Error]. *)
val maybe_exact_unit : Value.value -> unit option
val maybe_exact_bool : Value.value -> bool option
val maybe_exact_int : Value.value -> int64 option
val maybe_exact_int_as_int : Value.value -> int option
val maybe_exact_float : Value.value -> float option
val maybe_exact_text : Value.value -> string option
val maybe_exact_bytes : Value.value -> string option
val maybe_exact_list : (Value.value -> ('a, decode_error) result) -> Value.value -> 'a list option
val maybe_exact_map : Value.value -> Value.value Value.StringMap.t option
val maybe_exact_node : Value.value -> Value.node option
val maybe_exact_relationship : Value.value -> Value.relationship option
val maybe_exact_unbound_relationship : Value.value -> Value.urelationship option
val maybe_exact_path : Value.value -> Value.path option
val maybe_exact_point2d : Value.value -> Value.point2d option
val maybe_exact_point3d : Value.value -> Value.point3d option
val maybe_exact_duration : Value.value -> Value.duration option
val maybe_exact_date : Value.value -> Value.date option
val maybe_exact_local_time : Value.value -> Value.local_time option
val maybe_exact_time : Value.value -> Value.time option
val maybe_exact_local_datetime : Value.value -> Value.local_datetime option
val maybe_exact_datetime_zone_id : Value.value -> Value.datetime_zone_id option
val maybe_exact_datetime_offset : Value.value -> Value.datetime_offset option
val maybe_exact_value : Value.value -> Value.value option

(** {1 Record field accessors}
    [at_*] variants look up a key then decode. *)

val at_unit : t -> string -> (unit, decode_error) result
val at_bool : t -> string -> (bool, decode_error) result
val at_int : t -> string -> (int64, decode_error) result
val at_int_as_int : t -> string -> (int, decode_error) result
val at_float : t -> string -> (float, decode_error) result
val at_text : t -> string -> (string, decode_error) result
val at_bytes : t -> string -> (string, decode_error) result
val at_list : (Value.value -> ('a, decode_error) result) -> t -> string -> ('a list, decode_error) result
val at_map : t -> string -> (Value.value Value.StringMap.t, decode_error) result
val at_node : t -> string -> (Value.node, decode_error) result
val at_relationship : t -> string -> (Value.relationship, decode_error) result
val at_unbound_relationship : t -> string -> (Value.urelationship, decode_error) result
val at_path : t -> string -> (Value.path, decode_error) result
val at_point2d : t -> string -> (Value.point2d, decode_error) result
val at_point3d : t -> string -> (Value.point3d, decode_error) result
val at_duration : t -> string -> (Value.duration, decode_error) result
val at_date : t -> string -> (Value.date, decode_error) result
val at_local_time : t -> string -> (Value.local_time, decode_error) result
val at_time : t -> string -> (Value.time, decode_error) result
val at_local_datetime : t -> string -> (Value.local_datetime, decode_error) result
val at_datetime_zone_id : t -> string -> (Value.datetime_zone_id, decode_error) result
val at_datetime_offset : t -> string -> (Value.datetime_offset, decode_error) result
val at_value : t -> string -> (Value.value, decode_error) result

(** [maybe_at_*] variants return [None] if key not found; type mismatch still
    returns an error. *)
val maybe_at_unit : t -> string -> (unit option, decode_error) result
val maybe_at_bool : t -> string -> (bool option, decode_error) result
val maybe_at_int : t -> string -> (int64 option, decode_error) result
val maybe_at_int_as_int : t -> string -> (int option, decode_error) result
val maybe_at_float : t -> string -> (float option, decode_error) result
val maybe_at_text : t -> string -> (string option, decode_error) result
val maybe_at_bytes : t -> string -> (string option, decode_error) result
val maybe_at_list : (Value.value -> ('a, decode_error) result) -> t -> string -> ('a list option, decode_error) result
val maybe_at_map : t -> string -> (Value.value Value.StringMap.t option, decode_error) result
val maybe_at_node : t -> string -> (Value.node option, decode_error) result
val maybe_at_relationship : t -> string -> (Value.relationship option, decode_error) result
val maybe_at_unbound_relationship : t -> string -> (Value.urelationship option, decode_error) result
val maybe_at_path : t -> string -> (Value.path option, decode_error) result
val maybe_at_point2d : t -> string -> (Value.point2d option, decode_error) result
val maybe_at_point3d : t -> string -> (Value.point3d option, decode_error) result
val maybe_at_duration : t -> string -> (Value.duration option, decode_error) result
val maybe_at_date : t -> string -> (Value.date option, decode_error) result
val maybe_at_local_time : t -> string -> (Value.local_time option, decode_error) result
val maybe_at_time : t -> string -> (Value.time option, decode_error) result
val maybe_at_local_datetime : t -> string -> (Value.local_datetime option, decode_error) result
val maybe_at_datetime_zone_id : t -> string -> (Value.datetime_zone_id option, decode_error) result
val maybe_at_datetime_offset : t -> string -> (Value.datetime_offset option, decode_error) result
val maybe_at_value : t -> string -> (Value.value option, decode_error) result

(** Helper constructors. *)
val empty : t
val of_list : (string * Value.value) list -> t
