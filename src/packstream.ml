(* PackStream encoding markers *)
let marker_null = 0xC0
let marker_true = 0xC3
let marker_false = 0xC2
let marker_int8 = 0xC8
let marker_int16 = 0xC9
let marker_int32 = 0xCA
let marker_int64 = 0xCB
let marker_float64 = 0xC1
let marker_bytes8 = 0xCC
let marker_bytes16 = 0xCD
let marker_bytes32 = 0xCE
let marker_string8 = 0xD0
let marker_string16 = 0xD1
let marker_string32 = 0xD2
let marker_list8 = 0xD4
let marker_list16 = 0xD5
let marker_list32 = 0xD6
let marker_map8 = 0xD8
let marker_map16 = 0xD9
let marker_map32 = 0xDA
let marker_struct8 = 0xDC
let marker_struct16 = 0xDD

(* Structure signatures for graph types *)
let sig_node = 0x4E (* 'N' *)
let sig_relationship = 0x52 (* 'R' *)
let sig_unbound_relationship = 0x72 (* 'r' *)
let sig_path = 0x50 (* 'P' *)

(* Structure signatures for temporal/spatial types (PackStream v2) *)
let sig_date = 0x44 (* 'D' *)
let sig_time = 0x54 (* 'T' *)
let sig_local_time = 0x74 (* 't' *)
let sig_local_datetime = 0x64 (* 'd' *)
let sig_datetime_zone_id = 0x66 (* 'f' *)
let sig_datetime_offset = 0x46 (* 'F' *)
let sig_duration = 0x45 (* 'E' *)
let sig_point2d = 0x58 (* 'X' *)
let sig_point3d = 0x59 (* 'Y' *)

let be_uint16 n =
  let cs = Cstruct.create 2 in
  Cstruct.BE.set_uint16 cs 0 n;
  cs

let be_uint32 n =
  let cs = Cstruct.create 4 in
  Cstruct.BE.set_uint32 cs 0 n;
  cs

let chunked_frames ~max_chunk payload =
  let len = Cstruct.length payload in
  let rec loop off acc =
    if off >= len then List.rev (be_uint16 0 :: acc)
    else
      let n = Int.min max_chunk (len - off) in
      let chunk = Cstruct.sub payload off n in
      let frame = be_uint16 n in
      loop (off + n) (chunk :: frame :: acc)
  in
  loop 0 []

(* Encoding functions *)
let encode_int64 (n : int64) : string =
  if n >= -16L && n <= 127L then
    (* Tiny int: -16 to 127 fits in one byte *)
    String.make 1 (Char.chr (Int64.to_int n land 0xFF))
  else if n >= -128L && n < -16L then
    (* INT_8 *)
    let buf = Bytes.create 2 in
    Bytes.set buf 0 (Char.chr marker_int8);
    Bytes.set buf 1 (Char.chr (Int64.to_int n land 0xFF));
    Bytes.to_string buf
  else if n >= -32768L && n <= 32767L then
    (* INT_16 *)
    let buf = Bytes.create 3 in
    Bytes.set buf 0 (Char.chr marker_int16);
    Bytes.set_int16_be buf 1 (Int64.to_int n);
    Bytes.to_string buf
  else if n >= -2147483648L && n <= 2147483647L then
    (* INT_32 *)
    let buf = Bytes.create 5 in
    Bytes.set buf 0 (Char.chr marker_int32);
    Bytes.set_int32_be buf 1 (Int64.to_int32 n);
    Bytes.to_string buf
  else
    (* INT_64 *)
    let buf = Bytes.create 9 in
    Bytes.set buf 0 (Char.chr marker_int64);
    Bytes.set_int64_be buf 1 n;
    Bytes.to_string buf

let encode_float (f : float) : string =
  let buf = Bytes.create 9 in
  Bytes.set buf 0 (Char.chr marker_float64);
  Bytes.set_int64_be buf 1 (Int64.bits_of_float f);
  Bytes.to_string buf

