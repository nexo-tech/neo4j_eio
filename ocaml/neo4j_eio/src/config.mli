type t = {
  host : string;
  port : int;
  user : string;
  password : string;
  use_tls : bool;
}

val default : unit -> t
val of_env : unit -> t
