open Neo4j_eio

(* Test chunking a small message *)
let test_chunk_small () =
  let msg = "Hello" in
  let chunked = Protocol.chunk_message msg in
  (* Expected: 2-byte length (0x00 0x05) + "Hello" + end marker (0x00 0x00) *)
  let expected = "\x00\x05Hello\x00\x00" in
  Alcotest.(check string) "small message chunks correctly" expected chunked

(* Test chunking an empty message *)
let test_chunk_empty () =
  let msg = "" in
  let chunked = Protocol.chunk_message msg in
  (* Expected: just end marker (0x00 0x00) *)
  let expected = "\x00\x00" in
  Alcotest.(check string) "empty message chunks correctly" expected chunked

(* Test chunking a message exactly at max chunk size *)
let test_chunk_exact_max () =
  let msg = String.make Protocol.max_chunk_size 'x' in
  let chunked = Protocol.chunk_message msg in
  (* Expected: 2-byte length (0xFF 0xFF) + 65535 'x' chars + end marker (0x00 0x00) *)
  let expected_len = 2 + Protocol.max_chunk_size + 2 in
  Alcotest.(check int) "max-size message length" expected_len (String.length chunked);
  (* Check first chunk header *)
  Alcotest.(check int) "first chunk size high byte" 0xFF (Char.code chunked.[0]);
  Alcotest.(check int) "first chunk size low byte" 0xFF (Char.code chunked.[1]);
  (* Check end marker *)
  Alcotest.(check int) "end marker high byte" 0x00 (Char.code chunked.[String.length chunked - 2]);
  Alcotest.(check int) "end marker low byte" 0x00 (Char.code chunked.[String.length chunked - 1])

(* Test chunking a message larger than max chunk size *)
let test_chunk_multi () =
  let msg = String.make (Protocol.max_chunk_size + 100) 'y' in
  let chunked = Protocol.chunk_message msg in
  (* Expected: 2 chunks + end marker *)
  (* First chunk: 0xFF 0xFF + 65535 'y' *)
  (* Second chunk: 0x00 0x64 + 100 'y' *)
  (* End marker: 0x00 0x00 *)
  let expected_len = 2 + Protocol.max_chunk_size + 2 + 100 + 2 in
  Alcotest.(check int) "multi-chunk message length" expected_len (String.length chunked);
  (* Check first chunk header *)
  Alcotest.(check int) "first chunk size" 0xFF (Char.code chunked.[0]);
  (* Check second chunk header *)
  let second_chunk_offset = 2 + Protocol.max_chunk_size in
  Alcotest.(check int) "second chunk size high byte" 0x00 (Char.code chunked.[second_chunk_offset]);
  Alcotest.(check int) "second chunk size low byte" 0x64 (Char.code chunked.[second_chunk_offset + 1])

(* Test dechunking a small message *)
let test_dechunk_small () =
  let chunked = "\x00\x05Hello\x00\x00" in
  let pos = ref 0 in
  let read_bytes n =
    let result = String.sub chunked !pos n in
    pos := !pos + n;
    result
  in
  let msg = Protocol.dechunk_message read_bytes in
  Alcotest.(check string) "small message dechunks correctly" "Hello" msg

(* Test dechunking an empty message *)
let test_dechunk_empty () =
  let chunked = "\x00\x00" in
  let pos = ref 0 in
  let read_bytes n =
    let result = String.sub chunked !pos n in
    pos := !pos + n;
    result
  in
  let msg = Protocol.dechunk_message read_bytes in
  Alcotest.(check string) "empty message dechunks correctly" "" msg

(* Test dechunking a multi-chunk message *)
let test_dechunk_multi () =
  let chunk1 = "\x00\x03ABC" in
  let chunk2 = "\x00\x02DE" in
  let end_marker = "\x00\x00" in
  let chunked = chunk1 ^ chunk2 ^ end_marker in
  let pos = ref 0 in
  let read_bytes n =
    let result = String.sub chunked !pos n in
    pos := !pos + n;
    result
  in
  let msg = Protocol.dechunk_message read_bytes in
  Alcotest.(check string) "multi-chunk message dechunks correctly" "ABCDE" msg

(* Test roundtrip: chunk then dechunk *)
let test_roundtrip () =
  let original = "The quick brown fox jumps over the lazy dog" in
  let chunked = Protocol.chunk_message original in
  let pos = ref 0 in
  let read_bytes n =
    let result = String.sub chunked !pos n in
    pos := !pos + n;
    result
  in
  let recovered = Protocol.dechunk_message read_bytes in
  Alcotest.(check string) "roundtrip preserves message" original recovered