let encode_string (s : string) : string =
  let len = String.length s in
  if len < 16 then
    (* Tiny string: 0x80 + size *)
    String.make 1 (Char.chr (0x80 + len)) ^ s
  else if len <= 255 then
    (* STRING_8 *)
    let buf = Bytes.create (2 + len) in
    Bytes.set buf 0 (Char.chr marker_string8);
    Bytes.set_uint8 buf 1 len;
    Bytes.blit_string s 0 buf 2 len;
    Bytes.to_string buf
  else if len <= 65535 then
    (* STRING_16 *)
    let buf = Bytes.create (3 + len) in
    Bytes.set buf 0 (Char.chr marker_string16);
    Bytes.set_uint16_be buf 1 len;
    Bytes.blit_string s 0 buf 3 len;
    Bytes.to_string buf
  else
    (* STRING_32 *)
    let buf = Bytes.create (5 + len) in
    Bytes.set buf 0 (Char.chr marker_string32);
    Bytes.set_int32_be buf 1 (Int32.of_int len);
    Bytes.blit_string s 0 buf 5 len;
    Bytes.to_string buf

let encode_bytes (s : string) : string =
  let len = String.length s in
  if len <= 255 then
    (* BYTES_8 *)
    let buf = Bytes.create (2 + len) in
    Bytes.set buf 0 (Char.chr marker_bytes8);
    Bytes.set_uint8 buf 1 len;
    Bytes.blit_string s 0 buf 2 len;
    Bytes.to_string buf
  else if len <= 65535 then
    (* BYTES_16 *)
    let buf = Bytes.create (3 + len) in
    Bytes.set buf 0 (Char.chr marker_bytes16);
    Bytes.set_uint16_be buf 1 len;
    Bytes.blit_string s 0 buf 3 len;
    Bytes.to_string buf
  else
    (* BYTES_32 *)
    let buf = Bytes.create (5 + len) in
    Bytes.set buf 0 (Char.chr marker_bytes32);
    Bytes.set_int32_be buf 1 (Int32.of_int len);
    Bytes.blit_string s 0 buf 5 len;
    Bytes.to_string buf

let rec encode_value (v : Value.value) : string =
  match v with
  | Value.Null -> String.make 1 (Char.chr marker_null)
  | Value.Bool true -> String.make 1 (Char.chr marker_true)
  | Value.Bool false -> String.make 1 (Char.chr marker_false)
  | Value.Int n -> encode_int64 n
  | Value.Float f -> encode_float f
  | Value.Text s -> encode_string s
  | Value.Bytes b -> encode_bytes b
  | Value.List items -> encode_list items
  | Value.Map m -> encode_map m
  | Value.Struct s -> encode_struct s.signature s.fields
  | Value.Node n -> encode_node n
  | Value.Relationship r -> encode_relationship r
  | Value.UnboundRelationship ur -> encode_unbound_relationship ur
  | Value.Path p -> encode_path p
  | Value.Point2D p -> encode_point2d p
  | Value.Point3D p -> encode_point3d p
  | Value.Duration d -> encode_duration d
  | Value.Date d -> encode_date d
  | Value.LocalTime t -> encode_local_time t
  | Value.Time t -> encode_time t
  | Value.LocalDateTime dt -> encode_local_datetime dt
  | Value.DateTimeZoneId dt -> encode_datetime_zone_id dt
  | Value.DateTimeOffset dt -> encode_datetime_offset dt

and encode_list (items : Value.value list) : string =
  let len = List.length items in
  let header =
    if len < 16 then
      String.make 1 (Char.chr (0x90 + len)) (* Tiny list *)
    else if len <= 255 then
      let buf = Bytes.create 2 in
      Bytes.set buf 0 (Char.chr marker_list8);
      Bytes.set_uint8 buf 1 len;
      Bytes.to_string buf
    else if len <= 65535 then
      let buf = Bytes.create 3 in
      Bytes.set buf 0 (Char.chr marker_list16);
      Bytes.set_uint16_be buf 1 len;
      Bytes.to_string buf
    else
      let buf = Bytes.create 5 in
      Bytes.set buf 0 (Char.chr marker_list32);
      Bytes.set_int32_be buf 1 (Int32.of_int len);
      Bytes.to_string buf
  in
  header ^ String.concat "" (List.map encode_value items)

