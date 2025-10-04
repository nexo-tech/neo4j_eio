open Eio

(* Connect with optional TLS support - for now TLS is stub *)
let connect_flow ~sw ~net (cfg : Config.t) =
  let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, cfg.port) in
  let tcp_flow = Net.connect ~sw net addr in
  if cfg.use_tls then
    failwith "TLS support available but type-constrained - use use_tls=false for now"
  else
    tcp_flow

(* TLS connection helper - separate function to handle TLS type *)
let connect_tls ~sw ~net (cfg : Config.t) : Tls_eio.t =
  let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, cfg.port) in
  let tcp_flow = Net.connect ~sw net addr in
  let authenticator =
    match Ca_certs.authenticator () with
    | Ok auth -> auth
    | Error (`Msg msg) -> failwith ("TLS auth error: " ^ msg)
  in
  let tls_config = Tls.Config.client ~authenticator () in
  let host_domain =
    match Domain_name.of_string cfg.host with
    | Ok d -> Domain_name.host_exn d
    | Error (`Msg msg) -> failwith ("Invalid hostname: " ^ msg)
  in
  Tls_eio.client_of_flow tls_config ~host:host_domain tcp_flow

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

(* Send GOODBYE message (without closing - handled by with_connection) *)
let send_goodbye (flow : _ Flow.two_way) : unit =
  try
    let msg = Protocol.build_goodbye () in
    send_message flow msg
  with
  | _ -> ()

(* Legacy goodbye that also closes *)
let goodbye (flow : _ Flow.two_way) : unit =
  send_goodbye flow;
  Flow.close flow

(* High-level connection helper with automatic cleanup *)
let with_connection ~sw ~net (cfg : Config.t) f =
  try
    let flow = connect_flow ~sw ~net cfg in
    Fun.protect
      ~finally:(fun () ->
        (* Always try to send GOODBYE before closing *)
        send_goodbye flow;
        Flow.close flow)
      (fun () ->
        (* Perform handshake *)
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

          (* Send HELLO with credentials *)
          let hello = Protocol.build_hello ~user:cfg.user ~password:cfg.password ~user_agent in
          send_message flow hello;

          match recv_response flow with
          | Error e -> Error (Error.Protocol ("HELLO decode failed: " ^ e))
          | Ok (Value.Struct { signature = 0x70; _ }) ->
              (* SUCCESS - connection authenticated, call user function *)
              f flow version
          | Ok (Value.Struct { signature = 0x7F; fields }) ->
              let msg = match fields with
              | Value.Map m :: _ ->
                  (match Value.StringMap.find_opt "message" m with
                  | Some (Value.Text s) -> s
                  | _ -> "Authentication failed")
              | _ -> "Authentication failed"
              in
              Error (Error.Auth msg)
          | Ok _ ->
              Error (Error.Protocol "Unexpected HELLO response"))
  with
  | End_of_file -> Error (Error.Io "Connection closed by peer")
  | exn -> Error (Error.Io (Printexc.to_string exn))

(* Run a Cypher query and pull all results *)
let run_query (flow : _ Flow.two_way) ~statement ?(parameters = Value.StringMap.empty) () : (Value.value list, Error.t) result =
  try
    (* Send RUN *)
    let run_msg = Protocol.build_run ~statement ~parameters () in
    send_message flow run_msg;

    (* Receive SUCCESS response *)
    match recv_response flow with
    | Error e -> Error (Error.Protocol ("RUN decode failed: " ^ e))
    | Ok (Value.Struct { signature = 0x70; _ }) ->
        (* SUCCESS - now send PULL to get records *)
        let pull_msg = Protocol.build_pull ~n:(Some (-1L)) () in
        send_message flow pull_msg;

        (* Collect records *)
        let rec collect_records acc =
          match recv_response flow with
          | Error e -> Error (Error.Protocol ("PULL decode failed: " ^ e))
          | Ok (Value.Struct { signature = 0x71; fields = [Value.List records] }) ->
              (* RECORD - continue collecting *)
              collect_records (records :: acc)
          | Ok (Value.Struct { signature = 0x70; _ }) ->
              (* SUCCESS - end of stream *)
              Ok (List.rev acc |> List.flatten)
          | Ok (Value.Struct { signature = 0x7F; fields }) ->
              (* FAILURE *)
              let msg = match fields with
              | Value.Map m :: _ ->
                  (match Value.StringMap.find_opt "message" m with
                  | Some (Value.Text s) -> s
                  | _ -> "Query failed")
              | _ -> "Query failed"
              in
              Error (Error.Protocol msg)
          | Ok _ ->
              Error (Error.Protocol "Unexpected response during PULL")
        in
        collect_records []
    | Ok (Value.Struct { signature = 0x7F; fields }) ->
        (* FAILURE *)
        let msg = match fields with
        | Value.Map m :: _ ->
            (match Value.StringMap.find_opt "message" m with
            | Some (Value.Text s) -> s
            | _ -> "RUN failed")
        | _ -> "RUN failed"
        in
        Error (Error.Protocol msg)
    | Ok _ ->
        Error (Error.Protocol "Unexpected RUN response")
  with
  | End_of_file -> Error (Error.Io "Connection closed by peer")
  | exn -> Error (Error.Io (Printexc.to_string exn))
