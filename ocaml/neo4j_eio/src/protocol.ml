let major_minor v32 =
  let open Int32 in
  let major = to_int (logand v32 0xFFl) in
  let range = to_int (logand (shift_right_logical v32 16) 0xFFl) in
  let patch = to_int (logand (shift_right_logical v32 8) 0xFFl) in
  let minor = if range = 0 then patch else range in
  (major, minor)

type version =
  | V1
  | V2
  | V3
  | V4_0 | V4_1 | V4_2 | V4_3 | V4_4
  | V5_0 | V5_1 | V5_2 | V5_3 | V5_4
  | Unknown of int * int

let classify v32 =
  let major, minor = major_minor v32 in
  match major, minor with
  | 1, _ -> V1
  | 2, _ -> V2
  | 3, _ -> V3
  | 4, 0 -> V4_0
  | 4, 1 -> V4_1
  | 4, 2 -> V4_2
  | 4, 3 -> V4_3
  | 4, 4 -> V4_4
  | 5, 0 -> V5_0
  | 5, 1 -> V5_1
  | 5, 2 -> V5_2
  | 5, 3 -> V5_3
  | 5, 4 -> V5_4
  | _ -> Unknown (major, minor)

let supports_logon = function
  | V5_0 | V5_1 | V5_2 | V5_3 | V5_4 -> true
  | _ -> false

let uses_pull_discard = function
  | V3 | V4_0 | V4_1 | V4_2 | V4_3 | V4_4 | V5_0 | V5_1 | V5_2 | V5_3 | V5_4 -> true
  | _ -> false

let is_new_version = function
  | V3 | V4_0 | V4_1 | V4_2 | V4_3 | V4_4 | V5_0 | V5_1 | V5_2 | V5_3 | V5_4 -> true
  | _ -> false

let pp_version = function
  | V1 -> "1"
  | V2 -> "2"
  | V3 -> "3"
  | V4_0 -> "4.0"
  | V4_1 -> "4.1"
  | V4_2 -> "4.2"
  | V4_3 -> "4.3"
  | V4_4 -> "4.4"
  | V5_0 -> "5.0"
  | V5_1 -> "5.1"
  | V5_2 -> "5.2"
  | V5_3 -> "5.3"
  | V5_4 -> "5.4"
  | Unknown (maj, min) -> Printf.sprintf "%d.%d" maj min

(* Chunked framing per Bolt specification *)
let max_chunk_size = 65535

let chunk_message (msg : string) : string =
  let msg_len = String.length msg in
  let buf = Buffer.create (msg_len + 32) in
  let rec chunk_at offset =
    if offset >= msg_len then (
      (* End-of-message marker: zero-length chunk *)
      Buffer.add_char buf '\x00';
      Buffer.add_char buf '\x00'
    ) else (
      let remaining = msg_len - offset in
      let chunk_len = min remaining max_chunk_size in
      (* Write 2-byte big-endian chunk length *)
      Buffer.add_char buf (Char.chr (chunk_len lsr 8));
      Buffer.add_char buf (Char.chr (chunk_len land 0xFF));
      (* Write chunk data *)
      Buffer.add_substring buf msg offset chunk_len;
      chunk_at (offset + chunk_len)
    )
  in
  chunk_at 0;
  Buffer.contents buf

let dechunk_message (read_bytes : int -> string) : string =
  let buf = Buffer.create 1024 in
  let rec read_chunks () =
    let header = read_bytes 2 in
    let chunk_len = (Char.code header.[0] lsl 8) lor Char.code header.[1] in
    if chunk_len = 0 then
      (* End of message *)
      Buffer.contents buf
    else (
      let chunk_data = read_bytes chunk_len in
      Buffer.add_string buf chunk_data;
      read_chunks ())
  in
  read_chunks ()

(* Message codes for Bolt protocol *)
type message_code =
  | HELLO | GOODBYE | RESET | RUN | DISCARD | PULL
  | BEGIN | COMMIT | ROLLBACK | LOGON

let message_code_to_int = function
  | HELLO -> 0x01
  | GOODBYE -> 0x02
  | RESET -> 0x0F
  | RUN -> 0x10
  | DISCARD -> 0x2F
  | PULL -> 0x3F
  | BEGIN -> 0x11
  | COMMIT -> 0x12
  | ROLLBACK -> 0x13
  | LOGON -> 0x6A

let message_code_of_int = function
  | 0x01 -> Some HELLO
  | 0x02 -> Some GOODBYE
  | 0x0F -> Some RESET
  | 0x10 -> Some RUN
  | 0x2F -> Some DISCARD
  | 0x3F -> Some PULL
  | 0x11 -> Some BEGIN
  | 0x12 -> Some COMMIT
  | 0x13 -> Some ROLLBACK
  | 0x6A -> Some LOGON
  | _ -> None

type response_code =
  | SUCCESS | RECORD | IGNORED | FAILURE

let response_code_of_int = function
  | 0x70 -> Some SUCCESS
  | 0x71 -> Some RECORD
  | 0x7E -> Some IGNORED
  | 0x7F -> Some FAILURE
  | _ -> None

let pp_message_code = function
  | HELLO -> "HELLO"
  | GOODBYE -> "GOODBYE"
  | RESET -> "RESET"
  | RUN -> "RUN"
  | DISCARD -> "DISCARD"
  | PULL -> "PULL"
  | BEGIN -> "BEGIN"
  | COMMIT -> "COMMIT"
  | ROLLBACK -> "ROLLBACK"
  | LOGON -> "LOGON"

let pp_response_code = function
  | SUCCESS -> "SUCCESS"
  | RECORD -> "RECORD"
  | IGNORED -> "IGNORED"
  | FAILURE -> "FAILURE"
