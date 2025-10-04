module StringMap = Map.Make (String)

(* Temporal and spatial types from PackStream v2 / Neo4j 3.4+ *)
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

(* Core value type *)
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

let pp_point2d ppf (p : point2d) =
  Format.fprintf ppf "Point2D(srid=%Ld, x=%g, y=%g)" p.srid p.x p.y

let pp_point3d ppf (p : point3d) =
  Format.fprintf ppf "Point3D(srid=%Ld, x=%g, y=%g, z=%g)" p.srid p.x p.y p.z

let pp_duration ppf (d : duration) =
  Format.fprintf ppf "Duration(months=%Ld, days=%Ld, seconds=%Ld, nanoseconds=%Ld)"
    d.months d.days d.seconds d.nanoseconds

let pp_date ppf (d : date) =
  Format.fprintf ppf "Date(days=%Ld)" d.days_since_epoch

let pp_local_time ppf (t : local_time) =
  Format.fprintf ppf "LocalTime(nanos=%Ld)" t.nanoseconds_since_midnight

let pp_time ppf (t : time) =
  Format.fprintf ppf "Time(nanos=%Ld, tz_offset=%Ld)"
    t.nanoseconds_since_midnight t.timezone_offset_seconds

let pp_local_datetime ppf (dt : local_datetime) =
  Format.fprintf ppf "LocalDateTime(seconds=%Ld, nanos=%Ld)"
    dt.seconds_since_epoch dt.nanoseconds

let pp_datetime_zone_id ppf (dt : datetime_zone_id) =
  Format.fprintf ppf "DateTime(seconds=%Ld, nanos=%Ld, tz_id=%S)"
    dt.seconds_since_epoch dt.nanoseconds dt.timezone_id

let pp_datetime_offset ppf (dt : datetime_offset) =
  Format.fprintf ppf "DateTime(seconds=%Ld, nanos=%Ld, tz_offset=%Ld)"
    dt.seconds_since_epoch dt.nanoseconds dt.timezone_offset_seconds

let rec pp_value ppf = function
  | Null -> Format.fprintf ppf "null"
  | Bool b -> Format.fprintf ppf "%B" b
  | Int i -> Format.fprintf ppf "%Ld" i
  | Float f -> Format.fprintf ppf "%g" f
  | Text s -> Format.fprintf ppf "%S" s
  | Bytes b -> Format.fprintf ppf "Bytes(%d)" (String.length b)
  | List xs ->
      Format.fprintf ppf "[";
      List.iteri
        (fun i v -> if i > 0 then Format.fprintf ppf ",@ "; pp_value ppf v)
        xs;
      Format.fprintf ppf "]"
  | Map m ->
      let first = ref true in
      Format.fprintf ppf "{";
      StringMap.iter
        (fun k v ->
          if !first then first := false else Format.fprintf ppf ",@ ";
          Format.fprintf ppf "%S:@ %a" k pp_value v)
        m;
      Format.fprintf ppf "}"
  | Struct { signature; fields } ->
      Format.fprintf ppf "Struct(%d, [" signature;
      List.iteri (fun i v -> if i > 0 then Format.fprintf ppf ",@ "; pp_value ppf v) fields;
      Format.fprintf ppf "]"
  | Node n -> pp_node ppf n
  | Relationship r -> pp_relationship ppf r
  | UnboundRelationship ur -> pp_urelationship ppf ur
  | Path p -> pp_path ppf p
  | Point2D p -> pp_point2d ppf p
  | Point3D p -> pp_point3d ppf p
  | Duration d -> pp_duration ppf d
  | Date d -> pp_date ppf d
  | LocalTime t -> pp_local_time ppf t
  | Time t -> pp_time ppf t
  | LocalDateTime dt -> pp_local_datetime ppf dt
  | DateTimeZoneId dt -> pp_datetime_zone_id ppf dt
  | DateTimeOffset dt -> pp_datetime_offset ppf dt

and pp_node ppf { node_id; labels; props } =
  Format.fprintf ppf "Node(id=%Ld, labels=[" node_id;
  List.iteri (fun i l -> if i > 0 then Format.fprintf ppf ",@ "; Format.fprintf ppf "%S" l) labels;
  Format.fprintf ppf "], props={";
  let first = ref true in
  StringMap.iter (fun k v ->
    if !first then first := false else Format.fprintf ppf ",@ ";
    Format.fprintf ppf "%S:@ %a" k pp_value v) props;
  Format.fprintf ppf "})"

and pp_relationship ppf { rel_id; start_node_id; end_node_id; rel_type; rel_props } =
  Format.fprintf ppf "Relationship(id=%Ld, start=%Ld, end=%Ld, type=%S, props={"
    rel_id start_node_id end_node_id rel_type;
  let first = ref true in
  StringMap.iter (fun k v ->
    if !first then first := false else Format.fprintf ppf ",@ ";
    Format.fprintf ppf "%S:@ %a" k pp_value v) rel_props;
  Format.fprintf ppf "})"

and pp_urelationship ppf { urel_id; urel_type; urel_props } =
  Format.fprintf ppf "UnboundRelationship(id=%Ld, type=%S, props={" urel_id urel_type;
  let first = ref true in
  StringMap.iter (fun k v ->
    if !first then first := false else Format.fprintf ppf ",@ ";
    Format.fprintf ppf "%S:@ %a" k pp_value v) urel_props;
  Format.fprintf ppf "})"

and pp_path ppf { path_nodes; path_rels; path_seq } =
  Format.fprintf ppf "Path(nodes=[";
  List.iteri (fun i n -> if i > 0 then Format.fprintf ppf ",@ "; pp_node ppf n) path_nodes;
  Format.fprintf ppf "], rels=[";
  List.iteri (fun i r -> if i > 0 then Format.fprintf ppf ",@ "; pp_urelationship ppf r) path_rels;
  Format.fprintf ppf "], seq=[";
  List.iteri (fun i s -> if i > 0 then Format.fprintf ppf ",@ "; Format.fprintf ppf "%d" s) path_seq;
  Format.fprintf ppf "])"

(* Helper constructors for building values *)
let null = Null
let bool b = Bool b
let int i = Int i
let int32 i = Int (Int64.of_int32 i)
let int_of_int i = Int (Int64.of_int i)
let float f = Float f
let text s = Text s
let bytes b = Bytes b
let list l = List l
let map m = Map m
