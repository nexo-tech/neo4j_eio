let be_uint16 n =
  let cs = Cstruct.create 2 in
  Cstruct.BE.set_uint16 cs 0 n;
  cs

let be_uint32 n =
  let cs = Cstruct.create 4 in
  Cstruct.BE.set_uint32 cs 0 n;
  cs

let chunked_frames ~max_chunk payload =
  let len = Cstruct.length payload in
  let rec loop off acc =
    if off >= len then List.rev (be_uint16 0 :: acc)
    else
      let n = Int.min max_chunk (len - off) in
      let chunk = Cstruct.sub payload off n in
      let frame = be_uint16 n in
      loop (off + n) (chunk :: frame :: acc)
  in
  loop 0 []