and encode_map (m : Value.value Value.StringMap.t) : string =
  let len = Value.StringMap.cardinal m in
  let header =
    if len < 16 then
      String.make 1 (Char.chr (0xA0 + len)) (* Tiny map *)
    else if len <= 255 then
      let buf = Bytes.create 2 in
      Bytes.set buf 0 (Char.chr marker_map8);
      Bytes.set_uint8 buf 1 len;
      Bytes.to_string buf
    else if len <= 65535 then
      let buf = Bytes.create 3 in
      Bytes.set buf 0 (Char.chr marker_map16);
      Bytes.set_uint16_be buf 1 len;
      Bytes.to_string buf
    else
      let buf = Bytes.create 5 in
      Bytes.set buf 0 (Char.chr marker_map32);
      Bytes.set_int32_be buf 1 (Int32.of_int len);
      Bytes.to_string buf
  in
  let entries = Value.StringMap.fold (fun k v acc ->
    acc ^ encode_string k ^ encode_value v
  ) m "" in
  header ^ entries

and encode_struct (signature : int) (fields : Value.value list) : string =
  let len = List.length fields in
  let header =
    if len < 16 then
      let buf = Bytes.create 2 in
      Bytes.set buf 0 (Char.chr (0xB0 + len)); (* Tiny struct *)
      Bytes.set buf 1 (Char.chr signature);
      Bytes.to_string buf
    else if len <= 255 then
      let buf = Bytes.create 3 in
      Bytes.set buf 0 (Char.chr marker_struct8);
      Bytes.set_uint8 buf 1 len;
      Bytes.set buf 2 (Char.chr signature);
      Bytes.to_string buf
    else
      let buf = Bytes.create 4 in
      Bytes.set buf 0 (Char.chr marker_struct16);
      Bytes.set_uint16_be buf 1 len;
      Bytes.set buf 3 (Char.chr signature);
      Bytes.to_string buf
  in
  header ^ String.concat "" (List.map encode_value fields)

and encode_node (n : Value.node) : string =
  let fields = [
    Value.Int n.node_id;
    Value.List (List.map (fun l -> Value.Text l) n.labels);
    Value.Map n.props
  ] in
  encode_struct sig_node fields

and encode_relationship (r : Value.relationship) : string =
  let fields = [
    Value.Int r.rel_id;
    Value.Int r.start_node_id;
    Value.Int r.end_node_id;
    Value.Text r.rel_type;
    Value.Map r.rel_props
  ] in
  encode_struct sig_relationship fields

and encode_unbound_relationship (ur : Value.urelationship) : string =
  let fields = [
    Value.Int ur.urel_id;
    Value.Text ur.urel_type;
    Value.Map ur.urel_props
  ] in
  encode_struct sig_unbound_relationship fields

and encode_path (p : Value.path) : string =
  let fields = [
    Value.List (List.map (fun n -> Value.Node n) p.path_nodes);
    Value.List (List.map (fun r -> Value.UnboundRelationship r) p.path_rels);
    Value.List (List.map (fun i -> Value.Int (Int64.of_int i)) p.path_seq)
  ] in
  encode_struct sig_path fields

and encode_point2d (p : Value.point2d) : string =
  let fields = [
    Value.Int p.srid;
    Value.Float p.x;
    Value.Float p.y
  ] in
  encode_struct sig_point2d fields

and encode_point3d (p : Value.point3d) : string =
  let fields = [
    Value.Int p.srid;
    Value.Float p.x;
    Value.Float p.y;
    Value.Float p.z
  ] in
  encode_struct sig_point3d fields

and encode_duration (d : Value.duration) : string =
  let fields = [
    Value.Int d.months;
    Value.Int d.days;
    Value.Int d.seconds;
    Value.Int d.nanoseconds
  ] in
  encode_struct sig_duration fields

and encode_date (d : Value.date) : string =
  let fields = [ Value.Int d.days_since_epoch ] in
  encode_struct sig_date fields

and encode_local_time (t : Value.local_time) : string =
  let fields = [ Value.Int t.nanoseconds_since_midnight ] in
  encode_struct sig_local_time fields

and encode_time (t : Value.time) : string =
  let fields = [
    Value.Int t.nanoseconds_since_midnight;
    Value.Int t.timezone_offset_seconds
  ] in
  encode_struct sig_time fields

and encode_local_datetime (dt : Value.local_datetime) : string =
  let fields = [
    Value.Int dt.seconds_since_epoch;
    Value.Int dt.nanoseconds
  ] in
  encode_struct sig_local_datetime fields

and encode_datetime_zone_id (dt : Value.datetime_zone_id) : string =
  let fields = [
    Value.Int dt.seconds_since_epoch;
    Value.Int dt.nanoseconds;
    Value.Text dt.timezone_id
  ] in
  encode_struct sig_datetime_zone_id fields

