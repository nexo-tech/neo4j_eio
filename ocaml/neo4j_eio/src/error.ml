type t =
  | Io of string
  | Protocol of string

let to_string = function
  | Io s -> s
  | Protocol s -> s
