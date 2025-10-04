type t =
  | Io of string
  | Protocol of string

val to_string : t -> string
