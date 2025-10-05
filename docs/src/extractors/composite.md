# Composite Extractors

The Extract module provides higher‑level combinators to reduce boilerplate for common patterns. These build on top of `Record.at_*` and the simple `Extract` primitives.

Built‑ins
- `pair k1 k2 d1 d2` — extract two fields as a tuple using the provided decoders
- `triple k1 k2 k3 d1 d2 d3` — three fields as a tuple
- `text_int k1 k2` — convenience for two fields (text and int)
- `text_list key` — list of text values from a list field
- `int_list key` — list of int64 values from a list field
- Node helpers:
  - `node_props key`, `node_labels key`, `node_id key`
- Relationship helpers:
  - `rel_type key`, `rel_props key`, `rel_id key`

Examples
```ocaml
open Neo4j_eio
open Extract

(* Pair/triple *)
let p = pair "name" "age" Record.at_text Record.at_int
let t = triple "a" "b" "c" Record.at_int Record.at_int Record.at_int

(* Node helpers *)
let node_info =
  let+ labels = node_labels "n"
  and+ id = node_id "n" in
  (labels, id)

(* Lists *)
let tags = text_list "tags"
```

Usage with Query Builder
```ocaml
let extractor = text_int "name" "id"
match Query_builder.execute
  (Query_builder.raw "RETURN 'Alice' AS name, 1 AS id") session with
| Ok [r] -> (match Extract.run extractor r with Ok (n, id) -> Printf.printf "%s #%Ld\n" n id | Error e -> Format.eprintf "%a\n" Record.pp_decode_error e)
| _ -> ()
```

Tips
- Mix composite helpers with applicative style to build richer decoders.
- For nested graph structures, decode nodes/relationships first, then inspect their fields (`Value.StringMap` for properties).
