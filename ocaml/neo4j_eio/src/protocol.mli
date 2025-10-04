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
