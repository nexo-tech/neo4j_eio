(** crud.ml - BETTER_API Edition

    This demonstrates basic CRUD operations using:
    - Query Builder DSL
    - Record.at_* for extraction
*)

open Neo4j_eio

(* Example 1: Create - Creating nodes *)
let example_create_nodes session =
  Printf.printf "Example 1: CREATE - Creating nodes\n";

  let label = Printf.sprintf "Person_%d" (Random.int 1000000) in

  (* Create a single node *)
  match Query_builder.execute
    (Query_builder.raw (Printf.sprintf "CREATE (p:%s {name: $name, age: $age}) RETURN p.name AS name, p.age AS age" label)
     |> Query_builder.with_params [
       ("name", Value.Text "Alice");
       ("age", Value.Int 30L);
     ])
    session with
  | Ok [record] ->
      (match Record.at_text record "name", Record.at_int record "age" with
       | Ok name, Ok age ->
           Printf.printf "  ✓ Created node: %s, age %Ld\n" name age
       | _ -> Printf.printf "  ✗ Decode error\n");

      (* Create another node *)
      (match Query_builder.execute
         (Query_builder.raw (Printf.sprintf "CREATE (p:%s {name: $name, age: $age}) RETURN p.name AS name" label)
          |> Query_builder.with_params [
            ("name", Value.Text "Bob");
            ("age", Value.Int 25L);
          ])
         session with
       | Ok [r] ->
           (match Record.at_text r "name" with
            | Ok name -> Printf.printf "  ✓ Created node: %s\n" name
            | _ -> ());

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
             session in
           Printf.printf "  ✓ Cleanup completed\n"
       | _ -> ())
  | _ -> Printf.printf "  ✗ Create failed\n"

(* Example 2: Create - Creating relationships *)
let example_create_relationships session =
  Printf.printf "\nExample 2: CREATE - Creating relationships\n";

  let label = Printf.sprintf "User_%d" (Random.int 1000000) in

  (* Create two nodes and a relationship *)
  match Query_builder.execute
    (Query_builder.raw (Printf.sprintf
      "CREATE (a:%s {name: 'Alice'})-[r:KNOWS {since: 2020}]->(b:%s {name: 'Bob'}) RETURN a.name AS a_name, b.name AS b_name, r.since AS since"
      label label))
    session with
  | Ok [record] ->
      (match Record.at_text record "a_name", Record.at_text record "b_name", Record.at_int record "since" with
       | Ok a, Ok b, Ok since ->
           Printf.printf "  ✓ Created relationship: %s -[KNOWS since %Ld]-> %s\n" a since b;

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label))
             session in
           Printf.printf "  ✓ Cleanup completed\n"
       | _ -> Printf.printf "  ✗ Decode error\n")
  | _ -> Printf.printf "  ✗ Create relationship failed\n"

(* Example 3: Read - MATCH patterns and RETURN *)
let example_read_match session =
  Printf.printf "\nExample 3: READ - MATCH patterns and RETURN\n";

  let label = Printf.sprintf "Product_%d" (Random.int 1000000) in

  (* Create test data *)
  match Query_builder.execute_unit
    (Query_builder.raw (Printf.sprintf
      "CREATE (p1:%s {name: 'Laptop', price: 1000}), (p2:%s {name: 'Mouse', price: 25}), (p3:%s {name: 'Keyboard', price: 75})"
      label label label))
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Read with filtering *)
      (match Query_builder.execute
         (Query_builder.raw (Printf.sprintf "MATCH (p:%s) WHERE p.price > 50 RETURN p.name AS name, p.price AS price ORDER BY p.price DESC" label))
         session with
       | Ok records ->
           Printf.printf "  ✓ Found %d products with price > 50:\n" (List.length records);
           List.iter (fun record ->
             match Record.at_text record "name", Record.at_int record "price" with
             | Ok name, Ok price -> Printf.printf "    - %s: $%Ld\n" name price
             | _ -> ()
           ) records;

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
             session in
           Printf.printf "  ✓ Cleanup completed\n"
       | Error e -> Printf.eprintf "  ✗ MATCH failed: %s\n" (Error.to_string e))

