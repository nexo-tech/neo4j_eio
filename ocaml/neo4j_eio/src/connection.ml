open Eio

let read_exact (flow : _ Flow.source) (buf : Cstruct.t) (len : int) =
  let rec loop off remaining =
    if remaining = 0 then ()
    else (
      let slice = Cstruct.sub buf off remaining in
      let got = Flow.single_read flow slice in
      if got = 0 then raise End_of_file
      else loop (off + got) (remaining - got))
  in
  loop 0 len

(* Send a chunked message *)
let send_message (flow : _ Flow.sink) (msg : string) : unit =
  let chunked = Protocol.chunk_message msg in
  let buf = Cstruct.of_string chunked in
  let _ = Flow.single_write flow [buf] in
  ()

(* Receive a chunked message *)
let recv_message (flow : _ Flow.source) : string =
  let read_bytes n =
    let buf = Cstruct.create n in
    read_exact flow buf n;
    Cstruct.to_string buf
  in
  Protocol.dechunk_message read_bytes

(* Receive and decode a response message *)
let recv_response (flow : _ Flow.source) : (Value.value, string) result =
  let msg = recv_message flow in
  Packstream.decode_value_from_string msg

let handshake ~sw ~net (cfg : Config.t) : (Protocol.version, Error.t) result =
  try
    let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, cfg.port) in
    let flow = Net.connect ~sw net addr in
        Fun.protect
          ~finally:(fun () -> Flow.close flow)
          (fun () ->
            (* Client handshake: magic + 4 version proposals *)
            let out = Cstruct.create 20 in
            Cstruct.BE.set_uint32 out 0 0x6060B017l;
            let proposals = [ 0x00000005l; 0x00000004l; 0x00000003l; 0x00000002l ] in
            List.iteri (fun i v -> Cstruct.BE.set_uint32 out (4 * (i + 1)) v) proposals;
            let _ = Flow.single_write flow [out] in
            (* Server selects one version (or 0) and replies with 4 bytes *)
            let resp = Cstruct.create 4 in
            read_exact flow resp 4;
            let ver = Cstruct.BE.get_uint32 resp 0 in
            if ver = 0l then Error (Error.Protocol "Server returned version 0")
            else Ok (Protocol.classify ver))
  with
  | End_of_file -> Error (Error.Io "Connection closed by peer")
  | exn -> Error (Error.Io (Printexc.to_string exn))

(* Authenticate with HELLO (v4) or HELLO+LOGON (v5) *)
let authenticate ~sw ~net (cfg : Config.t) =
  try
    let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, cfg.port) in
    let flow = Net.connect ~sw net addr in

    (* Handshake *)
    let out = Cstruct.create 20 in
    Cstruct.BE.set_uint32 out 0 0x6060B017l;
    let proposals = [ 0x00000005l; 0x00000004l; 0x00000003l; 0x00000002l ] in
    List.iteri (fun i v -> Cstruct.BE.set_uint32 out (4 * (i + 1)) v) proposals;
    let _ = Flow.single_write flow [out] in

    let resp = Cstruct.create 4 in
    read_exact flow resp 4;
    let ver = Cstruct.BE.get_uint32 resp 0 in
    if ver = 0l then
      Error (Error.Protocol "Server returned version 0")
    else
      let version = Protocol.classify ver in
      let user_agent = "neo4j-eio/0.1.0" in

      (* Send HELLO with inline credentials (works for v3, v4, and v5) *)
      let hello = Protocol.build_hello ~user:cfg.user ~password:cfg.password ~user_agent in
      send_message flow hello;

      match recv_response flow with
      | Error e -> Error (Error.Protocol ("HELLO decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          (* SUCCESS *)
          Ok (version, flow)
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE *)
          let msg = match fields with
          | Value.Map m :: _ ->
              (match Value.StringMap.find_opt "message" m with
              | Some (Value.Text s) -> s
              | _ -> "Authentication failed")
          | _ -> "Authentication failed"
          in
          Flow.close flow;
          Error (Error.Auth msg)
      | Ok _ ->
          Flow.close flow;
          Error (Error.Protocol "Unexpected HELLO response")
  with
  | End_of_file -> Error (Error.Io "Connection closed by peer")
  | exn -> Error (Error.Io (Printexc.to_string exn))

(* Send GOODBYE and close connection *)
let goodbye (flow : _ Flow.two_way) : unit =
  try
    let msg = Protocol.build_goodbye () in
    send_message flow msg;
    Flow.close flow
  with
  | _ -> Flow.close flow
