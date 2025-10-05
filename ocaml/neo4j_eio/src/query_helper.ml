(** Result-based query helpers combining queries with extraction *)

(* Core Query Helpers *)

let query_extract session statement ?params extractor =
  let parameters = match params with
    | None -> Value.StringMap.empty
    | Some ps -> Neo4j.props ps
  in
  match Neo4j.query session ~statement ~parameters () with
  | Error e -> Error e
  | Ok records ->
      (* Extract each record, fail on first error *)
      let rec extract_all acc = function
        | [] -> Ok (List.rev acc)
        | record :: rest ->
            match Extract.run extractor record with
            | Error decode_err ->
                (* Convert decode error to Neo4j error *)
                let msg = Format.asprintf "Extraction failed: %a" Record.pp_decode_error decode_err in
                Error (Error.ClientError { code = "Client.ExtractionError"; message = msg })
            | Ok value ->
                extract_all (value :: acc) rest
      in
      extract_all [] records

let query_extract_single session statement ?params extractor =
  match query_extract session statement ?params extractor with
  | Error e -> Error e
  | Ok [] -> Ok None
  | Ok (first :: _) -> Ok (Some first)

let query_extract_one session statement ?params extractor =
  match query_extract session statement ?params extractor with
  | Error e -> Error e
  | Ok [] -> Error (Error.ClientError { code = "Client.NoResults"; message = "Expected exactly one result, got zero" })
  | Ok [single] -> Ok single
  | Ok results ->
      let msg = Printf.sprintf "Expected exactly one result, got %d" (List.length results) in
      Error (Error.ClientError { code = "Client.TooManyResults"; message = msg })

let query_unit session statement ?params () =
  let parameters = match params with
    | None -> Value.StringMap.empty
    | Some ps -> Neo4j.props ps
  in
  match Neo4j.query_ session ~statement ~parameters () with
  | Ok () -> Ok ()
  | Error e -> Error e

let query_count session statement ?params () =
  let parameters = match params with
    | None -> Value.StringMap.empty
    | Some ps -> Neo4j.props ps
  in
  match Neo4j.query session ~statement ~parameters () with
  | Error e -> Error e
  | Ok records -> Ok (List.length records)

(* Convenience Combinators *)

let map_query f query session =
  match query session with
  | Ok value -> Ok (f value)
  | Error e -> Error e

let bind_query query f session =
  match query session with
  | Ok value -> f value session
  | Error e -> Error e

let sequence_queries queries session =
  let rec go acc = function
    | [] -> Ok (List.rev acc)
    | query :: rest ->
        match query session with
        | Error e -> Error e
        | Ok value -> go (value :: acc) rest
  in
  go [] queries

(* Transaction Helpers *)

let transact session f =
  Session.transact session (fun tx -> f tx)

let transact_unit session f =
  transact session f

(* Batch Operations *)

let batch_execute session statement ?(batch_size = 0) param_lists =
  if batch_size > 0 && batch_size < List.length param_lists then
    (* Execute in batches *)
    let rec execute_batches = function
      | [] -> Ok ()
      | batch ->
          let current_batch, rest =
            let rec take n acc lst =
              match lst with
              | [] -> (List.rev acc, [])
              | _ when n <= 0 -> (List.rev acc, lst)
              | x :: xs -> take (n - 1) (x :: acc) xs
            in
            take batch_size [] batch
          in
          match transact session (fun tx ->
            let rec execute_in_tx = function
              | [] -> Ok ()
              | params :: rest ->
                  let parameters = Neo4j.props params in
                  match Neo4j.query_ tx ~statement ~parameters () with
                  | Error e -> Error e
                  | Ok () -> execute_in_tx rest
            in
            execute_in_tx current_batch
          ) with
          | Error e -> Error e
          | Ok () -> execute_batches rest
    in
    execute_batches param_lists
  else
    (* Execute all in one transaction *)
    transact session (fun tx ->
      let rec execute_all = function
        | [] -> Ok ()
        | params :: rest ->
            let parameters = Neo4j.props params in
            match Neo4j.query_ tx ~statement ~parameters () with
            | Error e -> Error e
            | Ok () -> execute_all rest
      in
      execute_all param_lists
    )

let batch_extract session statement extractor param_lists =
  let rec execute_all acc = function
    | [] -> Ok (List.rev acc)
    | params :: rest ->
        match query_extract session statement ~params extractor with
        | Error e -> Error e
        | Ok results ->
            execute_all (List.rev_append results acc) rest
  in
  execute_all [] param_lists

(* Parameter Helpers *)

let (=:) key value = (key, value)

let props bindings = bindings

(* Common Queries *)

let node_by_id session id extractor =
  query_extract_single session
    "MATCH (n) WHERE id(n) = $id RETURN n"
    ~params:["id" =: Value.Int id]
    extractor

let nodes_by_label session label extractor =
  let statement = Printf.sprintf "MATCH (n:%s) RETURN n" label in
  query_extract session statement extractor

let relationship_by_id session id extractor =
  query_extract_single session
    "MATCH ()-[r]->() WHERE id(r) = $id RETURN r"
    ~params:["id" =: Value.Int id]
    extractor

(* Utility Functions *)

let with_default default = function
  | Ok (Some value) -> Ok value
  | Ok None -> Ok default
  | Error e -> Error e

let option_to_result error = function
  | Some value -> Ok value
  | None -> Error error

let result_to_option = function
  | Ok value -> Some value
  | Error _ -> None
