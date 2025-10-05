open Eio

(* Session manages a single connection with serialized access *)
type 'a t = {
  flow: 'a;
  version: Protocol.version; [@warning "-69"]
  mutex: Mutex.t;
  mutable closed: bool;
  mutable in_transaction: bool;
}

let create flow version =
  { flow; version; mutex = Mutex.create (); closed = false; in_transaction = false }

(* Internal reset - must be called with mutex already held *)
let reset_internal t =
  let reset_msg = Protocol.build_reset () in
  Connection.send_message t.flow reset_msg;

  match Connection.recv_response t.flow with
  | Error e -> Error (Error.Protocol ("RESET decode failed: " ^ e))
  | Ok (Value.Struct { signature = 0x70; _ }) ->
      t.in_transaction <- false;  (* RESET clears transaction state *)
      Ok ()
  | Ok (Value.Struct { signature = 0x7F; fields }) ->
      let err = match fields with
      | Value.Map m :: _ -> Error.from_failure_map m
      | _ -> Error.Protocol "RESET failed"
      in
      Error err
  | Ok _ ->
      Error (Error.Protocol "Unexpected RESET response")

(* Reset the session to clear failed state *)
let reset t =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      reset_internal t
    )

(* Stream type for lazy record consumption *)
type stream = {
  fetch_next: unit -> (Value.value list, Error.t) result;
  mutable exhausted: bool;
}

