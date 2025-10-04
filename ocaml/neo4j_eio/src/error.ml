type t =
  | Io of string
  | Protocol of string
  | Auth of string
  | Database of { code: string; message: string }
  | Transient of { code: string; message: string }
  | ClientError of { code: string; message: string }

let to_string = function
  | Io s -> s
  | Protocol s -> s
  | Auth s -> "Authentication error: " ^ s
  | Database { code; message } -> Printf.sprintf "Database error %s: %s" code message
  | Transient { code; message } -> Printf.sprintf "Transient error %s: %s" code message
  | ClientError { code; message } -> Printf.sprintf "Client error %s: %s" code message

(* Parse FAILURE response into typed error *)
let from_failure_map (m : Value.value Value.StringMap.t) : t =
  let code = match Value.StringMap.find_opt "code" m with
    | Some (Value.Text s) -> s
    | _ -> "Neo.UnknownError"
  in
  let message = match Value.StringMap.find_opt "message" m with
    | Some (Value.Text s) -> s
    | _ -> "Unknown error"
  in
  (* Classify error based on code prefix *)
  if String.starts_with ~prefix:"Neo.DatabaseError" code then
    Database { code; message }
  else if String.starts_with ~prefix:"Neo.TransientError" code then
    Transient { code; message }
  else if String.starts_with ~prefix:"Neo.ClientError" code then
    ClientError { code; message }
  else
    Protocol (Printf.sprintf "%s: %s" code message)
