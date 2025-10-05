(** Lens-based accessors for Neo4j values and records.

    This module provides functional getters (optics) for accessing
    and extracting values from Neo4j records, values, and nodes.

    Inspired by Haskell's lens library and the hasbolt implementation,
    this provides a composable way to access nested data structures.

    {[
      open Lens

      (* Simple field access *)
      let name = record ^. key "person" >>> key "name" >>> text

      (* Optional field access *)
      let email = record ^? key "person" >>> key "email" >>> text

      (* Node property access *)
      let age = node_value ^. node_prop "age" >>> int
    ]}
*)

(** {1 Core Types} *)

(** A getter that extracts values of type ['a] from ['s].
    This is a simplified version suitable for read-only access. *)
type ('s, 'a) t = 's -> 'a option

(** {1 Construction} *)

(** [lens get] creates a getter from a function that extracts ['a] from ['s]. *)
val lens : ('s -> 'a option) -> ('s, 'a) t

(** [pure x] creates a lens that always returns [Some x]. *)
val pure : 'a -> ('s, 'a) t

(** [empty] is a lens that always returns [None]. *)
val empty : ('s, 'a) t

(** {1 Operators} *)

(** [s ^. l] views the value through lens [l], returning [None] if not found. *)
val (^.) : 's -> ('s, 'a) t -> 'a option

(** [s ^? l] is an alias for [^.] - preview the value through lens. *)
val (^?) : 's -> ('s, 'a) t -> 'a option

(** [s ^! l] views the value, raising [Not_found] if missing. *)
val (^!) : 's -> ('s, 'a) t -> 'a

(** {1 Composition} *)

(** [l1 >>> l2] composes two lenses, first applying [l1] then [l2]. *)
val (>>>) : ('s, 'a) t -> ('a, 'b) t -> ('s, 'b) t

(** [compose l1 l2] is equivalent to [l1 >>> l2]. *)
val compose : ('s, 'a) t -> ('a, 'b) t -> ('s, 'b) t

(** {1 Value Prisms}

    These prisms extract specific types from {!Value.value}.
    Returns [None] if the value is not of the expected type.
*)

(** Extract a [bool] from a value. *)
val exact_bool : (Value.value, bool) t

(** Extract an [int64] from a value. *)
val exact_int : (Value.value, int64) t

(** Extract a [float] from a value. *)
val exact_float : (Value.value, float) t

(** Extract a [string] from a value. *)
val exact_text : (Value.value, string) t

(** Extract bytes from a value. *)
val exact_bytes : (Value.value, string) t

(** Extract a list from a value. *)
val exact_list : (Value.value, Value.value list) t

(** Extract a map from a value. *)
val exact_map : (Value.value, Value.value Value.StringMap.t) t

(** Extract a node from a value. *)
val exact_node : (Value.value, Value.node) t

(** Extract a relationship from a value. *)
val exact_relationship : (Value.value, Value.relationship) t

(** Extract an unbound relationship from a value. *)
val exact_unbound_relationship : (Value.value, Value.urelationship) t

(** Extract a path from a value. *)
val exact_path : (Value.value, Value.path) t

(** Extract a 2D point from a value. *)
val exact_point2d : (Value.value, Value.point2d) t

(** Extract a 3D point from a value. *)
val exact_point3d : (Value.value, Value.point3d) t

(** Extract a duration from a value. *)
val exact_duration : (Value.value, Value.duration) t

(** Extract a date from a value. *)
val exact_date : (Value.value, Value.date) t

(** Extract a local time from a value. *)
val exact_local_time : (Value.value, Value.local_time) t

(** Extract a time from a value. *)
val exact_time : (Value.value, Value.time) t

(** Extract a local datetime from a value. *)
val exact_local_datetime : (Value.value, Value.local_datetime) t

(** Extract a datetime with zone ID from a value. *)
val exact_datetime_zone_id : (Value.value, Value.datetime_zone_id) t

(** Extract a datetime with offset from a value. *)
val exact_datetime_offset : (Value.value, Value.datetime_offset) t

(** {1 Record Accessors} *)

(** [key name] accesses a field in a record by name.
    Returns [None] if the key is not found. *)
val key : string -> (Record.t, Value.value) t

(** [field name] accesses a field and extracts it as a specific type.
    This is a convenience function combining [key] and type extraction.

    For example:
    {[
      let name = record ^. field_text "name"
      (* equivalent to: record ^. key "name" >>> exact_text *)
    ]}
*)

(** Extract a boolean field from a record. *)
val field_bool : string -> (Record.t, bool) t

(** Extract an integer field from a record. *)
val field_int : string -> (Record.t, int64) t

(** Extract a float field from a record. *)
val field_float : string -> (Record.t, float) t

(** Extract a text field from a record. *)
val field_text : string -> (Record.t, string) t

(** Extract a bytes field from a record. *)
val field_bytes : string -> (Record.t, string) t

(** Extract a list field from a record. *)
val field_list : string -> (Record.t, Value.value list) t

(** Extract a map field from a record. *)
val field_map : string -> (Record.t, Value.value Value.StringMap.t) t

(** Extract a node field from a record. *)
val field_node : string -> (Record.t, Value.node) t

(** Extract a relationship field from a record. *)
val field_relationship : string -> (Record.t, Value.relationship) t

(** Extract a path field from a record. *)
val field_path : string -> (Record.t, Value.path) t

(** {1 Node Accessors} *)

(** [node_prop name] accesses a property of a node by name. *)
val node_prop : string -> (Value.node, Value.value) t

(** [node_id] extracts the node ID. *)
val node_id : (Value.node, int64) t

(** [node_labels] extracts the node labels. *)
val node_labels : (Value.node, string list) t

(** Extract a boolean property from a node. *)
val node_prop_bool : string -> (Value.node, bool) t

(** Extract an integer property from a node. *)
val node_prop_int : string -> (Value.node, int64) t

(** Extract a float property from a node. *)
val node_prop_float : string -> (Value.node, float) t

(** Extract a text property from a node. *)
val node_prop_text : string -> (Value.node, string) t

(** {1 Relationship Accessors} *)

(** [rel_prop name] accesses a property of a relationship by name. *)
val rel_prop : string -> (Value.relationship, Value.value) t

(** [rel_id] extracts the relationship ID. *)
val rel_id : (Value.relationship, int64) t

(** [rel_type] extracts the relationship type. *)
val rel_type : (Value.relationship, string) t

(** [rel_start_id] extracts the start node ID. *)
val rel_start_id : (Value.relationship, int64) t

(** [rel_end_id] extracts the end node ID. *)
val rel_end_id : (Value.relationship, int64) t

(** {1 Combinators} *)

(** [with_default default lens] returns [default] if the lens returns [None]. *)
val with_default : 'a -> ('s, 'a) t -> ('s, 'a) t

(** [try_both l1 l2] tries [l1] first, then [l2] if [l1] returns [None]. *)
val try_both : ('s, 'a) t -> ('s, 'a) t -> ('s, 'a) t

(** [(<|>)] is an infix alias for [try_both]. *)
val (<|>) : ('s, 'a) t -> ('s, 'a) t -> ('s, 'a) t

(** [map f lens] transforms the result of a lens with function [f]. *)
val map : ('a -> 'b) -> ('s, 'a) t -> ('s, 'b) t

(** [bind f lens] chains lenses monadically. *)
val bind : ('a -> ('s, 'b) t) -> ('s, 'a) t -> ('s, 'b) t
