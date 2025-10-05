# Real‑World Pipeline Examples

This page presents real‑world examples derived from `ocaml/test/pipeline_integration_test.ml`, showcasing end‑to‑end pipelines combining extraction, transformation, and execution.

ETL: top revenue product
```ocaml
let label = Printf.sprintf "ETL_%d" (Random.int 1_000_000) in
let result = Cypher.(
  query (Printf.sprintf
    "UNWIND [{name: 'Product A', price: 100, quantity: 5},
             {name: 'Product B', price: 50, quantity: 10},
             {name: 'Product C', price: 200, quantity: 2}] AS p
     CREATE (prod:%s {name: p.name, price: p.price, quantity: p.quantity})
     RETURN prod.name AS name, prod.price AS price, prod.quantity AS quantity" label)
  |> extract Extract.(let+ name = text "name" and+ price = int "price" and+ qty = int "quantity" in (name, price, qty))
  |> map (List.map (fun (name, price, qty) -> (name, Int64.mul price qty)))
  |> sort_by snd |> reverse |> first
  |> run_in session
)
(* Expect: Ok (Some ("Product B", 500L)) *)
```

Grouping and aggregation by department
```ocaml
let label = Printf.sprintf "Group_%d" (Random.int 1_000_000) in
let result = Cypher.(
  query (Printf.sprintf
    "UNWIND [{dept: 'Sales', emp: 'Alice', salary: 50000},
             {dept: 'Sales', emp: 'Bob', salary: 55000},
             {dept: 'IT', emp: 'Charlie', salary: 60000},
             {dept: 'IT', emp: 'Diana', salary: 65000}] AS e
     CREATE (emp:%s {dept: e.dept, name: e.emp, salary: e.salary})
     RETURN emp.dept AS dept, emp.salary AS salary" label)
  |> extract Extract.(let+ dept = text "dept" and+ salary = int "salary" in (dept, salary))
  |> group_by fst
  |> map (List.map (fun (dept, salaries) ->
       let total = List.fold_left (fun acc (_, s) -> Int64.add acc s) 0L salaries in
       (dept, total)))
  |> sort_by snd |> reverse
  |> run_in session
)
(* Expect: Ok [("IT", 125000L); ("Sales", 105000L)] *)
```

Sliding window sums
```ocaml
let label = Printf.sprintf "Window_%d" (Random.int 1_000_000) in
let result = Cypher.(
  query (Printf.sprintf "UNWIND [1, 2, 3, 4, 5] AS n CREATE (v:%s {val: n}) RETURN v.val AS val ORDER BY v.val" label)
  |> extract Extract.(int "val")
  |> sliding_window 2
  |> map (List.map (List.fold_left Int64.add 0L))
  |> run_in session
)
(* Expect: Ok [3L; 5L; 7L; 9L] *)
```

Validation + filter + take
```ocaml
let label = Printf.sprintf "Valid_%d" (Random.int 1_000_000) in
let result = Cypher.(
  query (Printf.sprintf
    "UNWIND [10, -5, 20, 0, 30, -10] AS n
     CREATE (v:%s {value: n})
     RETURN v.value AS value" label)
  |> extract Extract.(int "value")
  |> filter (fun n -> n > 0L)
  |> sort Int64.compare
  |> take 2
  |> run_in session
)
(* Expect: Ok [10L; 20L] *)
```

Deduplicate and sort
```ocaml
let label = Printf.sprintf "Dedup_%d" (Random.int 1_000_000) in
let result = Cypher.(
  query (Printf.sprintf
    "UNWIND ['apple', 'banana', 'apple', 'cherry', 'banana', 'date'] AS fruit
     CREATE (f:%s {name: fruit}) RETURN f.name AS name" label)
  |> extract Extract.(text "name")
  |> deduplicate_by (=)
  |> sort String.compare
  |> run_in session
)
(* Expect: Ok ["apple"; "banana"; "cherry"; "date"] *)
```

Batch processing with chunk
```ocaml
let label = Printf.sprintf "Batch_%d" (Random.int 1_000_000) in
let result = Cypher.(
  query (Printf.sprintf "UNWIND range(1, 10) AS n CREATE (i:%s {id: n}) RETURN i.id AS id ORDER BY i.id" label)
  |> extract Extract.(int "id")
  |> chunk 3
  |> map (List.map List.length)
  |> run_in session
)
(* Expect: Ok [3; 3; 3; 1] *)
```

Notes
- These examples are self‑cleaning in tests; remember to cleanup test labels in your apps.
- Adjust `label` to isolate temporary data, and use `MATCH (n:Label) DELETE n`.
