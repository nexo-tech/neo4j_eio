open Neo4j_eio

(* Helper to convert string to hex for debugging *)
let to_hex s =
  let buf = Buffer.create (String.length s * 2) in
  String.iter (fun c -> Printf.bprintf buf "%02x" (Char.code c)) s;
  Buffer.contents buf

(* Test primitives *)
let test_encode_null () =
  let encoded = Packstream.encode_value Value.Null in
  Alcotest.(check string) "null" "c0" (to_hex encoded)

let test_encode_bool () =
  let true_enc = Packstream.encode_value (Value.Bool true) in
  let false_enc = Packstream.encode_value (Value.Bool false) in
  Alcotest.(check string) "true" "c3" (to_hex true_enc);
  Alcotest.(check string) "false" "c2" (to_hex false_enc)

let test_encode_tiny_int () =
  let enc0 = Packstream.encode_value (Value.Int 0L) in
  let enc42 = Packstream.encode_value (Value.Int 42L) in
  let enc_neg1 = Packstream.encode_value (Value.Int (-1L)) in
  Alcotest.(check string) "0" "00" (to_hex enc0);
  Alcotest.(check string) "42" "2a" (to_hex enc42);
  Alcotest.(check string) "-1" "ff" (to_hex enc_neg1)

let test_encode_int16 () =
  let enc = Packstream.encode_value (Value.Int 1000L) in
  Alcotest.(check string) "1000" "c903e8" (to_hex enc)

let test_encode_int32 () =
  let enc = Packstream.encode_value (Value.Int 100000L) in
  Alcotest.(check string) "100000" "ca000186a0" (to_hex enc)

let test_encode_int64 () =
  let enc = Packstream.encode_value (Value.Int 10000000000L) in
  Alcotest.(check string) "10000000000" "cb00000002540be400" (to_hex enc)

let test_encode_float () =
  let enc = Packstream.encode_value (Value.Float 1.5) in
  (* 1.5 in IEEE 754 double: 0x3FF8000000000000 *)
  Alcotest.(check string) "1.5" "c13ff8000000000000" (to_hex enc)

let test_encode_tiny_string () =
  let enc = Packstream.encode_value (Value.Text "hello") in
  (* 0x85 = tiny string length 5, followed by "hello" *)
  Alcotest.(check string) "hello" "8568656c6c6f" (to_hex enc)

let test_encode_string8 () =
  let long_str = String.make 20 'a' in
  let enc = Packstream.encode_value (Value.Text long_str) in
  (* STRING_8: marker + len + 20*'a' in hex = 20*"61" *)
  let expected_hex = "d014" ^ String.concat "" (List.init 20 (fun _ -> "61")) in
  Alcotest.(check string) "20 a's" expected_hex (to_hex enc)

let test_encode_bytes () =
  let enc = Packstream.encode_value (Value.Bytes "data") in
  (* BYTES_8: 0xCC, length 4, then "data" *)
  Alcotest.(check string) "bytes" "cc0464617461" (to_hex enc)

let test_encode_tiny_list () =
  let lst = Value.List [Value.Int 1L; Value.Int 2L; Value.Int 3L] in
  let enc = Packstream.encode_value lst in
  (* 0x93 = tiny list length 3, then three tiny ints *)
  Alcotest.(check string) "list [1,2,3]" "93010203" (to_hex enc)

let test_encode_tiny_map () =
  let m = Value.Map (Value.StringMap.of_seq (List.to_seq [
    ("a", Value.Int 1L)
  ])) in
  let enc = Packstream.encode_value m in
  (* 0xA1 = tiny map size 1, then key "a" (0x81 'a'), then value 1 *)
  Alcotest.(check string) "map {a:1}" "a1816101" (to_hex enc)

let test_encode_struct () =
  let s = Value.Struct { signature = 0x42; fields = [Value.Int 1L] } in
  let enc = Packstream.encode_value s in
  (* 0xB1 = tiny struct size 1, signature 0x42, field 1 *)
  Alcotest.(check string) "struct" "b14201" (to_hex enc)

(* Test graph types *)
let test_encode_node () =
  let node = Value.Node {
    node_id = 123L;
    labels = ["Person"];
    props = Value.StringMap.of_seq (List.to_seq [("name", Value.Text "Alice")])
  } in
  let enc = Packstream.encode_value node in
  (* Node structure: sig 'N' (0x4E), fields [id, labels, props] *)
  let hex = to_hex enc in
  Alcotest.(check bool) "starts with B3 4E" true (String.starts_with ~prefix:"b34e" hex)

let test_encode_point2d () =
  let point = Value.Point2D { srid = 4326L; x = 12.3; y = 56.7 } in
  let enc = Packstream.encode_value point in
  (* Point2D structure: sig 'X' (0x58), fields [srid, x, y] *)
  let hex = to_hex enc in
  Alcotest.(check bool) "starts with B3 58" true (String.starts_with ~prefix:"b358" hex)

let test_encode_duration () =
  let dur = Value.Duration { months = 1L; days = 2L; seconds = 3L; nanoseconds = 4L } in
  let enc = Packstream.encode_value dur in
  (* Duration structure: sig 'E' (0x45), 4 fields *)
  let hex = to_hex enc in
  Alcotest.(check bool) "starts with B4 45" true (String.starts_with ~prefix:"b445" hex)

let () =
  Alcotest.run "packstream encoding"
    [ "primitives",
      [ Alcotest.test_case "null" `Quick test_encode_null
      ; Alcotest.test_case "bool" `Quick test_encode_bool
      ; Alcotest.test_case "tiny int" `Quick test_encode_tiny_int
      ; Alcotest.test_case "int16" `Quick test_encode_int16
      ; Alcotest.test_case "int32" `Quick test_encode_int32
      ; Alcotest.test_case "int64" `Quick test_encode_int64
      ; Alcotest.test_case "float" `Quick test_encode_float
      ; Alcotest.test_case "tiny string" `Quick test_encode_tiny_string
      ; Alcotest.test_case "string8" `Quick test_encode_string8
      ; Alcotest.test_case "bytes" `Quick test_encode_bytes
      ]
    ; "collections",
      [ Alcotest.test_case "tiny list" `Quick test_encode_tiny_list
      ; Alcotest.test_case "tiny map" `Quick test_encode_tiny_map
      ; Alcotest.test_case "struct" `Quick test_encode_struct
      ]
    ; "graph types",
      [ Alcotest.test_case "node" `Quick test_encode_node
      ; Alcotest.test_case "point2d" `Quick test_encode_point2d
      ; Alcotest.test_case "duration" `Quick test_encode_duration
      ]
    ]
