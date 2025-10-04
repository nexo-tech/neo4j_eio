(* Record abstraction for Neo4j query results *)

type t = Value.value Value.StringMap.t

(* Decode errors *)
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

let pp_decode_error ppf = function
  | NotNull -> Format.fprintf ppf "Not a Null value"
  | NotBool -> Format.fprintf ppf "Not a Bool value"
  | NotInt -> Format.fprintf ppf "Not an Int value"
  | NotFloat -> Format.fprintf ppf "Not a Float value"
  | NotText -> Format.fprintf ppf "Not a Text value"
  | NotBytes -> Format.fprintf ppf "Not a Bytes value"
  | NotList -> Format.fprintf ppf "Not a List value"
  | NotMap -> Format.fprintf ppf "Not a Map value"
  | NotStruct -> Format.fprintf ppf "Not a Struct value"
  | NotNode -> Format.fprintf ppf "Not a Node value"
  | NotRelationship -> Format.fprintf ppf "Not a Relationship value"
  | NotUnboundRelationship -> Format.fprintf ppf "Not an UnboundRelationship value"
  | NotPath -> Format.fprintf ppf "Not a Path value"
  | NotPoint2D -> Format.fprintf ppf "Not a Point2D value"
  | NotPoint3D -> Format.fprintf ppf "Not a Point3D value"
  | NotDuration -> Format.fprintf ppf "Not a Duration value"
  | NotDate -> Format.fprintf ppf "Not a Date value"
  | NotLocalTime -> Format.fprintf ppf "Not a LocalTime value"
  | NotTime -> Format.fprintf ppf "Not a Time value"
  | NotLocalDateTime -> Format.fprintf ppf "Not a LocalDateTime value"
  | NotDateTimeZoneId -> Format.fprintf ppf "Not a DateTimeZoneId value"
  | NotDateTimeOffset -> Format.fprintf ppf "Not a DateTimeOffset value"
  | KeyNotFound key -> Format.fprintf ppf "Key not found: %s" key

(* Type-directed decoders - exact variants *)

let exact_unit = function
  | Value.Null -> Ok ()
  | _ -> Error NotNull

let exact_bool = function
  | Value.Bool b -> Ok b
  | _ -> Error NotBool

let exact_int = function
  | Value.Int i -> Ok i
  | _ -> Error NotInt

let exact_int_as_int = function
  | Value.Int i -> Ok (Int64.to_int i)
  | _ -> Error NotInt

let exact_float = function
  | Value.Float f -> Ok f
  | Value.Int i -> Ok (Int64.to_float i)
  | _ -> Error NotFloat

let exact_text = function
  | Value.Text s -> Ok s
  | _ -> Error NotText

let exact_bytes = function
  | Value.Bytes b -> Ok b
  | _ -> Error NotBytes

let exact_list decoder = function
  | Value.List xs ->
      let rec decode_all acc = function
        | [] -> Ok (List.rev acc)
        | x :: xs ->
            match decoder x with
            | Ok v -> decode_all (v :: acc) xs
            | Error e -> Error e
      in
      decode_all [] xs
  | _ -> Error NotList

let exact_map = function
  | Value.Map m -> Ok m
  | _ -> Error NotMap

let exact_node = function
  | Value.Node n -> Ok n
  | _ -> Error NotNode

let exact_relationship = function
  | Value.Relationship r -> Ok r
  | _ -> Error NotRelationship

let exact_unbound_relationship = function
  | Value.UnboundRelationship ur -> Ok ur
  | _ -> Error NotUnboundRelationship

let exact_path = function
  | Value.Path p -> Ok p
  | _ -> Error NotPath

let exact_value v = Ok v

(* Maybe variants - return None instead of Error *)

let maybe_exact_unit v = match exact_unit v with Ok x -> Some x | Error _ -> None
let maybe_exact_bool v = match exact_bool v with Ok x -> Some x | Error _ -> None
let maybe_exact_int v = match exact_int v with Ok x -> Some x | Error _ -> None
let maybe_exact_int_as_int v = match exact_int_as_int v with Ok x -> Some x | Error _ -> None
let maybe_exact_float v = match exact_float v with Ok x -> Some x | Error _ -> None
let maybe_exact_text v = match exact_text v with Ok x -> Some x | Error _ -> None
let maybe_exact_bytes v = match exact_bytes v with Ok x -> Some x | Error _ -> None
let maybe_exact_list decoder v = match exact_list decoder v with Ok x -> Some x | Error _ -> None
let maybe_exact_map v = match exact_map v with Ok x -> Some x | Error _ -> None
let maybe_exact_node v = match exact_node v with Ok x -> Some x | Error _ -> None
let maybe_exact_relationship v = match exact_relationship v with Ok x -> Some x | Error _ -> None
let maybe_exact_unbound_relationship v = match exact_unbound_relationship v with Ok x -> Some x | Error _ -> None
let maybe_exact_path v = match exact_path v with Ok x -> Some x | Error _ -> None
let maybe_exact_value v = match exact_value v with Ok x -> Some x | Error _ -> None

(* Record field accessors - at variants *)

let at_unit record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_unit v
  | None -> Error (KeyNotFound key)

let at_bool record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_bool v
  | None -> Error (KeyNotFound key)

let at_int record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_int v
  | None -> Error (KeyNotFound key)

let at_int_as_int record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_int_as_int v
  | None -> Error (KeyNotFound key)

let at_float record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_float v
  | None -> Error (KeyNotFound key)

let at_text record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_text v
  | None -> Error (KeyNotFound key)

let at_bytes record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_bytes v
  | None -> Error (KeyNotFound key)

let at_list decoder record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_list decoder v
  | None -> Error (KeyNotFound key)

let at_map record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_map v
  | None -> Error (KeyNotFound key)

let at_node record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_node v
  | None -> Error (KeyNotFound key)

let at_relationship record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_relationship v
  | None -> Error (KeyNotFound key)

let at_unbound_relationship record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_unbound_relationship v
  | None -> Error (KeyNotFound key)

let at_path record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_path v
  | None -> Error (KeyNotFound key)

let at_value record key =
  match Value.StringMap.find_opt key record with
  | Some v -> exact_value v
  | None -> Error (KeyNotFound key)

(* Maybe_at variants - return None if key not found, or decode error on type mismatch *)

let maybe_at_unit record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_unit v with Ok () -> Ok (Some ()) | Error e -> Error e)
  | None -> Ok None

let maybe_at_bool record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_bool v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_int record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_int v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_int_as_int record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_int_as_int v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_float record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_float v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_text record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_text v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_bytes record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_bytes v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_list decoder record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_list decoder v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_map record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_map v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_node record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_node v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_relationship record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_relationship v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_unbound_relationship record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_unbound_relationship v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_path record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_path v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

let maybe_at_value record key =
  match Value.StringMap.find_opt key record with
  | Some v -> (match exact_value v with Ok x -> Ok (Some x) | Error e -> Error e)
  | None -> Ok None

(* Helper constructors *)

let empty = Value.StringMap.empty

let of_list pairs =
  List.fold_left (fun acc (k, v) ->
    Value.StringMap.add k v acc
  ) Value.StringMap.empty pairs

