open Eio

(* Session manages a single connection with serialized access *)
type 'a t = {
  flow: 'a;
  version: Protocol.version;
  mutex: Mutex.t;
  mutable closed: bool;
}

let create flow version =
  { flow; version; mutex = Mutex.create (); closed = false }

(* Execute a query with serialized access *)
let run t ~statement ?(parameters = Value.StringMap.empty) ?(fetch_size = -1L) () =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      (* Send RUN *)
      let run_msg = Protocol.build_run ~statement ~parameters () in
      Connection.send_message t.flow run_msg;

      (* Receive SUCCESS response *)
      match Connection.recv_response t.flow with
      | Error e -> Error (Error.Protocol ("RUN decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          (* SUCCESS - now send PULL to get records *)
          let pull_msg =
            if fetch_size = -1L then
              Protocol.build_pull ~n:(Some (-1L)) ()
            else
              Protocol.build_pull ~n:(Some fetch_size) ()
          in
          Connection.send_message t.flow pull_msg;

          (* Collect records - loop until has_more is false *)
          let rec collect_records acc =
            match Connection.recv_response t.flow with
            | Error e -> Error (Error.Protocol ("PULL decode failed: " ^ e))
            | Ok (Value.Struct { signature = 0x71; fields = [Value.List records] }) ->
                (* RECORD - continue collecting *)
                collect_records (records :: acc)
            | Ok (Value.Struct { signature = 0x70; fields = [Value.Map meta] }) ->
                (* SUCCESS - check if there are more records *)
                let has_more = match Value.StringMap.find_opt "has_more" meta with
                  | Some (Value.Bool b) -> b
                  | _ -> false
                in
                if has_more then (
                  (* Send another PULL *)
                  let pull_msg =
                    if fetch_size = -1L then
                      Protocol.build_pull ~n:(Some (-1L)) ()
                    else
                      Protocol.build_pull ~n:(Some fetch_size) ()
                  in
                  Connection.send_message t.flow pull_msg;
                  collect_records acc
                ) else
                  (* No more records - return what we have *)
                  Ok (List.rev acc |> List.flatten)
            | Ok (Value.Struct { signature = 0x70; _ }) ->
                (* SUCCESS without metadata - end of stream *)
                Ok (List.rev acc |> List.flatten)
            | Ok (Value.Struct { signature = 0x7F; fields }) ->
                (* FAILURE *)
                let err = match fields with
                | Value.Map m :: _ -> Error.from_failure_map m
                | _ -> Error.Protocol "Query failed"
                in
                Error err
            | Ok _ ->
                Error (Error.Protocol "Unexpected response during PULL")
          in
          collect_records []
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "RUN failed"
          in
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected RUN response")
    )

(* Begin a transaction *)
let begin_transaction t ?(metadata = Value.StringMap.empty) () =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      let begin_msg = Protocol.build_begin ~extra:metadata () in
      Connection.send_message t.flow begin_msg;

      match Connection.recv_response t.flow with
      | Error e -> Error (Error.Protocol ("BEGIN decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          Ok ()
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "BEGIN failed"
          in
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected BEGIN response")
    )

(* Commit a transaction *)
let commit t =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      let commit_msg = Protocol.build_commit () in
      Connection.send_message t.flow commit_msg;

      match Connection.recv_response t.flow with
      | Error e -> Error (Error.Protocol ("COMMIT decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          Ok ()
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "COMMIT failed"
          in
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected COMMIT response")
    )

(* Rollback a transaction *)
let rollback t =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      let rollback_msg = Protocol.build_rollback () in
      Connection.send_message t.flow rollback_msg;

      match Connection.recv_response t.flow with
      | Error e -> Error (Error.Protocol ("ROLLBACK decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          Ok ()
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "ROLLBACK failed"
          in
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected ROLLBACK response")
    )

(* Reset the session to clear failed state *)
let reset t =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      let reset_msg = Protocol.build_reset () in
      Connection.send_message t.flow reset_msg;

      match Connection.recv_response t.flow with
      | Error e -> Error (Error.Protocol ("RESET decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          Ok ()
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "RESET failed"
          in
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected RESET response")
    )

(* Close the session *)
let close t =
  if not t.closed then (
    t.closed <- true;
    Connection.send_goodbye t.flow;
    Flow.close t.flow
  )

(* Create a session from configuration *)
let with_session ~sw ~net cfg f =
  Connection.with_connection ~sw ~net cfg (fun flow version ->
    let session = create flow version in
    Fun.protect
      ~finally:(fun () -> close session)
      (fun () -> f session)
  )
