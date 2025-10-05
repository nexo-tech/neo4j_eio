# Programmatic Query Building

Build queries dynamically by composing small functions that return `Query_builder.t`. This page shows tested patterns that match the current API and examples.

Compose small builders
Write helpers that produce a builder; combine them with `|>`.

```ocaml
open Neo4j_eio

let match_label label = Query_builder.match_ (Printf.sprintf "(n:%s)" label)
let where_active = Query_builder.where "n.active = true"
let project_name_age = Query_builder.return ["n.name AS name"; "n.age AS age"]
let order_age_desc = Query_builder.order_by_desc "n.age"

let query_people label =
  match_label label
  |> where_active
  |> project_name_age
  |> order_age_desc
  |> Query_builder.limit 10
```

Conditional filters
Add filters based on options; `and_where` appends to the most recent WHERE.

```ocaml
let where_min_age = function
  | None -> fun b -> b
  | Some min -> fun b ->
      b
      |> Query_builder.and_where (Printf.sprintf "n.age >= %d" min)

let where_city = function
  | None -> fun b -> b
  | Some c -> fun b -> Query_builder.and_where (Printf.sprintf "n.city = '%s'" c) b

let filter_people ?min_age ?city label =
  match_label label
  |> Query_builder.where "true"    (* seed WHERE so and_where attaches *)
  |> where_min_age min_age
  |> where_city city
  |> project_name_age
```

Parameterized filters (recommended)
Prefer `$param` placeholders + `with_params`.

```ocaml
let filter_people_params ~min_age ~active label =
  match_label label
  |> Query_builder.where "n.age >= $min_age"
  |> Query_builder.and_where "n.active = $active"
  |> project_name_age
  |> Query_builder.with_params [
       ("min_age", Value.Int (Int64.of_int min_age));
       ("active", Value.Bool active);
     ]
```

Reusable RETURN/ORDER fragments

```ocaml
let return_fields fields = fun b -> Query_builder.return fields b
let order_by_many fields =
  List.fold_left (fun b f -> Query_builder.order_by f b)
```

UNWIND builders

```ocaml
let insert_many label (items : (string * Value.value) list list) =
  let list_of_maps =
    items
    |> List.map (fun kvs ->
         kvs
         |> List.fold_left (fun m (k,v) -> Value.StringMap.add k v m) Value.StringMap.empty
         |> fun m -> Value.Map m)
    |> fun xs -> Value.List xs
  in
  Query_builder.unwind "$rows" "row"
  |> Query_builder.with_param ("rows", list_of_maps)
  |> Query_builder.create (Printf.sprintf "(n:%s) SET n = row" label)
  |> Query_builder.return ["count(n) AS created"]
```

Introspect before executing

```ocaml
let (cypher, params) = Query_builder.build_with_params (query_people "Person") in
Printf.printf "%s\n" cypher;
List.iter (fun (k, _v) -> Printf.printf ":%s\n" k) params;
```

Execute with a session

```ocaml
let run_q session label =
  match Query_builder.execute (query_people label) session with
  | Ok rows -> rows
  | Error e -> (Printf.eprintf "%s\n" (Error.to_string e); [])
```

Notes
- Clause strings are verbatim; keep identifiers static and bind data via parameters.
- `and_where`/`or_where` attach to the latest WHERE; seed with a trivial WHERE if you’ll add many conditions conditionally.
- For atomic multi-step flows, wrap builders with the Transaction DSL (`Transaction_dsl.exec_query_builder`).

