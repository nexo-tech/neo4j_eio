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
    encode_string k ^ encode_value v ^ acc
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

