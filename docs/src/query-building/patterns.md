# Common Query Patterns (CRUD)

This page provides copy‑pasteable patterns for common Cypher operations using the current Query Builder API. Examples mirror `ocaml/examples/crud.ml`.

Create nodes
```ocaml
let label = Printf.sprintf "Person_%d" (Random.int 1_000_000) in
let res = Query_builder.execute
  (Query_builder.raw (Printf.sprintf
     "CREATE (p:%s {name: $name, age: $age}) RETURN p.name AS name, p.age AS age"
     label)
   |> Query_builder.with_params [ ("name", Value.Text "Alice"); ("age", Value.Int 30L) ])
  session
```

Create relationships
```ocaml
let label = Printf.sprintf "User_%d" (Random.int 1_000_000) in
let res = Query_builder.execute
  (Query_builder.raw (Printf.sprintf
     {|CREATE (a:%s {name: 'Alice'})-[r:KNOWS {since: 2020}]->(b:%s {name: 'Bob'})
RETURN a.name AS a_name, b.name AS b_name, r.since AS since|}
     label label))
  session
```

Read with filtering
```ocaml
let label = Printf.sprintf "Product_%d" (Random.int 1_000_000) in
let _ = Query_builder.execute_unit
  (Query_builder.raw (Printf.sprintf
     "CREATE (p1:%s {name: 'Laptop', price: 1000}), (p2:%s {name: 'Mouse', price: 25}), (p3:%s {name: 'Keyboard', price: 75})"
     label label label)) session in
let res = Query_builder.execute
  (Query_builder.raw (Printf.sprintf
     "MATCH (p:%s) WHERE p.price > 50 RETURN p.name AS name, p.price AS price ORDER BY p.price DESC"
     label)) session
```

Update properties
```ocaml
let label = Printf.sprintf "Employee_%d" (Random.int 1_000_000) in
let _ = Query_builder.execute_unit
  (Query_builder.raw (Printf.sprintf "CREATE (e:%s {name: 'Alice', role: 'Developer', salary: 80000})" label)) session in
let res = Query_builder.execute
  (Query_builder.raw (Printf.sprintf
     "MATCH (e:%s {name: 'Alice'}) SET e.role = 'Senior Developer', e.salary = 100000 RETURN e.role AS role, e.salary AS salary"
     label)) session
```

Delete and detach delete
```ocaml
let label = Printf.sprintf "Item_%d" (Random.int 1_000_000) in
let _ = Query_builder.execute_unit
  (Query_builder.raw (Printf.sprintf
     "CREATE (a:%s {name: 'A'})-[:LINKS_TO]->(b:%s {name: 'B'})-[:LINKS_TO]->(c:%s {name: 'C'})"
     label label label)) session in
let _ = Query_builder.execute
  (Query_builder.raw (Printf.sprintf "MATCH (n:%s {name:'C'}) DETACH DELETE n RETURN 1" label)) session in
let _ = Query_builder.execute
  (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DETACH DELETE n RETURN 1" label)) session in
()
```

Merge (create or match)
```ocaml
let label = Printf.sprintf "City_%d" (Random.int 1_000_000) in
let _ = Query_builder.execute
  (Query_builder.raw (Printf.sprintf
     "MERGE (c:%s {name: 'Paris'}) ON CREATE SET c.country = 'France', c.created = true RETURN c.name AS name, c.created AS created"
     label)) session in
let _ = Query_builder.execute
  (Query_builder.raw (Printf.sprintf
     "MERGE (c:%s {name: 'Paris'}) ON MATCH SET c.updated = true RETURN c.name AS name, c.updated AS updated"
     label)) session
```

UNWIND batch create
```ocaml
let label = Printf.sprintf "Book_%d" (Random.int 1_000_000) in
let books = Value.List [
  Value.Map (Value.StringMap.of_list [ ("title", Value.Text "1984"); ("year", Value.Int 1949L) ]);
  Value.Map (Value.StringMap.of_list [ ("title", Value.Text "Brave New World"); ("year", Value.Int 1932L) ]);
  Value.Map (Value.StringMap.of_list [ ("title", Value.Text "Fahrenheit 451"); ("year", Value.Int 1953L) ]);
] in
let res = Query_builder.execute
  (Query_builder.raw (Printf.sprintf
     "UNWIND $books AS book CREATE (b:%s {title: book.title, year: book.year}) RETURN b.title AS title, b.year AS year"
     label)
   |> Query_builder.with_param ("books", books))
  session
```

Complete CRUD cycle
```ocaml
let label = Printf.sprintf "Task_%d" (Random.int 1_000_000) in
let _ = Query_builder.execute
  (Query_builder.raw (Printf.sprintf "CREATE (t:%s {id: 1, title: 'Learn Neo4j', status: 'pending'}) RETURN t.id AS id" label)) session in
let _ = Query_builder.execute
  (Query_builder.raw (Printf.sprintf "MATCH (t:%s {id: 1}) RETURN t.title AS title, t.status AS status" label)) session in
let _ = Query_builder.execute
  (Query_builder.raw (Printf.sprintf "MATCH (t:%s {id: 1}) SET t.status = 'completed' RETURN t.status AS status" label)) session in
let _ = Query_builder.execute_unit
  (Query_builder.raw (Printf.sprintf "MATCH (t:%s {id: 1}) DELETE t" label)) session
```

Tips
- Always alias return fields (`... AS name`) to keep decoding reliable.
- Prefer parameters over string interpolation; bind lists/maps via `Value.List`/`Value.Map`.
- Use `detach_delete` when nodes might have relationships.
- Clean up test data with label‑scoped `MATCH (n:Label) DETACH DELETE n`.
