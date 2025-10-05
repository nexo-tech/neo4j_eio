(** Declarative query builder DSL *)

type clause =
  | Match of string
  | OptionalMatch of string
  | Create of string
  | Merge of string
  | Unwind of string * string  (* expression, alias *)
  | Where of string list  (* conditions *)
  | Return of bool * string list  (* distinct, fields *)
  | With of string list
  | OrderBy of (string * bool) list  (* field, descending *)
  | Limit of int
  | Skip of int
  | Set of string list
  | Delete of bool * string list  (* detach, nodes *)
  | RawCypher of string

type t = {
  clauses : clause list;
  params : (string * Value.value) list;
}

(** {1 Construction} *)

let raw cypher = {
  clauses = [RawCypher cypher];
  params = [];
}

let match_ pattern = {
  clauses = [Match pattern];
  params = [];
}

let optional_match pattern = {
  clauses = [OptionalMatch pattern];
  params = [];
}

let create_node pattern = {
  clauses = [Create pattern];
  params = [];
}

let merge pattern = {
  clauses = [Merge pattern];
  params = [];
}

let unwind expr alias = {
  clauses = [Unwind (expr, alias)];
  params = [];
}

(** {1 Filtering} *)

let where condition builder =
  { builder with clauses = builder.clauses @ [Where [condition]] }

let and_where condition builder =
  (* Find the last Where clause and append to it *)
  let rec update_where acc = function
    | [] -> List.rev (Where [condition] :: acc)
    | Where conditions :: rest ->
        List.rev_append acc (Where (conditions @ [condition]) :: rest)
    | clause :: rest -> update_where (clause :: acc) rest
  in
  { builder with clauses = update_where [] builder.clauses }

let or_where condition builder =
  (* Find the last Where clause and append with OR *)
  let rec update_where acc = function
    | [] -> List.rev (Where [condition] :: acc)
    | Where conditions :: rest ->
        let combined = String.concat " OR " conditions ^ " OR " ^ condition in
        List.rev_append acc (Where [combined] :: rest)
    | clause :: rest -> update_where (clause :: acc) rest
  in
  { builder with clauses = update_where [] builder.clauses }

(** {1 Return and Projection} *)

let return fields builder =
  { builder with clauses = builder.clauses @ [Return (false, fields)] }

let return_distinct fields builder =
  { builder with clauses = builder.clauses @ [Return (true, fields)] }

let with_ fields builder =
  { builder with clauses = builder.clauses @ [With fields] }

(** {1 Ordering and Limiting} *)

let order_by expr builder =
  let new_order = (expr, false) in
  let rec add_order acc = function
    | [] -> List.rev (OrderBy [new_order] :: acc)
    | OrderBy orders :: rest ->
        List.rev_append acc (OrderBy (orders @ [new_order]) :: rest)
    | clause :: rest -> add_order (clause :: acc) rest
  in
  { builder with clauses = add_order [] builder.clauses }

let order_by_desc expr builder =
  let new_order = (expr, true) in
  let rec add_order acc = function
    | [] -> List.rev (OrderBy [new_order] :: acc)
    | OrderBy orders :: rest ->
        List.rev_append acc (OrderBy (orders @ [new_order]) :: rest)
    | clause :: rest -> add_order (clause :: acc) rest
  in
  { builder with clauses = add_order [] builder.clauses }

let limit n builder =
  { builder with clauses = builder.clauses @ [Limit n] }

let skip n builder =
  { builder with clauses = builder.clauses @ [Skip n] }

(** {1 Mutations} *)

let create pattern builder =
  { builder with clauses = builder.clauses @ [Create pattern] }

let set assignments builder =
  { builder with clauses = builder.clauses @ [Set assignments] }

let delete nodes builder =
  { builder with clauses = builder.clauses @ [Delete (false, nodes)] }

let detach_delete nodes builder =
  { builder with clauses = builder.clauses @ [Delete (true, nodes)] }

(** {1 Parameters} *)

let with_params params builder =
  { builder with params = builder.params @ params }

let with_param param builder =
  { builder with params = builder.params @ [param] }

(** {1 Building} *)

let build_clause = function
  | Match pattern -> "MATCH " ^ pattern
  | OptionalMatch pattern -> "OPTIONAL MATCH " ^ pattern
  | Create pattern -> "CREATE " ^ pattern
  | Merge pattern -> "MERGE " ^ pattern
  | Unwind (expr, alias) -> "UNWIND " ^ expr ^ " AS " ^ alias
  | Where conditions -> "WHERE " ^ String.concat " AND " conditions
  | Return (distinct, fields) ->
      "RETURN " ^ (if distinct then "DISTINCT " else "") ^ String.concat ", " fields
  | With fields -> "WITH " ^ String.concat ", " fields
  | OrderBy orders ->
      "ORDER BY " ^ String.concat ", " (List.map (fun (field, desc) ->
        field ^ (if desc then " DESC" else "")
      ) orders)
  | Limit n -> "LIMIT " ^ string_of_int n
  | Skip n -> "SKIP " ^ string_of_int n
  | Set assignments -> "SET " ^ String.concat ", " assignments
  | Delete (detach, nodes) ->
      (if detach then "DETACH DELETE " else "DELETE ") ^ String.concat ", " nodes
  | RawCypher cypher -> cypher

let build builder =
  String.concat "\n" (List.map build_clause builder.clauses)

let build_with_params builder =
  (build builder, builder.params)

let to_string = build

(** {1 Execution Helpers} *)

let execute builder session =
  let query_str = build builder in
  let query = Cypher.query query_str in
  let query_with_params =
    if builder.params = [] then query
    else Cypher.with_params builder.params query
  in
  Cypher.run query_with_params session

let execute_unit builder session =
  let query_str = build builder in
  let query = Cypher.query_unit query_str in
  let query_with_params =
    if builder.params = [] then query
    else Cypher.with_params builder.params query
  in
  Cypher.run query_with_params session

(** {1 Convenience Constructors} *)

let select _fields pattern =
  match_ pattern

let insert pattern props =
  create_node pattern
  |> with_params props

let update pattern set_clause =
  match_ pattern
  |> set set_clause

let remove pattern =
  match_ pattern
  |> detach_delete [pattern]
