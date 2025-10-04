type t =
  | Io of string
  | Protocol of string
  | Auth of string

val to_string : t -> string
