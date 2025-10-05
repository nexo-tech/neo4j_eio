# ETL Pipeline Example

This example demonstrates a practical Extract–Transform–Load (ETL) workflow using the current neo4j_eio API. We’ll stage raw order data, load it into a graph model, and optionally post‑process results using the Cypher fluent pipeline.

Scenario
- Raw orders with shape: `{user, item, qty, price}`
- Target graph:
  - `(:User {username, name})`
  - `(:Item {sku, title})`
  - `(:PURCHASE {qty, price, total})` relationships from User to Item

APIs used
- Query Builder: `Query_builder.raw`, `with_params`, `execute`, `execute_unit`
- Record decoding: `Record.at_*`
- Optional: Transaction DSL for atomic multi‑step ETL
- Optional: Cypher pipeline (`Cypher`) for in‑memory transformations

Stage raw data (label‑scoped)
```ocaml
open Neo4j_eio

let stage_orders session label =
  Query_builder.execute_unit
    (Query_builder.raw (Printf.sprintf
       "UNWIND [\n         {u:'alice', name:'Alice', sku:'A', title:'Laptop',  qty:1, price:1200},\n         {u:'alice', name:'Alice', sku:'B', title:'Mouse',   qty:2, price:  25},\n         {u:'bob',   name:'Bob',   sku:'B', title:'Mouse',   qty:1, price:  25},\n         {u:'bob',   name:'Bob',   sku:'C', title:'Keyboard',qty:1, price:  75}\n       ] AS x\n       MERGE (:RawOrder:%s {u: x.u, name: x.name, sku: x.sku, title: x.title, qty: x.qty, price: x.price})"
       label))
    session
```

Load into target graph (all‑in‑Cypher)
```ocaml
let load_graph_all_in_cypher session label =
  Query_builder.execute_unit
    (Query_builder.raw (Printf.sprintf
       "MATCH (r:RawOrder:%s)\n\
        MERGE (u:User:%s {username: r.u})\n\
          ON CREATE SET u.name = r.name\n\
        MERGE (i:Item:%s {sku: r.sku})\n\
          ON CREATE SET i.title = r.title\n\
        MERGE (u)-[p:PURCHASE]->(i)\n\
          ON CREATE SET p.qty = r.qty, p.price = r.price, p.total = r.qty * r.price\n\
          ON MATCH  SET p.qty = p.qty + r.qty, p.total = p.total + (r.qty * r.price)"
       label label label))
    session
```

Optional: OCaml transform with Cypher pipeline
```ocaml
(* Aggregate totals per (user, item), then apply writes row‑by‑row *)
let aggregate_orders session label =
  let rows = Query_builder.execute
    (Query_builder.raw (Printf.sprintf
       "MATCH (r:RawOrder:%s)\n\
        RETURN r.u AS u, r.name AS name, r.sku AS sku, r.title AS title,\n\
               sum(r.qty) AS qty_total, sum(r.qty * r.price) AS amount_total"
       label)) session in
  match rows with
  | Error e -> Error e
  | Ok rows ->
      List.iter (fun r ->
        match Record.(at_text r "u", at_text r "name", at_text r "sku", at_text r "title", at_int r "qty_total", at_int r "amount_total") with
        | Ok u, Ok name, Ok sku, Ok title, Ok qty, Ok amount ->
            let _ = Query_builder.execute_unit
              (Query_builder.raw (Printf.sprintf
                 "MERGE (u:User:%s {username: $u}) ON CREATE SET u.name = $name\n\
                  MERGE (i:Item:%s {sku: $sku}) ON CREATE SET i.title = $title\n\
                  MERGE (u)-[p:PURCHASE]->(i)\n\
                  ON CREATE SET p.qty = $qty, p.total = $amount\n\
                  ON MATCH  SET p.qty = p.qty + $qty, p.total = p.total + $amount"
                 label label)
               |> Query_builder.with_params [
                    ("u",     Value.Text u);
                    ("name",  Value.Text name);
                    ("sku",   Value.Text sku);
                    ("title", Value.Text title);
                    ("qty",   Value.Int qty);
                    ("amount",Value.Int amount);
                  ])
              session in
            ()
        | _ -> ()
      ) rows;
      Ok ()
```

End‑to‑end ETL (transactional)
```ocaml
open Transaction_dsl

let etl_tx label =
  let open Transaction_dsl in
  let* () = exec_query_builder_unit
      (Query_builder.raw (Printf.sprintf "MATCH (n:User:%s) DETACH DELETE n" label)) in
  let* () = exec_query_builder_unit
      (Query_builder.raw (Printf.sprintf "MATCH (n:Item:%s) DETACH DELETE n" label)) in
  let* () = exec_query_builder_unit
      (Query_builder.raw (Printf.sprintf "MATCH (n:RawOrder:%s) DETACH DELETE n" label)) in
  return ()

let () =
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in
    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        let label = Printf.sprintf "ETL_%d" (Random.int 1_000_000) in

        (* Stage *)
        let _ = stage_orders session label in

        (* Load (pick one approach) *)
        let _ = load_graph_all_in_cypher session label in
        (* OR: let _ = aggregate_orders session label in *)

        (* Verify *)
        (match Query_builder.execute
           (Query_builder.raw (Printf.sprintf
              "MATCH (u:User:%s)-[p:PURCHASE]->(i:Item:%s) RETURN u.username AS user, i.sku AS sku, p.qty AS qty, p.total AS total ORDER BY user, sku"
              label label)) session with
         | Ok rows ->
             List.iter (fun r ->
               match Record.(at_text r "user", at_text r "sku", at_int r "qty", at_int r "total") with
               | Ok user, Ok sku, Ok qty, Ok total ->
                   Printf.printf "%s -> %s (qty %Ld, total %Ld)\n" user sku qty total
               | _ -> ()
             ) rows
         | Error e -> Printf.eprintf "Verify failed: %s\n" (Error.to_string e));

        (* Cleanup (transactional) *)
        let _ = run (etl_tx label) session in
        Ok ()
      ) with
      | Ok () -> ()
      | Error e -> Printf.eprintf "Session error: %s\n" (Error.to_string e)
```

Tips
- Keep data label‑scoped (e.g., `:RawOrder:ETL_123`) to simplify cleanup.
- Prefer `MERGE` for idempotent loads; use `ON CREATE SET` and `ON MATCH SET` to manage upserts.
- Use the fluent pipeline (`Cypher`) for complex in‑memory transforms; use Query Builder for writes.