(* Test message code conversions *)
let test_message_codes () =
  let codes = [
    Protocol.HELLO, 0x01;
    Protocol.GOODBYE, 0x02;
    Protocol.RESET, 0x0F;
    Protocol.RUN, 0x10;
    Protocol.BEGIN, 0x11;
    Protocol.COMMIT, 0x12;
    Protocol.ROLLBACK, 0x13;
    Protocol.DISCARD, 0x2F;
    Protocol.PULL, 0x3F;
    Protocol.LOGON, 0x6A;
  ] in
  List.iter (fun (code, expected_int) ->
    let actual_int = Protocol.message_code_to_int code in
    Alcotest.(check int) (Printf.sprintf "%s to int" (Protocol.pp_message_code code)) expected_int actual_int;
    match Protocol.message_code_of_int actual_int with
    | Some recovered_code ->
        Alcotest.(check string) (Printf.sprintf "int %02x to code" expected_int)
          (Protocol.pp_message_code code) (Protocol.pp_message_code recovered_code)
    | None ->
        Alcotest.fail (Printf.sprintf "Failed to convert int %02x back to message code" expected_int)
  ) codes

(* Test response code conversions *)
let test_response_codes () =
  let codes = [
    Protocol.SUCCESS, 0x70;
    Protocol.RECORD, 0x71;
    Protocol.IGNORED, 0x7E;
    Protocol.FAILURE, 0x7F;
  ] in
  List.iter (fun (code, expected_int) ->
    match Protocol.response_code_of_int expected_int with
    | Some recovered_code ->
        Alcotest.(check string) (Printf.sprintf "int %02x to response code" expected_int)
          (Protocol.pp_response_code code) (Protocol.pp_response_code recovered_code)
    | None ->
        Alcotest.fail (Printf.sprintf "Failed to convert int %02x to response code" expected_int)
  ) codes

(* Test version negotiation logic *)
let test_negotiate_v5 () =
  let ver = Protocol.classify 0x00000005l in
  Alcotest.(check string) "v5 classified" "5.0" (Protocol.pp_version ver);
  Alcotest.(check bool) "v5 supports logon" true (Protocol.supports_logon ver);
  Alcotest.(check bool) "v5 is new version" true (Protocol.is_new_version ver)

let test_negotiate_v4 () =
  let ver = Protocol.classify 0x00000004l in
  Alcotest.(check string) "v4 classified" "4.0" (Protocol.pp_version ver);
  Alcotest.(check bool) "v4 does not support logon" false (Protocol.supports_logon ver);
  Alcotest.(check bool) "v4 is new version" true (Protocol.is_new_version ver)

let test_negotiate_v3 () =
  let ver = Protocol.classify 0x00000003l in
  Alcotest.(check string) "v3 classified" "3" (Protocol.pp_version ver);
  Alcotest.(check bool) "v3 uses pull/discard" true (Protocol.uses_pull_discard ver)

let test_handshake_magic () =
  (* Verify the handshake magic constant *)
  Alcotest.(check int32) "handshake magic" 0x6060B017l 0x6060B017l

let () =
  Alcotest.run "protocol framing"
    [ "chunking", [
        Alcotest.test_case "chunk small message" `Quick test_chunk_small;
        Alcotest.test_case "chunk empty message" `Quick test_chunk_empty;
        Alcotest.test_case "chunk exact max size" `Quick test_chunk_exact_max;
        Alcotest.test_case "chunk multi-chunk" `Quick test_chunk_multi;
      ];
      "dechunking", [
        Alcotest.test_case "dechunk small message" `Quick test_dechunk_small;
        Alcotest.test_case "dechunk empty message" `Quick test_dechunk_empty;
        Alcotest.test_case "dechunk multi-chunk" `Quick test_dechunk_multi;
        Alcotest.test_case "roundtrip" `Quick test_roundtrip;
      ];
      "message codes", [
        Alcotest.test_case "message code conversions" `Quick test_message_codes;
        Alcotest.test_case "response code conversions" `Quick test_response_codes;
      ];
      "version negotiation", [
        Alcotest.test_case "v5 classification" `Quick test_negotiate_v5;
        Alcotest.test_case "v4 classification" `Quick test_negotiate_v4;
        Alcotest.test_case "v3 classification" `Quick test_negotiate_v3;
        Alcotest.test_case "handshake magic" `Quick test_handshake_magic;
      ];
    ]
