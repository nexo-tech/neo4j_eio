(* Neo4j connection configuration *)

type log_level =
  | Debug
  | Info
  | Warn
  | Error
  | Silent

type t = {
  uri : string;
  user : string;
  password : string;
  user_agent : string;
  fetch_size : int;
  use_tls : bool;
  tls_ca : string option;
  log_level : log_level;
  protocols : int list;
}

(* Parse URI to extract host and port *)
let parse_uri uri =
  (* Support bolt://host:port or bolt+s://host:port or neo4j://host:port or just host:port *)
  let uri = String.trim uri in
  (* Strip protocol prefix if present *)
  let uri_no_proto =
    if String.starts_with ~prefix:"bolt+s://" uri then
      String.sub uri 9 (String.length uri - 9)
    else if String.starts_with ~prefix:"bolt://" uri then
      String.sub uri 7 (String.length uri - 7)
    else if String.starts_with ~prefix:"neo4j://" uri then
      String.sub uri 8 (String.length uri - 8)
    else if String.starts_with ~prefix:"neo4j+s://" uri then
      String.sub uri 10 (String.length uri - 10)
    else
      uri
  in
  (* Parse host:port *)
  match String.split_on_char ':' uri_no_proto with
  | [host; port_str] ->
      (match int_of_string_opt port_str with
       | Some port -> Ok (host, port)
       | None -> Error ("Invalid port: " ^ port_str))
  | [host] -> Ok (host, 7687) (* Default Bolt port *)
  | _ -> Error ("Invalid URI format: " ^ uri)

let default () =
  { uri = "bolt://127.0.0.1:7687"
  ; user = "neo4j"
  ; password = "testpass"
  ; user_agent = "neo4j_eio/0.1.0"
  ; fetch_size = 1000
  ; use_tls = false
  ; tls_ca = None
  ; log_level = Info
  ; protocols = [5; 4; 3]  (* Bolt 5.x, 4.x, 3.x in order of preference *)
  }

let env k = try Sys.getenv k with Not_found -> ""

let parse_log_level s =
  match String.lowercase_ascii s with
  | "debug" -> Debug
  | "info" -> Info
  | "warn" | "warning" -> Warn
  | "error" -> Error
  | "silent" | "quiet" -> Silent
  | _ -> Info

let of_env () =
  let d = default () in
  (* Parse URI from NEO4J_URI or construct from NEO4J_HOST + NEO4J_PORT *)
  let uri =
    match env "NEO4J_URI" with
    | "" ->
        let host = match env "NEO4J_HOST" with "" -> "127.0.0.1" | s -> s in
        let port =
          match env "NEO4J_PORT" with
          | "" -> 7687
          | s -> (try int_of_string s with _ -> 7687)
        in
        Printf.sprintf "bolt://%s:%d" host port
    | s -> s
  in
  let user =
    match env "NEO4J_USER" with
    | "" -> (match env "NEO4J_USERNAME" with "" -> d.user | s -> s)
    | s -> s
  in
  let password = match env "NEO4J_PASSWORD" with "" -> d.password | s -> s in
  let user_agent = match env "NEO4J_USER_AGENT" with "" -> d.user_agent | s -> s in
  let fetch_size =
    match env "NEO4J_FETCH_SIZE" with
    | "" -> d.fetch_size
    | s -> (try int_of_string s with _ -> d.fetch_size)
  in
  let use_tls =
    match String.lowercase_ascii (env "NEO4J_TLS") with
    | "1" | "true" | "yes" -> true
    | _ ->
        (* Also check if URI starts with bolt+s:// or neo4j+s:// *)
        String.starts_with ~prefix:"bolt+s://" uri ||
        String.starts_with ~prefix:"neo4j+s://" uri
  in
  let tls_ca =
    match env "NEO4J_TLS_CA" with
    | "" -> None
    | s -> Some s
  in
  let log_level =
    match env "NEO4J_LOG_LEVEL" with
    | "" -> d.log_level
    | s -> parse_log_level s
  in
  let protocols = d.protocols in (* Could be made configurable if needed *)
  { uri; user; password; user_agent; fetch_size; use_tls; tls_ca; log_level; protocols }

let make
    ?(uri = "bolt://127.0.0.1:7687")
    ?(user = "neo4j")
    ?(password = "testpass")
    ?(user_agent = "neo4j_eio/0.1.0")
    ?(fetch_size = 1000)
    ?(use_tls = false)
    ?tls_ca
    ?(log_level = Info)
    ?(protocols = [5; 4; 3])
    () =
  { uri; user; password; user_agent; fetch_size; use_tls; tls_ca; log_level; protocols }
