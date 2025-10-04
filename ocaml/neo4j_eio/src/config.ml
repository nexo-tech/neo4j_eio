type t = {
  host : string;
  port : int;
  user : string;
  password : string;
  use_tls : bool;
}

let default () =
  { host = "127.0.0.1"
  ; port = 7687
  ; user = "neo4j"
  ; password = "testpass"
  ; use_tls = false
  }

let env k = try Sys.getenv k with Not_found -> ""

let of_env () =
  let d = default () in
  let host = match env "NEO4J_HOST" with "" -> d.host | s -> s in
  let port =
    match env "NEO4J_PORT" with
    | "" -> d.port
    | s -> (try int_of_string s with _ -> d.port)
  in
  let user = match env "NEO4J_USER" with "" -> (match env "NEO4J_USERNAME" with "" -> d.user | s -> s) | s -> s in
  let password = match env "NEO4J_PASSWORD" with "" -> d.password | s -> s in
  let use_tls = match String.lowercase_ascii (env "NEO4J_TLS") with "1" | "true" | "yes" -> true | _ -> d.use_tls in
  { host; port; user; password; use_tls }