(* Example 4: Update - SET property operations *)
let example_update_set session =
  Printf.printf "\nExample 4: UPDATE - SET property operations\n";

  let label = Printf.sprintf "Employee_%d" (Random.int 1000000) in

  (* Create a node *)
  match Query_builder.execute_unit
    (Query_builder.raw (Printf.sprintf "CREATE (e:%s {name: 'Alice', role: 'Developer', salary: 80000})" label))
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Update properties *)
      (match Query_builder.execute
         (Query_builder.raw (Printf.sprintf "MATCH (e:%s {name: 'Alice'}) SET e.role = 'Senior Developer', e.salary = 100000 RETURN e.name AS name, e.role AS role, e.salary AS salary" label))
         session with
       | Ok [record] ->
           (match Record.at_text record "name", Record.at_text record "role", Record.at_int record "salary" with
            | Ok name, Ok role, Ok salary ->
                Printf.printf "  ✓ Updated %s: %s, salary $%Ld\n" name role salary;

                (* Add new property *)
                (match Query_builder.execute
                   (Query_builder.raw (Printf.sprintf "MATCH (e:%s {name: 'Alice'}) SET e.promoted = true RETURN e.promoted AS promoted" label))
                   session with
                 | Ok [r] ->
                     (match Record.at_bool r "promoted" with
                      | Ok promoted -> Printf.printf "  ✓ Added property promoted: %b\n" promoted
                      | _ -> ());

                     (* Cleanup *)
                     let _ = Query_builder.execute_unit
                       (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
                       session in
                     Printf.printf "  ✓ Cleanup completed\n"
                 | _ -> ())
            | _ -> Printf.printf "  ✗ Decode error\n")
       | _ -> Printf.printf "  ✗ UPDATE failed\n")

(* Example 5: Delete - DELETE and DETACH DELETE *)
let example_delete session =
  Printf.printf "\nExample 5: DELETE - DELETE and DETACH DELETE\n";

  let label = Printf.sprintf "Item_%d" (Random.int 1000000) in

  (* Create test data with relationships *)
  match Query_builder.execute_unit
    (Query_builder.raw (Printf.sprintf
      "CREATE (a:%s {name: 'Item A'})-[:LINKS_TO]->(b:%s {name: 'Item B'})-[:LINKS_TO]->(c:%s {name: 'Item C'})"
      label label label))
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Count initial nodes *)
      (match Query_builder.execute
         (Query_builder.raw (Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" label))
         session with
       | Ok [r] ->
           (match Record.at_int r "cnt" with
            | Ok cnt -> Printf.printf "  ✓ Created %Ld nodes with relationships\n" cnt
            | _ -> ());

           (* Delete a node without relationships using DETACH DELETE *)
           (match Query_builder.execute
              (Query_builder.raw (Printf.sprintf "MATCH (n:%s {name: 'Item C'}) DETACH DELETE n RETURN count(*) AS deleted" label))
              session with
            | Ok _ ->
                Printf.printf "  ✓ DETACH DELETE removed Item C\n";

                (* Delete remaining nodes *)
                (match Query_builder.execute
                   (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DETACH DELETE n RETURN count(*) AS deleted" label))
                   session with
                 | Ok _ -> Printf.printf "  ✓ DETACH DELETE removed remaining nodes\n"
                 | Error e -> Printf.eprintf "  ✗ DELETE failed: %s\n" (Error.to_string e))
            | Error e -> Printf.eprintf "  ✗ DELETE failed: %s\n" (Error.to_string e))
       | _ -> ())

(* Example 6: MERGE operations *)
let example_merge session =
  Printf.printf "\nExample 6: MERGE - Create or update\n";

  let label = Printf.sprintf "City_%d" (Random.int 1000000) in

  (* First MERGE creates the node *)
  match Query_builder.execute
    (Query_builder.raw (Printf.sprintf "MERGE (c:%s {name: 'Paris'}) ON CREATE SET c.country = 'France', c.created = true RETURN c.name AS name, c.created AS created" label))
    session with
  | Ok [record] ->
      (match Record.at_text record "name", Record.maybe_at_bool record "created" with
       | Ok name, Ok (Some created) ->
           Printf.printf "  ✓ MERGE created: %s (created: %b)\n" name created;

           (* Second MERGE finds existing node *)
           (match Query_builder.execute
              (Query_builder.raw (Printf.sprintf "MERGE (c:%s {name: 'Paris'}) ON MATCH SET c.updated = true RETURN c.name AS name, c.updated AS updated" label))
              session with
            | Ok [r] ->
                (match Record.at_text r "name", Record.maybe_at_bool r "updated" with
                 | Ok name, Ok (Some updated) ->
                     Printf.printf "  ✓ MERGE matched: %s (updated: %b)\n" name updated;

                     (* Cleanup *)
                     let _ = Query_builder.execute_unit
                       (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
                       session in
                     Printf.printf "  ✓ Cleanup completed\n"
                 | _ -> Printf.printf "  ✗ Decode error\n")
            | _ -> Printf.printf "  ✗ Second MERGE failed\n")
       | _ -> Printf.printf "  ✗ Decode error\n")
  | _ -> Printf.printf "  ✗ First MERGE failed\n"

(* Example 7: UNWIND for batch creates *)
let example_unwind_batch session =
  Printf.printf "\nExample 7: UNWIND - Batch create operations\n";

  let label = Printf.sprintf "Book_%d" (Random.int 1000000) in

  (* Create batch data using UNWIND *)
  match Query_builder.execute
    (Query_builder.raw (Printf.sprintf
      "UNWIND $books AS book CREATE (b:%s {title: book.title, year: book.year}) RETURN b.title AS title, b.year AS year"
      label)
     |> Query_builder.with_params [
       ("books", Value.List [
         Value.Map (Value.StringMap.of_list [
           ("title", Value.Text "1984");
           ("year", Value.Int 1949L);
         ]);
         Value.Map (Value.StringMap.of_list [
           ("title", Value.Text "Brave New World");
           ("year", Value.Int 1932L);
         ]);
         Value.Map (Value.StringMap.of_list [
           ("title", Value.Text "Fahrenheit 451");
           ("year", Value.Int 1953L);
         ]);
       ])
     ])
    session with
  | Ok records ->
      Printf.printf "  ✓ Created %d books using UNWIND:\n" (List.length records);
      List.iter (fun record ->
        match Record.at_text record "title", Record.at_int record "year" with
        | Ok title, Ok year -> Printf.printf "    - %s (%Ld)\n" title year
        | _ -> ()
      ) records;

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session in
      Printf.printf "  ✓ Cleanup completed\n"
  | Error e -> Printf.eprintf "  ✗ UNWIND batch create failed: %s\n" (Error.to_string e)

(* Example 8: Complete CRUD cycle *)
let example_complete_crud_cycle session =
  Printf.printf "\nExample 8: Complete CRUD cycle\n";

  let label = Printf.sprintf "Task_%d" (Random.int 1000000) in

  (* CREATE *)
  match Query_builder.execute
    (Query_builder.raw (Printf.sprintf "CREATE (t:%s {id: 1, title: 'Learn Neo4j', status: 'pending'}) RETURN t.id AS id" label))
    session with
  | Ok [record] ->
      (match Record.at_int record "id" with
       | Ok id ->
           Printf.printf "  ✓ CREATE: Created task with id %Ld\n" id;

           (* READ *)
           (match Query_builder.execute
              (Query_builder.raw (Printf.sprintf "MATCH (t:%s {id: 1}) RETURN t.title AS title, t.status AS status" label))
              session with
            | Ok [r] ->
                (match Record.at_text r "title", Record.at_text r "status" with
                 | Ok title, Ok status ->
                     Printf.printf "  ✓ READ: Found task '%s' with status '%s'\n" title status;

                     (* UPDATE *)
                     (match Query_builder.execute
                        (Query_builder.raw (Printf.sprintf "MATCH (t:%s {id: 1}) SET t.status = 'completed' RETURN t.status AS status" label))
                        session with
                      | Ok [ur] ->
                          (match Record.at_text ur "status" with
                           | Ok status ->
                               Printf.printf "  ✓ UPDATE: Changed status to '%s'\n" status;

                               (* DELETE *)
                               (match Query_builder.execute_unit
                                  (Query_builder.raw (Printf.sprintf "MATCH (t:%s {id: 1}) DELETE t" label))
                                  session with
                                | Ok () -> Printf.printf "  ✓ DELETE: Removed task\n"
                                | Error e -> Printf.eprintf "  ✗ DELETE failed: %s\n" (Error.to_string e))
                           | _ -> Printf.printf "  ✗ UPDATE decode error\n")
                      | _ -> Printf.printf "  ✗ UPDATE failed\n")
                 | _ -> Printf.printf "  ✗ READ decode error\n")
            | _ -> Printf.printf "  ✗ READ failed\n")
       | _ -> Printf.printf "  ✗ CREATE decode error\n")
  | _ -> Printf.printf "  ✗ CREATE failed\n"

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Basic CRUD Operations\n";
    Printf.printf "=====================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_create_nodes session;
        example_create_relationships session;
        example_read_match session;
        example_update_set session;
        example_delete session;
        example_merge session;
        example_unwind_batch session;
        example_complete_crud_cycle session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All CRUD examples completed!\n";
          Printf.printf "  Demonstrated operations:\n";
          Printf.printf "  - CREATE: Creating nodes and relationships\n";
          Printf.printf "  - READ: MATCH patterns with WHERE filtering\n";
          Printf.printf "  - UPDATE: SET operations for properties\n";
          Printf.printf "  - DELETE: DETACH DELETE for safe removal\n";
          Printf.printf "  - MERGE: Create-or-update operations\n";
          Printf.printf "  - UNWIND: Batch create operations\n";
          Printf.printf "  - Complete CRUD cycle demonstration\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
