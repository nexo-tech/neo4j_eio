(** Lens-based accessors for Neo4j values and records *)

(** A lens is fundamentally a getter function that may fail *)
type ('s, 'a) t = 's -> 'a option

(** {1 Construction} *)

let lens f = f

let pure x = fun _ -> Some x

let empty = fun _ -> None

(** {1 Operators} *)

let (^.) s l = l s

let (^?) s l = l s

let (^!) s l =
  match l s with
  | Some a -> a
  | None -> raise Not_found

(** {1 Composition} *)

let (>>>) l1 l2 = fun s ->
  match l1 s with
  | Some a -> l2 a
  | None -> None

let compose = (>>>)

(** {1 Value Prisms} *)

let exact_bool = function
  | Value.Bool b -> Some b
  | _ -> None

let exact_int = function
  | Value.Int i -> Some i
  | _ -> None

let exact_float = function
  | Value.Float f -> Some f
  | _ -> None

let exact_text = function
  | Value.Text t -> Some t
  | _ -> None

let exact_bytes = function
  | Value.Bytes b -> Some b
  | _ -> None

let exact_list = function
  | Value.List l -> Some l
  | _ -> None

let exact_map = function
  | Value.Map m -> Some m
  | _ -> None

let exact_node = function
  | Value.Node n -> Some n
  | _ -> None

let exact_relationship = function
  | Value.Relationship r -> Some r
  | _ -> None

let exact_unbound_relationship = function
  | Value.UnboundRelationship ur -> Some ur
  | _ -> None

let exact_path = function
  | Value.Path p -> Some p
  | _ -> None

let exact_point2d = function
  | Value.Point2D p -> Some p
  | _ -> None

let exact_point3d = function
  | Value.Point3D p -> Some p
  | _ -> None

let exact_duration = function
  | Value.Duration d -> Some d
  | _ -> None

let exact_date = function
  | Value.Date d -> Some d
  | _ -> None

let exact_local_time = function
  | Value.LocalTime t -> Some t
  | _ -> None

let exact_time = function
  | Value.Time t -> Some t
  | _ -> None

let exact_local_datetime = function
  | Value.LocalDateTime dt -> Some dt
  | _ -> None

let exact_datetime_zone_id = function
  | Value.DateTimeZoneId dt -> Some dt
  | _ -> None

let exact_datetime_offset = function
  | Value.DateTimeOffset dt -> Some dt
  | _ -> None

(** {1 Record Accessors} *)

let key k = fun record ->
  Value.StringMap.find_opt k record

let field_bool k = key k >>> exact_bool
let field_int k = key k >>> exact_int
let field_float k = key k >>> exact_float
let field_text k = key k >>> exact_text
let field_bytes k = key k >>> exact_bytes
let field_list k = key k >>> exact_list
let field_map k = key k >>> exact_map
let field_node k = key k >>> exact_node
let field_relationship k = key k >>> exact_relationship
let field_path k = key k >>> exact_path

(** {1 Node Accessors} *)

let node_prop name = fun (node : Value.node) ->
  Value.StringMap.find_opt name node.props

let node_id = fun (node : Value.node) -> Some node.node_id

let node_labels = fun (node : Value.node) -> Some node.labels

let node_prop_bool name = node_prop name >>> exact_bool
let node_prop_int name = node_prop name >>> exact_int
let node_prop_float name = node_prop name >>> exact_float
let node_prop_text name = node_prop name >>> exact_text

(** {1 Relationship Accessors} *)

let rel_prop name = fun (rel : Value.relationship) ->
  Value.StringMap.find_opt name rel.rel_props

let rel_id = fun (rel : Value.relationship) -> Some rel.rel_id

let rel_type = fun (rel : Value.relationship) -> Some rel.rel_type

let rel_start_id = fun (rel : Value.relationship) -> Some rel.start_node_id

let rel_end_id = fun (rel : Value.relationship) -> Some rel.end_node_id

(** {1 Combinators} *)

let with_default default l = fun s ->
  match l s with
  | Some a -> Some a
  | None -> Some default

let try_both l1 l2 = fun s ->
  match l1 s with
  | Some a -> Some a
  | None -> l2 s

let (<|>) = try_both

let map f l = fun s ->
  match l s with
  | Some a -> Some (f a)
  | None -> None

let bind f l = fun s ->
  match l s with
  | Some a -> f a s
  | None -> None
