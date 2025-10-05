# Lens‑Based Graph Navigation

The Lens and Traversal modules provide composable, read‑only optics to access fields, node properties, and collections. This page reflects `ocaml/src/lens.mli` and `ocaml/src/traversal.mli`, with examples from `ocaml/examples/lens_composition.ml`.

Lens basics
- Type: `('s, 'a) Lens.t = 's -> 'a option`
- Core operators:
  - `s ^. l` — view (option)
  - `s ^? l` — alias for `^.` (preview)
  - `s ^! l` — view or raise if missing
  - Composition: `l1 >>> l2`

Record field access
```ocaml
let open Lens in
let name = record ^. field_text "name"        (* string option *)
let age  = record ^. field_int  "age"         (* int64 option *)
let node = record ^. field_node "p"           (* Value.node option *)
```

Node property access
```ocaml
let open Lens in
match node with
| Some n ->
    let id     = n ^. node_id in               (* int64 option *)
    let labels = n ^. node_labels in           (* string list option *)
    let price  = n ^. node_prop_int "price" in (* int64 option *)
    ()
| None -> ()
```

Fallbacks and alternatives
```ocaml
let open Lens in
(* try displayName, fall back to username *)
let display =
  match record ^. field_text "displayName" with
  | Some d -> d
  | None -> Option.value (record ^. field_text "username") ~default:"Anonymous"
```

Traversals over collections
- Type: `('s, 'a) Traversal.t` focuses multiple values.
- Predefined traversals: `records`, `values`, `each`, `filtered pred`.
- Extract values with `^..`, `^?` and aggregate with folds/aggregations.

```ocaml
let open Traversal in
let salary_trav = records >>> Lens.field_int "salary"
let all_salaries = rows ^.. salary_trav                  (* int64 list *)
let total_salary = sum_int salary_trav rows              (* int64 *)
let avg_salary = average_int salary_trav rows            (* int64 option *)
let top5 = rows ^.. take 5 salary_trav
let high = any (fun s -> s >= 85_000L) salary_trav rows  (* bool *)
```

Transformations
- `map`, `filter`, `take`, `drop` transform what a traversal focuses on.

```ocaml
let score_trav = records >>> Lens.field_int "score"
let high_scores = rows ^.. Traversal.filter (fun s -> s >= 50L) score_trav
```

Tips
- Use Lens for ergonomic access to record fields and node/relationship properties.
- Use Traversal to operate over sets of rows or values without manual loops.
- Keep Cypher returning named fields (`AS ...`) for stable lens keys.
