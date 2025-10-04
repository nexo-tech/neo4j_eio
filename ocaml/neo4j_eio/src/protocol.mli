type version =
  | V1
  | V2
  | V3
  | V4_0 | V4_1 | V4_2 | V4_3 | V4_4
  | V5_0 | V5_1 | V5_2 | V5_3 | V5_4
  | Unknown of int * int  (* major, minor *)

val classify : int32 -> version
val major_minor : int32 -> int * int
val supports_logon : version -> bool   (* v5.x *)
val uses_pull_discard : version -> bool (* v3+ *)
val is_new_version : version -> bool   (* v3+ like hasbolt *)
val pp_version : version -> string

(* Chunked message framing *)
val max_chunk_size : int
val chunk_message : string -> string
val dechunk_message : (int -> string) -> string

(* Message codes *)
type message_code =
  | HELLO | GOODBYE | RESET | RUN | DISCARD | PULL
  | BEGIN | COMMIT | ROLLBACK | LOGON

val message_code_to_int : message_code -> int
val message_code_of_int : int -> message_code option
val pp_message_code : message_code -> string

(* Response codes *)
type response_code =
  | SUCCESS | RECORD | IGNORED | FAILURE

val response_code_of_int : int -> response_code option
val pp_response_code : response_code -> string

(* Message builders *)
val build_hello : user:string -> password:string -> user_agent:string -> string
val build_goodbye : unit -> string
val build_reset : unit -> string
