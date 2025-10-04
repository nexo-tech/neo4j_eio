val be_uint16 : int -> Cstruct.t
val be_uint32 : int32 -> Cstruct.t

val chunked_frames : max_chunk:int -> Cstruct.t -> Cstruct.t list

(* PackStream encoding *)
val encode_value : Value.value -> string
val encode_int64 : int64 -> string
val encode_float : float -> string
val encode_string : string -> string
val encode_bytes : string -> string
(*
  Produce Bolt chunked frames for a single message payload.
  Returns a list of cstructs to write in order: for each chunk
  two-byte size header followed by the chunk, then a final 0x0000 terminator.
*)