(* Execute a query and return a stream for lazy consumption *)
let run_stream t ~statement ?(parameters = Value.StringMap.empty) ?(fetch_size = 1000L) () =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    (* Send RUN immediately *)
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      let run_msg = Protocol.build_run ~statement ~parameters () in
      Connection.send_message t.flow run_msg;

      (* Receive RUN response *)
      match Connection.recv_response t.flow with
      | Error e -> Error (Error.Protocol ("RUN decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          (* SUCCESS - create stream *)
          let exhausted_ref = ref false in
          let rec stream = {
            fetch_next = (fun () ->
              (* Check if already exhausted *)
              if !exhausted_ref then
                Ok []
              else
                Mutex.use_rw t.mutex ~protect:true (fun () ->
                  (* Send PULL for next chunk *)
                  let pull_msg = Protocol.build_pull ~n:(Some fetch_size) () in
                  Connection.send_message t.flow pull_msg;

                  (* Collect records from this PULL *)
                  let rec collect_chunk acc =
                    match Connection.recv_response t.flow with
                    | Error e -> Error (Error.Protocol ("PULL decode failed: " ^ e))
                    | Ok (Value.Struct { signature = 0x71; fields = [Value.List records] }) ->
                        (* RECORD - continue collecting this chunk *)
                        collect_chunk (records :: acc)
                    | Ok (Value.Struct { signature = 0x70; fields = [Value.Map meta] }) ->
                        (* SUCCESS - chunk complete *)
                        let has_more = match Value.StringMap.find_opt "has_more" meta with
                          | Some (Value.Bool b) -> b
                          | _ -> false
                        in
                        exhausted_ref := not has_more;
                        stream.exhausted <- not has_more;
                        Ok (List.rev acc |> List.flatten)
                    | Ok (Value.Struct { signature = 0x70; _ }) ->
                        (* SUCCESS without metadata - stream exhausted *)
                        exhausted_ref := true;
                        stream.exhausted <- true;
                        Ok (List.rev acc |> List.flatten)
                    | Ok (Value.Struct { signature = 0x7F; fields }) ->
                        (* FAILURE - automatically reset session *)
                        exhausted_ref := true;
                        stream.exhausted <- true;
                        let err = match fields with
                        | Value.Map m :: _ -> Error.from_failure_map m
                        | _ -> Error.Protocol "Query failed"
                        in
                        (* Auto-reset like hasbolt does, but not in transactions *)
                        (if not t.in_transaction then
                          let _ = reset_internal t in ());
                        Error err
                    | Ok _ ->
                        exhausted_ref := true;
                        stream.exhausted <- true;
                        Error (Error.Protocol "Unexpected response during PULL")
                  in
                  collect_chunk []
                )
            );
            exhausted = false;
          }
          in
          Ok stream
      | Ok (Value.Struct { signature = 0x7E; _ }) ->
          Error (Error.Protocol "RUN was ignored - session in failed state")
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE - automatically reset session *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "RUN failed"
          in
          (* Auto-reset like hasbolt does, but not in transactions *)
          (if not t.in_transaction then
            let _ = reset_internal t in ());
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected RUN response")
    )

(* Record-based stream type *)
type record_stream = {
  fetch_next_records: unit -> (Record.t list, Error.t) result;
  mutable exhausted: bool;
}

(* Execute a query and return a record stream for lazy consumption *)
let run_stream_records t ~statement ?(parameters = Value.StringMap.empty) ?(fetch_size = 1000L) () =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    (* Send RUN immediately *)
    Mutex.use_rw t.mutex ~protect:true (fun () ->
      let run_msg = Protocol.build_run ~statement ~parameters () in
      Connection.send_message t.flow run_msg;

      (* Receive RUN response *)
      match Connection.recv_response t.flow with
      | Error e -> Error (Error.Protocol ("RUN decode failed: " ^ e))
      | Ok (Value.Struct { signature = 0x70; fields = [Value.Map meta] }) ->
          (* SUCCESS - extract field names from metadata *)
          let field_names = match Value.StringMap.find_opt "fields" meta with
            | Some (Value.List names) ->
                List.filter_map (function Value.Text name -> Some name | _ -> None) names
            | _ -> []
          in

          (* Create record stream *)
          let exhausted_ref = ref false in
          let rec stream = {
            fetch_next_records = (fun () ->
              (* Check if already exhausted *)
              if !exhausted_ref then
                Ok []
              else
                Mutex.use_rw t.mutex ~protect:true (fun () ->
                  (* Send PULL for next chunk *)
                  let pull_msg = Protocol.build_pull ~n:(Some fetch_size) () in
                  Connection.send_message t.flow pull_msg;

                  (* Collect records from this PULL *)
                  let rec collect_chunk acc =
                    match Connection.recv_response t.flow with
                    | Error e -> Error (Error.Protocol ("PULL decode failed: " ^ e))
                    | Ok (Value.Struct { signature = 0x71; fields = [Value.List values] }) ->
                        (* RECORD - combine field names with values to create a record *)
                        let record =
                          List.fold_left2 (fun acc name value ->
                            Value.StringMap.add name value acc
                          ) Value.StringMap.empty field_names values
                        in
                        collect_chunk (record :: acc)
                    | Ok (Value.Struct { signature = 0x70; fields = [Value.Map meta] }) ->
                        (* SUCCESS - chunk complete *)
                        let has_more = match Value.StringMap.find_opt "has_more" meta with
                          | Some (Value.Bool b) -> b
                          | _ -> false
                        in
                        exhausted_ref := not has_more;
                        stream.exhausted <- not has_more;
                        Ok (List.rev acc)
                    | Ok (Value.Struct { signature = 0x70; _ }) ->
                        (* SUCCESS without metadata - stream exhausted *)
                        exhausted_ref := true;
                        stream.exhausted <- true;
                        Ok (List.rev acc)
                    | Ok (Value.Struct { signature = 0x7F; fields }) ->
                        (* FAILURE - automatically reset session *)
                        exhausted_ref := true;
                        stream.exhausted <- true;
                        let err = match fields with
                        | Value.Map m :: _ -> Error.from_failure_map m
                        | _ -> Error.Protocol "Query failed"
                        in
                        (* Auto-reset like hasbolt does, but not in transactions *)
                        (if not t.in_transaction then
                          let _ = reset_internal t in ());
                        Error err
                    | Ok _ ->
                        exhausted_ref := true;
                        stream.exhausted <- true;
                        Error (Error.Protocol "Unexpected response during PULL")
                  in
                  collect_chunk []
                )
            );
            exhausted = false;
          }
          in
          Ok stream
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          (* SUCCESS without proper metadata - can't create record stream without field names *)
          Error (Error.Protocol "RUN SUCCESS missing field metadata")
      | Ok (Value.Struct { signature = 0x7E; _ }) ->
          Error (Error.Protocol "RUN was ignored - session in failed state")
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE - automatically reset session *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "RUN failed"
          in
          (* Auto-reset like hasbolt does, but not in transactions *)
          (if not t.in_transaction then
            let _ = reset_internal t in ());
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected RUN response")
    )

(* Execute a query with serialized access - strict materialization *)
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
                (* FAILURE - automatically reset session *)
                let err = match fields with
                | Value.Map m :: _ -> Error.from_failure_map m
                | _ -> Error.Protocol "Query failed"
                in
                (* Auto-reset like hasbolt does *)
                let _ = reset_internal t in
                Error err
            | Ok _ ->
                Error (Error.Protocol "Unexpected response during PULL")
          in
          collect_records []
      | Ok (Value.Struct { signature = 0x7E; _ }) ->
          (* IGNORED - query was ignored (session in failed state after previous error) *)
          Error (Error.Protocol "RUN was ignored - session in failed state")
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE - automatically reset session *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "RUN failed"
          in
          (* Auto-reset like hasbolt does, but not in transactions *)
          (if not t.in_transaction then
            let _ = reset_internal t in ());
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected RUN response")
    )

(* Execute a query and return records with named fields *)
let run_records t ~statement ?(parameters = Value.StringMap.empty) ?(fetch_size = -1L) () =
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
      | Ok (Value.Struct { signature = 0x70; fields = [Value.Map meta] }) ->
          (* SUCCESS - extract field names from metadata *)
          let field_names = match Value.StringMap.find_opt "fields" meta with
            | Some (Value.List names) ->
                List.filter_map (function Value.Text name -> Some name | _ -> None) names
            | _ -> []
          in

          (* Now send PULL to get records *)
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
            | Ok (Value.Struct { signature = 0x71; fields = [Value.List values] }) ->
                (* RECORD - combine field names with values to create a record *)
                let record =
                  List.fold_left2 (fun acc name value ->
                    Value.StringMap.add name value acc
                  ) Value.StringMap.empty field_names values
                in
                collect_records (record :: acc)
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
                  Ok (List.rev acc)
            | Ok (Value.Struct { signature = 0x70; _ }) ->
                (* SUCCESS without metadata - end of stream *)
                Ok (List.rev acc)
            | Ok (Value.Struct { signature = 0x7F; fields }) ->
                (* FAILURE - automatically reset session *)
                let err = match fields with
                | Value.Map m :: _ -> Error.from_failure_map m
                | _ -> Error.Protocol "Query failed"
                in
                (* Auto-reset like hasbolt does *)
                (if not t.in_transaction then
                  let _ = reset_internal t in ());
                Error err
            | Ok _ ->
                Error (Error.Protocol "Unexpected response during PULL")
          in
          collect_records []
      | Ok (Value.Struct { signature = 0x70; _ }) ->
          (* SUCCESS without proper metadata - return empty records *)
          let pull_msg =
            if fetch_size = -1L then
              Protocol.build_pull ~n:(Some (-1L)) ()
            else
              Protocol.build_pull ~n:(Some fetch_size) ()
          in
          Connection.send_message t.flow pull_msg;

          (* With no field names, just return empty records *)
          let rec collect_records acc =
            match Connection.recv_response t.flow with
            | Error e -> Error (Error.Protocol ("PULL decode failed: " ^ e))
            | Ok (Value.Struct { signature = 0x71; _ }) ->
                collect_records (Value.StringMap.empty :: acc)
            | Ok (Value.Struct { signature = 0x70; _ }) ->
                Ok (List.rev acc)
            | Ok (Value.Struct { signature = 0x7F; fields }) ->
                let err = match fields with
                | Value.Map m :: _ -> Error.from_failure_map m
                | _ -> Error.Protocol "Query failed"
                in
                (if not t.in_transaction then
                  let _ = reset_internal t in ());
                Error err
            | Ok _ ->
                Error (Error.Protocol "Unexpected response during PULL")
          in
          collect_records []
      | Ok (Value.Struct { signature = 0x7E; _ }) ->
          (* IGNORED - query was ignored (session in failed state after previous error) *)
          Error (Error.Protocol "RUN was ignored - session in failed state")
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE - automatically reset session *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "RUN failed"
          in
          (* Auto-reset like hasbolt does, but not in transactions *)
          (if not t.in_transaction then
            let _ = reset_internal t in ());
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected RUN response")
    )

