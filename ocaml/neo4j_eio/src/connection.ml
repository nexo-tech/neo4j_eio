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
