val be_uint16 : int -> Cstruct.t
(** Encode a 16-bit unsigned integer in big-endian. *)

val be_uint32 : int32 -> Cstruct.t
(** Encode a 32-bit unsigned integer in big-endian. *)

val chunked_frames : max_chunk:int -> Cstruct.t -> Cstruct.t list
(** Split a payload into Bolt chunked frames up to [max_chunk] bytes each. *)

(** PackStream encoding *)
val encode_value : Value.value -> string
val encode_int64 : int64 -> string
val encode_float : float -> string
val encode_string : string -> string
val encode_bytes : string -> string

(** PackStream decoding *)
val decode_value_from_string : string -> (Value.value, string) result
(** Decode a single PackStream value from a string buffer. Returns an error string on failure. *)

(**
  Produce Bolt chunked frames for a single message payload.
  Returns a list of cstructs to write in order: for each chunk,
  a two-byte size header is followed by the chunk, ending with a
  final 0x0000 terminator.
*)
