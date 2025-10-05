module StringMap : Map.S with type key = string
(** String-keyed map used for value maps and records. *)

(** Temporal and spatial types from PackStream v2 / Neo4j 3.4+. *)
type point2d = { srid : int64; x : float; y : float }
type point3d = { srid : int64; x : float; y : float; z : float }

type duration = {
  months : int64;
  days : int64;
  seconds : int64;
  nanoseconds : int64;
}

type date = { days_since_epoch : int64 }
type local_time = { nanoseconds_since_midnight : int64 }
type time = { nanoseconds_since_midnight : int64; timezone_offset_seconds : int64 }
type local_datetime = { seconds_since_epoch : int64; nanoseconds : int64 }
type datetime_zone_id = { seconds_since_epoch : int64; nanoseconds : int64; timezone_id : string }
type datetime_offset = { seconds_since_epoch : int64; nanoseconds : int64; timezone_offset_seconds : int64 }

(** Core value type mirrored from Neo4j PackStream. *)
type value =
  | Null
  | Bool of bool
  | Int of int64
  | Float of float
  | Text of string
  | Bytes of string
  | List of value list
  | Map of value StringMap.t
  | Struct of structure
  | Node of node
  | Relationship of relationship
  | UnboundRelationship of urelationship
  | Path of path
  | Point2D of point2d
  | Point3D of point3d
  | Duration of duration
  | Date of date
  | LocalTime of local_time
  | Time of time
  | LocalDateTime of local_datetime
  | DateTimeZoneId of datetime_zone_id
  | DateTimeOffset of datetime_offset

and structure = { signature : int; fields : value list }

and node = { node_id : int64; labels : string list; props : value StringMap.t }

and relationship = {
  rel_id : int64;
  start_node_id : int64;
  end_node_id : int64;
  rel_type : string;
  rel_props : value StringMap.t;
}

and urelationship = { urel_id : int64; urel_type : string; urel_props : value StringMap.t }

and path = { path_nodes : node list; path_rels : urelationship list; path_seq : int list }

(** Record type - a row returned from a query with named fields. *)
type record = value StringMap.t

(** Pretty printers for debugging. *)
val pp_point2d : Format.formatter -> point2d -> unit
val pp_point3d : Format.formatter -> point3d -> unit
val pp_duration : Format.formatter -> duration -> unit
val pp_date : Format.formatter -> date -> unit
val pp_local_time : Format.formatter -> local_time -> unit
val pp_time : Format.formatter -> time -> unit
val pp_local_datetime : Format.formatter -> local_datetime -> unit
val pp_datetime_zone_id : Format.formatter -> datetime_zone_id -> unit
val pp_datetime_offset : Format.formatter -> datetime_offset -> unit
val pp_node : Format.formatter -> node -> unit
val pp_relationship : Format.formatter -> relationship -> unit
val pp_urelationship : Format.formatter -> urelationship -> unit
val pp_path : Format.formatter -> path -> unit
val pp_value : Format.formatter -> value -> unit

(** Helper constructors for building values. *)
val null : value
val bool : bool -> value
val int : int64 -> value
val int32 : int32 -> value
val int_of_int : int -> value
val float : float -> value
val text : string -> value
val bytes : string -> value
val list : value list -> value
val map : value StringMap.t -> value

(** Record helper - extract a value by field name. *)
val at : record -> string -> value option
