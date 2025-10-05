# Node, Relationship, and Path Extractors

This page focuses on graph entity extraction. It reflects the current `Value` and `Extract` modules and the `Record.at_*` accessors.

Graph value shapes (Value)
- Node: `{ node_id: int64; labels: string list; props: Value.value Value.StringMap.t }`
- Relationship: `{ rel_id: int64; start_node_id: int64; end_node_id: int64; rel_type: string; rel_props: Value.value Value.StringMap.t }`
- Unbound relationship: `{ urel_id: int64; urel_type: string; urel_props: Value.value Value.StringMap.t }`
- Path: `{ path_nodes: node list; path_rels: urelationship list; path_seq: int list }`

Direct record access
- Use `Record.at_node`, `Record.at_relationship`, `Record.at_unbound_relationship`, `Record.at_path` when you prefer direct accessors.

```ocaml
match Query_builder.execute
  (Query_builder.raw "CREATE (p:Tmp {name:'A'}) RETURN p") session with
| Ok [r] -> (match Record.at_node r "p" with
            | Ok n ->
                Printf.printf "id=%Ld labels=%s\n" n.node_id (String.concat "," n.labels);
                (match Value.StringMap.find_opt "name" n.props with
                 | Some (Value.Text s) -> Printf.printf "name=%s\n" s | _ -> ())
            | Error e -> Format.eprintf "%a\n" Record.pp_decode_error e)
| _ -> ()
```

Extract module helpers
- `Extract.node key`, `Extract.relationship key`, `Extract.unbound_relationship key`, `Extract.path key`
- Composite helpers for graph entities:
  - Node: `node_props key`, `node_labels key`, `node_id key`
  - Relationship: `rel_type key`, `rel_props key`, `rel_id key`

Example: decode node info with Extract
```ocaml
open Extract

let node_info =
  let+ labels = node_labels "p"
  and+ id = node_id "p" in
  (labels, id)

match Query_builder.execute
  (Query_builder.raw "CREATE (p:Tmp {name:'A'}) RETURN p") session with
| Ok [r] -> (match Extract.run node_info r with
            | Ok (labels, id) -> Printf.printf "labels=%s id=%Ld\n" (String.concat "," labels) id
            | Error e -> Format.eprintf "%a\n" Record.pp_decode_error e)
| _ -> ()
```

Relationships
- Use `Extract.relationship` or `Record.at_relationship` to decode the bound relationship value.
- For path results, relationships inside `path_rels` are unbound; decode them with `Extract.unbound_relationship` or inspect the path fields.

Paths
- Decode the entire path with `Extract.path`/`Record.at_path` and iterate nodes/relationships:

```ocaml
match Query_builder.execute
  (Query_builder.raw "MATCH p=(:A)-[:R]->(:B) RETURN p LIMIT 1") session with
| Ok [r] -> (match Record.at_path r "p" with
            | Ok p ->
                List.iter (fun n -> Printf.printf "node %Ld\n" n.node_id) p.path_nodes;
                List.iter (fun r -> Printf.printf "rel %Ld\n" r.urel_id) p.path_rels
            | Error e -> Format.eprintf "%a\n" Record.pp_decode_error e)
| _ -> ()
```

Tips
- Always alias your returns (`... AS p`) so extractor keys match reliably.
- Use property maps (`Value.StringMap`) on nodes/relationships to get properties by name.
- Prefer `Extract` helpers when composing node/relationship details with other fields.
