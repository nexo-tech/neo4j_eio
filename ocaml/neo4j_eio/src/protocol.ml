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

