open Neo4j_eio

let case input32 expected_name =
  let v = Protocol.classify input32 in
  Alcotest.(check string) "classify" expected_name (Protocol.pp_version v)

let test_classify () =
  case 0x00000001l "1";
  case 0x00000002l "2";
  case 0x00000003l "3";
  case 0x00000004l "4.0";
  case 0x00000104l "4.1";
  case 0x00000005l "5.0";
  case 0x00010005l "5.1";
  case 0x00020005l "5.2"

let () = Alcotest.run "protocol" [ "classify", [ Alcotest.test_case "versions" `Quick test_classify ] ]

