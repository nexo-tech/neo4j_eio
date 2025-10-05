# Working With Values (PackStream)

neo4j_eio exposes all Neo4j/PackStream types through the `Value` module. You will use these types in two places:
- As parameter values when sending queries
- When decoding results (together with the `Record` module)

Core `Value.value` variants
- Scalars: `Null | Bool of bool | Int of int64 | Float of float | Text of string | Bytes of string`
- Collections: `List of value list | Map of value StringMap.t`
- Graph: `Node`, `Relationship`, `UnboundRelationship`, `Path`
- Spatial/Temporal (v2): `Point2D`, `Point3D`, `Duration`, `Date`, `LocalTime`, `Time`, `LocalDateTime`, `DateTimeZoneId`, `DateTimeOffset`

Constructing values for parameters

```ocaml
let params = [
  ("name", Value.Text "Alice");
  ("age", Value.Int 30L);
  ("tags", Value.List [Value.Text "friend"; Value.Text "vip"]);
  ("props", Value.Map (
     [ ("likes", Value.Int 10L); ("active", Value.Bool true) ]
     |> List.fold_left (fun acc (k,v) -> Value.StringMap.add k v acc) Value.StringMap.empty));
] in

let _ = Query_builder.execute_unit
  (Query_builder.raw "CREATE (p:Person {name: $name, age: $age})")
  session
```

Returning and decoding values
- Use `Record.at_*` helpers to decode typed values from a `Record.t`.

```ocaml
match Query_builder.execute
  (Query_builder.raw "RETURN true AS b, 42 AS i, 'x' AS s, [1,2] AS xs")
  session with
| Ok [r] ->
    (match Record.at_bool r "b", Record.at_int r "i", Record.at_text r "s",
           Record.at_list Record.exact_int r "xs" with
     | Ok b, Ok i, Ok s, Ok xs ->
         Printf.printf "b=%b i=%Ld s=%s xs_len=%d\n" b i s (List.length xs)
     | _ -> Printf.printf "decode error\n")
| _ -> ()
```

Graph entities
- Node: `{ node_id; labels; props }`
- Relationship: `{ rel_id; start_node_id; end_node_id; rel_type; rel_props }`
- Path: `{ path_nodes; path_rels; path_seq }`

```ocaml
match Query_builder.execute
  (Query_builder.raw "CREATE (p:Tmp {name:'A'}) RETURN p") session with
| Ok [r] ->
    (match Record.at_node r "p" with
     | Ok n ->
         Printf.printf "node id=%Ld labels=%s\n"
           n.node_id (String.concat "," n.labels);
         (match Value.StringMap.find_opt "name" n.props with
          | Some (Value.Text s) -> Printf.printf "name=%s\n" s
          | _ -> ())
     | Error _ -> ())
| _ -> ()
```

Spatial/temporal examples

```ocaml
(* Point2D *)
match Query_builder.execute
  (Query_builder.raw "RETURN point({x: 1.5, y: 2.5}) AS pt") session with
| Ok [r] -> (match Record.at_point2d r "pt" with Ok p -> Printf.printf "(%.1f,%.1f) srid=%Ld\n" p.x p.y p.srid | _ -> ())
| _ -> ()

(* Duration *)
match Query_builder.execute
  (Query_builder.raw "RETURN duration('P1Y2M3DT4H5M6S') AS d") session with
| Ok [r] -> (match Record.at_duration r "d" with Ok d -> Printf.printf "%Ld months, %Ld days\n" d.months d.days | _ -> ())
| _ -> ()
```

Tips
- Prefer `Record.at_*`/`Record.exact_*` to catch type mismatches early.
- When building maps, use `Value.StringMap.add` to construct `Map` values.
- Use `Session.run_records` or Query Builder to preserve field names in results, making decoding straightforward.