and encode_datetime_offset (dt : Value.datetime_offset) : string =
  let fields = [
    Value.Int dt.seconds_since_epoch;
    Value.Int dt.nanoseconds;
    Value.Int dt.timezone_offset_seconds
  ] in
  encode_struct sig_datetime_offset fields

(* PackStream decoding using Angstrom *)
open Angstrom

let decode_error msg = fail msg

let parse_uint8 = any_char >>| Char.code
let parse_uint16 = BE.any_uint16
let parse_int16 = BE.any_int16
let parse_int32 = BE.any_int32
let parse_int64 = BE.any_int64
let parse_float64 =
  parse_int64 >>| Int64.float_of_bits

let rec decode_value () =
  parse_uint8 >>= fun marker ->
  match marker with
  | 0xC0 -> return Value.Null
  | 0xC3 -> return (Value.Bool true)
  | 0xC2 -> return (Value.Bool false)
  | 0xC8 -> (* INT_8 *)
      any_char >>| fun c -> Value.Int (Int64.of_int (Char.code c))
  | 0xC9 -> (* INT_16 *)
      parse_int16 >>| fun n -> Value.Int (Int64.of_int n)
  | 0xCA -> (* INT_32 *)
      parse_int32 >>| fun n -> Value.Int (Int64.of_int32 n)
  | 0xCB -> (* INT_64 *)
      parse_int64 >>| fun n -> Value.Int n
  | 0xC1 -> (* FLOAT_64 *)
      parse_float64 >>| fun f -> Value.Float f
  | 0xCC -> (* BYTES_8 *)
      parse_uint8 >>= fun len ->
      take len >>| fun s -> Value.Bytes s
  | 0xCD -> (* BYTES_16 *)
      parse_uint16 >>= fun len ->
      take len >>| fun s -> Value.Bytes s
  | 0xCE -> (* BYTES_32 *)
      parse_int32 >>= fun len32 ->
      let len = Int32.to_int len32 in
      take len >>| fun s -> Value.Bytes s
  | 0xD0 -> (* STRING_8 *)
      parse_uint8 >>= fun len ->
      take len >>| fun s -> Value.Text s
  | 0xD1 -> (* STRING_16 *)
      parse_uint16 >>= fun len ->
      take len >>| fun s -> Value.Text s
  | 0xD2 -> (* STRING_32 *)
      parse_int32 >>= fun len32 ->
      let len = Int32.to_int len32 in
      take len >>| fun s -> Value.Text s
  | 0xD4 -> (* LIST_8 *)
      parse_uint8 >>= decode_list
  | 0xD5 -> (* LIST_16 *)
      parse_uint16 >>= decode_list
  | 0xD6 -> (* LIST_32 *)
      parse_int32 >>= fun len32 ->
      decode_list (Int32.to_int len32)
  | 0xD8 -> (* MAP_8 *)
      parse_uint8 >>= decode_map
  | 0xD9 -> (* MAP_16 *)
      parse_uint16 >>= decode_map
  | 0xDA -> (* MAP_32 *)
      parse_int32 >>= fun len32 ->
      decode_map (Int32.to_int len32)
  | 0xDC -> (* STRUCT_8 *)
      parse_uint8 >>= fun len ->
      parse_uint8 >>= fun sig_ ->
      decode_struct sig_ len
  | 0xDD -> (* STRUCT_16 *)
      parse_uint16 >>= fun len ->
      parse_uint8 >>= fun sig_ ->
      decode_struct sig_ len
  | m when m >= 0xF0 && m <= 0xFF -> (* Tiny negative int *)
      let n = m - 256 in
      return (Value.Int (Int64.of_int n))
  | m when m >= 0x00 && m <= 0x7F -> (* Tiny positive int *)
      return (Value.Int (Int64.of_int m))
  | m when m >= 0x80 && m <= 0x8F -> (* Tiny string *)
      let len = m - 0x80 in
      take len >>| fun s -> Value.Text s
  | m when m >= 0x90 && m <= 0x9F -> (* Tiny list *)
      let len = m - 0x90 in
      decode_list len
  | m when m >= 0xA0 && m <= 0xAF -> (* Tiny map *)
      let len = m - 0xA0 in
      decode_map len
  | m when m >= 0xB0 && m <= 0xBF -> (* Tiny struct *)
      let len = m - 0xB0 in
      parse_uint8 >>= fun sig_ ->
      decode_struct sig_ len
  | _ -> decode_error (Printf.sprintf "Unknown marker: 0x%02x" marker)

