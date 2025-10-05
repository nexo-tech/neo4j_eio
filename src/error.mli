type t =
  | Io of string
  | Protocol of string
  | Auth of string
  | Database of { code: string; message: string }
  | Transient of { code: string; message: string }
  | ClientError of { code: string; message: string }

val to_string : t -> string

(* Parse FAILURE response into typed error *)
val from_failure_map : Value.value Value.StringMap.t -> t
