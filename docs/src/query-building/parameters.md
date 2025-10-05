# Parameters and Safety

The Query Builder separates Cypher text from parameters to keep queries safe and ergonomic. This page shows how to bind parameters correctly using the current API.

Binding parameters
- Use `$name` placeholders in Cypher and provide a `(string * Value.value) list` via `with_params` or `with_param`.

```ocaml
let q =
  Query_builder.raw "RETURN $x + 1 AS y, $s AS t"
  |> Query_builder.with_params [
       ("x", Value.Int 41L);
       ("s", Value.Text "hello");
     ]

let res = Query_builder.execute q session
```

Lists and maps
- Pass lists as `Value.List [ ... ]` and maps as `Value.Map <StringMap>`.

```ocaml
let tags = Value.List [Value.Text "a"; Value.Text "b"] in
let props_map =
  [ ("active", Value.Bool true); ("score", Value.Int 10L) ]
  |> List.fold_left (fun m (k,v) -> Value.StringMap.add k v m) Value.StringMap.empty
  |> fun m -> Value.Map m in

let _ = Query_builder.execute_unit
  (Query_builder.raw "CREATE (p:Tmp {name: $name, tags: $tags, props: $props})"
   |> Query_builder.with_params [
        ("name", Value.Text "Alice");
        ("tags", tags);
        ("props", props_map);
      ])
  session
```

IN lists and UNWIND
- Use `$xs` with a list and `x IN $xs`, or use `UNWIND $xs AS x` via `unwind`:

```ocaml
let xs = Value.List (List.init 5 (fun i -> Value.Int (Int64.of_int (i+1)))) in
let res = Query_builder.execute
  (Query_builder.match_ "(p:Person)"
   |> Query_builder.where "p.age IN $xs"
   |> Query_builder.return ["count(p) AS cnt"]
   |> Query_builder.with_param ("xs", xs))
  session
```

Build vs execute
- `build` returns the Cypher string with `$placeholders` intact.
- `build_with_params` returns both the string and the parameter list; you can pass this to the `Cypher` API if you need more control.

```ocaml
let (cypher, params) = Query_builder.build_with_params q in
(* params : (string * Value.value) list *)
```

Safety guidelines
- Do not string‑interpolate user input into clause strings; always use `$param` + `with_params`.
- Keep identifiers (labels, property names) static where possible. The builder does not escape identifiers; clause text is verbatim.
- For user‑selected enums/ids, validate on the application side and map to known strings rather than passing dynamic identifiers.
- Prefer `Session.run_records`/Query Builder (named fields) to reduce decoding mistakes later.

Type considerations
- Parameters are `Value.value`s; choose the closest matching constructor (`Int`, `Text`, `Bool`, `List`, `Map`, etc.).
- Decoding is separate; use `Record.at_*`/`Extract` for typed results.

Troubleshooting
- "Parameter not found" → ensure the name matches `$param` in Cypher.
- Type mismatch in Cypher → e.g., using `IN` on a non‑list; check the `Value` shape.
- Unexpected query shape → inspect `build` output to confirm the generated Cypher.