and decode_list len =
  count len (decode_value ()) >>| fun items -> Value.List items

and decode_map len =
  count len (
    decode_value () >>= fun k ->
    decode_value () >>= fun v ->
    match k with
    | Value.Text key -> return (key, v)
    | _ -> decode_error "Map key must be a string"
  ) >>| fun pairs ->
  Value.Map (Value.StringMap.of_seq (List.to_seq pairs))

and decode_struct sig_ len =
  count len (decode_value ()) >>= fun fields ->
  match sig_ with
  | 0x4E -> decode_node fields
  | 0x52 -> decode_relationship fields
  | 0x72 -> decode_unbound_relationship fields
  | 0x50 -> decode_path fields
  | 0x44 -> decode_date fields
  | 0x54 -> decode_time fields
  | 0x74 -> decode_local_time fields
  | 0x64 -> decode_local_datetime fields
  | 0x66 -> decode_datetime_zone_id fields  (* 'f' - Bolt 4 *)
  | 0x69 -> decode_datetime_zone_id fields  (* 'i' - Bolt 5+ *)
  | 0x46 -> decode_datetime_offset fields   (* 'F' - Bolt 4 *)
  | 0x49 -> decode_datetime_offset fields   (* 'I' - Bolt 5+ *)
  | 0x45 -> decode_duration fields
  | 0x58 -> decode_point2d fields
  | 0x59 -> decode_point3d fields
  | _ -> return (Value.Struct { signature = sig_; fields })

and decode_node fields =
  match fields with
  (* Bolt 5+ format: element_id, node_id, labels, props *)
  | [Value.Text _element_id; Value.Int node_id; Value.List labels; Value.Map props] ->
      let label_strs = List.filter_map (function
        | Value.Text s -> Some s
        | _ -> None
      ) labels in
      return (Value.Node { node_id; labels = label_strs; props })
  (* Bolt 5+ alternative format: node_id, labels, props, element_id *)
  | [Value.Int node_id; Value.List labels; Value.Map props; Value.Text _element_id] ->
      let label_strs = List.filter_map (function
        | Value.Text s -> Some s
        | _ -> None
      ) labels in
      return (Value.Node { node_id; labels = label_strs; props })
  (* Bolt 4 and earlier: node_id, labels, props *)
  | [Value.Int node_id; Value.List labels; Value.Map props] ->
      let label_strs = List.filter_map (function
        | Value.Text s -> Some s
        | _ -> None
      ) labels in
      return (Value.Node { node_id; labels = label_strs; props })
  | _ ->
      let types = List.map (function
        | Value.Text _ -> "Text"
        | Value.Int _ -> "Int"
        | Value.List _ -> "List"
        | Value.Map _ -> "Map"
        | _ -> "Other"
      ) fields in
      decode_error (Printf.sprintf "Invalid node structure: got [%s] with %d fields"
        (String.concat "; " types) (List.length fields))

and decode_relationship fields =
  match fields with
  (* Bolt 5+ format (actual): rel_id, start_node_id, end_node_id, type, props, element_id, start_element_id, end_element_id *)
  | [Value.Int rel_id; Value.Int start_node_id; Value.Int end_node_id; Value.Text rel_type; Value.Map rel_props;
     Value.Text _element_id; Value.Text _start_element_id; Value.Text _end_element_id] ->
      return (Value.Relationship { rel_id; start_node_id; end_node_id; rel_type; rel_props })
  (* Bolt 4 and earlier: rel_id, start_node_id, end_node_id, type, props *)
  | [Value.Int rel_id; Value.Int start_node_id; Value.Int end_node_id; Value.Text rel_type; Value.Map rel_props] ->
      return (Value.Relationship { rel_id; start_node_id; end_node_id; rel_type; rel_props })
  | _ ->
      let types = List.map (function
        | Value.Text _ -> "Text"
        | Value.Int _ -> "Int"
        | Value.Map _ -> "Map"
        | Value.Bool _ -> "Bool"
        | Value.Float _ -> "Float"
        | Value.List _ -> "List"
        | _ -> "Other"
      ) fields in
      decode_error (Printf.sprintf "Invalid relationship structure: got [%s] with %d fields"
        (String.concat "; " types) (List.length fields))