(* Helper to consume entire stream into a list *)
let stream_to_list (stream : stream) : (Value.value list, Error.t) result =
  let rec collect acc =
    if stream.exhausted then
      Ok (List.rev acc |> List.flatten)
    else
      match stream.fetch_next () with
      | Error e -> Error e
      | Ok chunk ->
          if List.length chunk = 0 && stream.exhausted then
            Ok (List.rev acc |> List.flatten)
          else
            collect (chunk :: acc)
  in
  collect []

(* Convert a record stream to a list by fetching all chunks *)
let record_stream_to_list (stream : record_stream) : (Record.t list, Error.t) result =
  let rec collect acc =
    if stream.exhausted then
      Ok (List.rev acc |> List.flatten)
    else
      match stream.fetch_next_records () with
      | Error e -> Error e
      | Ok chunk ->
          if List.length chunk = 0 && stream.exhausted then
            Ok (List.rev acc |> List.flatten)
          else
            collect (chunk :: acc)
  in
  collect []

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
          t.in_transaction <- true;  (* Now in transaction *)
          Ok ()
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE - automatically reset session *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "BEGIN failed"
          in
          let _ = reset_internal t in
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
          t.in_transaction <- false;  (* Transaction ended *)
          Ok ()
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE - automatically reset session *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "COMMIT failed"
          in
          let _ = reset_internal t in
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
          (* SUCCESS - rollback completed *)
          t.in_transaction <- false;  (* Transaction ended *)
          Ok ()
      | Ok (Value.Struct { signature = 0x7E; _ }) ->
          (* IGNORED - transaction was already failed, rollback implicit *)
          (* But session is still in FAILED state, need RESET to clear it *)
          t.in_transaction <- false;  (* Transaction ended *)
          let _ = reset_internal t in
          Ok ()
      | Ok (Value.Struct { signature = 0x7F; fields }) ->
          (* FAILURE - automatically reset session *)
          let err = match fields with
          | Value.Map m :: _ -> Error.from_failure_map m
          | _ -> Error.Protocol "ROLLBACK failed"
          in
          let _ = reset_internal t in
          Error err
      | Ok _ ->
          Error (Error.Protocol "Unexpected ROLLBACK response")
    )

(* Transact helper: runs actions in a transaction, commits on success, rollback on error *)
let transact t f =
  if t.closed then
    Error (Error.Protocol "Session is closed")
  else
    match begin_transaction t () with
    | Error e -> Error e
    | Ok () ->
        match f t with
        | Error e ->
            (* Action failed - rollback and return error *)
            (* Note: If the error was a FAILURE, automatic reset already happened *)
            (match rollback t with
             | Ok () ->
                 (* Rollback succeeded - session is back to READY state *)
                 Error e
             | Error _ ->
                 (* Rollback failed - automatic reset already happened if it was a FAILURE *)
                 Error e)
        | Ok result ->
            (* Action succeeded - commit *)
            match commit t with
            | Ok () -> Ok result
            | Error e -> Error e

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