and decode_unbound_relationship fields =
  match fields with
  (* Bolt 5+ format (actual): rel_id, type, props, element_id *)
  | [Value.Int urel_id; Value.Text urel_type; Value.Map urel_props; Value.Text _element_id] ->
      return (Value.UnboundRelationship { urel_id; urel_type; urel_props })
  (* Bolt 4 and earlier: rel_id, type, props *)
  | [Value.Int urel_id; Value.Text urel_type; Value.Map urel_props] ->
      return (Value.UnboundRelationship { urel_id; urel_type; urel_props })
  | _ ->
      let types = List.map (function
        | Value.Text _ -> "Text"
        | Value.Int _ -> "Int"
        | Value.Map _ -> "Map"
        | Value.Bool _ -> "Bool"
        | Value.Float _ -> "Float"
        | Value.List _ -> "List"
        | _ -> "Other"
      ) fields in
      decode_error (Printf.sprintf "Invalid unbound relationship structure: got [%s] with %d fields"
        (String.concat "; " types) (List.length fields))

and decode_path fields =
  match fields with
  | [Value.List nodes; Value.List rels; Value.List seq] ->
      let path_nodes = List.filter_map (function
        | Value.Node n -> Some n
        | _ -> None
      ) nodes in
      let path_rels = List.filter_map (function
        | Value.UnboundRelationship r -> Some r
        | _ -> None
      ) rels in
      let path_seq = List.filter_map (function
        | Value.Int i -> Some (Int64.to_int i)
        | _ -> None
      ) seq in
      return (Value.Path { path_nodes; path_rels; path_seq })
  | _ -> decode_error "Invalid path structure"

and decode_point2d fields =
  match fields with
  | [Value.Int srid; Value.Float x; Value.Float y] ->
      return (Value.Point2D { srid; x; y })
  | _ -> decode_error "Invalid Point2D structure"

and decode_point3d fields =
  match fields with
  | [Value.Int srid; Value.Float x; Value.Float y; Value.Float z] ->
      return (Value.Point3D { srid; x; y; z })
  | _ -> decode_error "Invalid Point3D structure"

and decode_duration fields =
  match fields with
  | [Value.Int months; Value.Int days; Value.Int seconds; Value.Int nanoseconds] ->
      return (Value.Duration { months; days; seconds; nanoseconds })
  | _ -> decode_error "Invalid duration structure"

and decode_date fields =
  match fields with
  | [Value.Int days_since_epoch] ->
      return (Value.Date { days_since_epoch })
  | _ -> decode_error "Invalid date structure"

and decode_local_time fields =
  match fields with
  | [Value.Int nanoseconds_since_midnight] ->
      return (Value.LocalTime { nanoseconds_since_midnight })
  | _ -> decode_error "Invalid local time structure"

and decode_time fields =
  match fields with
  | [Value.Int nanoseconds_since_midnight; Value.Int timezone_offset_seconds] ->
      return (Value.Time { nanoseconds_since_midnight; timezone_offset_seconds })
  | _ -> decode_error "Invalid time structure"

and decode_local_datetime fields =
  match fields with
  | [Value.Int seconds_since_epoch; Value.Int nanoseconds] ->
      return (Value.LocalDateTime { seconds_since_epoch; nanoseconds })
  | _ -> decode_error "Invalid local datetime structure"

and decode_datetime_zone_id fields =
  match fields with
  | [Value.Int seconds_since_epoch; Value.Int nanoseconds; Value.Text timezone_id] ->
      return (Value.DateTimeZoneId { seconds_since_epoch; nanoseconds; timezone_id })
  | _ -> decode_error "Invalid datetime with zone id structure"

and decode_datetime_offset fields =
  match fields with
  | [Value.Int seconds_since_epoch; Value.Int nanoseconds; Value.Int timezone_offset_seconds] ->
      return (Value.DateTimeOffset { seconds_since_epoch; nanoseconds; timezone_offset_seconds })
  | _ -> decode_error "Invalid datetime with offset structure"

let decode_value_from_string s =
  match parse_string ~consume:All (decode_value ()) s with
  | Ok v -> Ok v
  | Error msg -> Error msg

