(* File: examples/traversal.ml *)
(* Task 3.2: Demonstrates graph traversal patterns *)

open Neo4j_eio

(* Example 1: Variable-length paths - Friend of friend *)
let example_variable_length_paths session =
  Printf.printf "Example 1: Variable-length paths (1 to 3 hops)\n";

  let label = Printf.sprintf "Person_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create a social network: Alice -> Bob -> Charlie -> David *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (a:%s {name: 'Alice'})-[:KNOWS]->(b:%s {name: 'Bob'})-[:KNOWS]->(c:%s {name: 'Charlie'})-[:KNOWS]->(d:%s {name: 'David'})"
      label label label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Find all people within 1-3 hops from Alice *)
      (match query session
         ~statement:(Printf.sprintf "MATCH (start:%s {name: 'Alice'})-[:KNOWS*1..3]->(connected:%s) RETURN DISTINCT connected.name AS name ORDER BY name" label label)
         () with
       | Ok records ->
           Printf.printf "  ✓ Alice is connected to %d people within 3 hops:\n" (List.length records);
           List.iter (fun record ->
             match Record.at_text record "name" with
             | Ok name -> Printf.printf "    - %s\n" name
             | _ -> ()
           ) records;

           (* Cleanup *)
           let _ = query_ session
             ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
             () in
           Printf.printf "  ✓ Cleanup completed\n"
       | Error e -> Printf.eprintf "  ✗ Variable-length path query failed: %s\n" (Error.to_string e))

(* Example 2: Shortest path between two nodes *)
let example_shortest_path session =
  Printf.printf "\nExample 2: Shortest path between nodes\n";

  let label = Printf.sprintf "City_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create a route network *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (sf:%s {name: 'San Francisco'}), (la:%s {name: 'Los Angeles'}), (vegas:%s {name: 'Las Vegas'}), (phoenix:%s {name: 'Phoenix'}), (sf)-[:ROUTE {distance: 380}]->(la), (sf)-[:ROUTE {distance: 570}]->(vegas), (vegas)-[:ROUTE {distance: 420}]->(la), (vegas)-[:ROUTE {distance: 300}]->(phoenix), (la)-[:ROUTE {distance: 370}]->(phoenix)"
      label label label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Find shortest path from San Francisco to Phoenix *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH (start:%s {name: 'San Francisco'}), (end:%s {name: 'Phoenix'}), p = shortestPath((start)-[:ROUTE*]-(end)) RETURN [n IN nodes(p) | n.name] AS cities, length(p) AS hops"
           label label)
         () with
       | Ok [record] ->
           (match Record.at_list Record.exact_text record "cities", Record.at_int record "hops" with
            | Ok cities, Ok hops ->
                Printf.printf "  ✓ Shortest path from SF to Phoenix (%Ld hops):\n" hops;
                Printf.printf "    Route: %s\n" (String.concat " -> " cities)
            | _ -> Printf.printf "  ✗ Decode error\n")
       | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
       | Error e -> Printf.eprintf "  ✗ Shortest path query failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 3: Pattern comprehension - collecting related data *)
let example_pattern_comprehension session =
  Printf.printf "\nExample 3: Pattern comprehension\n";

  let label = Printf.sprintf "User_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create users with projects *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (alice:%s {name: 'Alice'}), (bob:%s {name: 'Bob'}), (proj1:Project {name: 'API'}), (proj2:Project {name: 'UI'}), (proj3:Project {name: 'Database'}), (alice)-[:WORKS_ON]->(proj1), (alice)-[:WORKS_ON]->(proj2), (bob)-[:WORKS_ON]->(proj2), (bob)-[:WORKS_ON]->(proj3)"
      label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Use pattern comprehension to collect projects per user *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH (u:%s) RETURN u.name AS user, [(u)-[:WORKS_ON]->(p:Project) | p.name] AS projects"
           label)
         () with
       | Ok records ->
           Printf.printf "  ✓ User projects (using pattern comprehension):\n";
           List.iter (fun record ->
             match Record.at_text record "user", Record.at_list Record.exact_text record "projects" with
             | Ok user, Ok projects ->
                 Printf.printf "    %s works on: %s\n" user (String.concat ", " projects)
             | _ -> ()
           ) records
       | Error e -> Printf.eprintf "  ✗ Pattern comprehension query failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      let _ = query_ session
        ~statement:"MATCH (n:Project) DETACH DELETE n"
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 4: OPTIONAL MATCH - handling missing relationships *)
let example_optional_match session =
  Printf.printf "\nExample 4: OPTIONAL MATCH (handling missing relationships)\n";

  let label = Printf.sprintf "Employee_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create employees with and without managers *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (ceo:%s {name: 'CEO', role: 'Chief'}), (dev:%s {name: 'Developer', role: 'Dev'}), (intern:%s {name: 'Intern', role: 'Intern'}), (dev)-[:REPORTS_TO]->(ceo)"
      label label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Use OPTIONAL MATCH to find manager (may not exist) *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH (e:%s) OPTIONAL MATCH (e)-[:REPORTS_TO]->(manager:%s) RETURN e.name AS name, e.role AS role, manager.name AS manager_name ORDER BY name"
           label label)
         () with
       | Ok records ->
           Printf.printf "  ✓ Employee hierarchy:\n";
           List.iter (fun record ->
             match Record.at_text record "name", Record.at_text record "role", Record.maybe_at_text record "manager_name" with
             | Ok name, Ok role, Ok manager_opt ->
                 (match manager_opt with
                  | Some manager -> Printf.printf "    %s (%s) reports to %s\n" name role manager
                  | None -> Printf.printf "    %s (%s) has no manager\n" name role)
             | _ -> ()
           ) records
       | Error e -> Printf.eprintf "  ✗ OPTIONAL MATCH query failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 5: Collecting aggregated results *)
let example_collect_aggregation session =
  Printf.printf "\nExample 5: Collecting and aggregating results\n";

  let label = Printf.sprintf "Author_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create authors and books *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (a1:%s {name: 'Author A'}), (a2:%s {name: 'Author B'}), (b1:Book {title: 'Book 1', year: 2020}), (b2:Book {title: 'Book 2', year: 2021}), (b3:Book {title: 'Book 3', year: 2022}), (a1)-[:WROTE]->(b1), (a1)-[:WROTE]->(b2), (a2)-[:WROTE]->(b3)"
      label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Collect books per author with count and years *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH (a:%s)-[:WROTE]->(b:Book) RETURN a.name AS author, count(b) AS book_count, collect(b.title) AS titles, collect(b.year) AS years ORDER BY book_count DESC"
           label)
         () with
       | Ok records ->
           Printf.printf "  ✓ Author statistics:\n";
           List.iter (fun record ->
             match Record.at_text record "author", Record.at_int record "book_count", Record.at_list Record.exact_text record "titles", Record.at_list Record.exact_int record "years" with
             | Ok author, Ok count, Ok titles, Ok years ->
                 Printf.printf "    %s: %Ld books\n" author count;
                 List.iter2 (fun title year ->
                   Printf.printf "      - %s (%Ld)\n" title year
                 ) titles years
             | _ -> ()
           ) records
       | Error e -> Printf.eprintf "  ✗ Collect query failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      let _ = query_ session
        ~statement:"MATCH (n:Book) DETACH DELETE n"
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 6: All shortest paths (multiple paths with same length) *)
let example_all_shortest_paths session =
  Printf.printf "\nExample 6: All shortest paths\n";

  let label = Printf.sprintf "Node_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create a graph with multiple shortest paths *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (a:%s {name: 'A'}), (b:%s {name: 'B'}), (c:%s {name: 'C'}), (d:%s {name: 'D'}), (a)-[:CONNECTED]->(b)-[:CONNECTED]->(d), (a)-[:CONNECTED]->(c)-[:CONNECTED]->(d)"
      label label label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Find all shortest paths from A to D *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH (start:%s {name: 'A'}), (end:%s {name: 'D'}), p = allShortestPaths((start)-[:CONNECTED*]-(end)) RETURN [n IN nodes(p) | n.name] AS path"
           label label)
         () with
       | Ok records ->
           Printf.printf "  ✓ Found %d shortest paths from A to D:\n" (List.length records);
           List.iteri (fun i record ->
             match Record.at_list Record.exact_text record "path" with
             | Ok path -> Printf.printf "    Path %d: %s\n" (i + 1) (String.concat " -> " path)
             | _ -> ()
           ) records
       | Error e -> Printf.eprintf "  ✗ All shortest paths query failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 7: Graph pathfinding with relationship properties *)
let example_weighted_pathfinding session =
  Printf.printf "\nExample 7: Weighted pathfinding (using relationship properties)\n";

  let label = Printf.sprintf "Location_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create a weighted graph *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (a:%s {name: 'A'}), (b:%s {name: 'B'}), (c:%s {name: 'C'}), (d:%s {name: 'D'}), (a)-[:PATH {cost: 1}]->(b), (b)-[:PATH {cost: 1}]->(d), (a)-[:PATH {cost: 2}]->(c), (c)-[:PATH {cost: 2}]->(d)"
      label label label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Find path and calculate total cost *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH p = (start:%s {name: 'A'})-[:PATH*]->(end:%s {name: 'D'}) RETURN [n IN nodes(p) | n.name] AS path, reduce(total = 0, r IN relationships(p) | total + r.cost) AS total_cost ORDER BY total_cost LIMIT 1"
           label label)
         () with
       | Ok [record] ->
           (match Record.at_list Record.exact_text record "path", Record.at_int record "total_cost" with
            | Ok path, Ok cost ->
                Printf.printf "  ✓ Lowest cost path (cost=%Ld): %s\n" cost (String.concat " -> " path)
            | _ -> Printf.printf "  ✗ Decode error\n")
       | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
       | Error e -> Printf.eprintf "  ✗ Weighted pathfinding query failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 8: Breadth-first traversal pattern *)
let example_breadth_first_traversal session =
  Printf.printf "\nExample 8: Breadth-first traversal with depth tracking\n";

  let label = Printf.sprintf "TreeNode_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create a tree structure *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (root:%s {name: 'Root'}), (l1a:%s {name: 'L1-A'}), (l1b:%s {name: 'L1-B'}), (l2a:%s {name: 'L2-A'}), (l2b:%s {name: 'L2-B'}), (l2c:%s {name: 'L2-C'}), (root)-[:CHILD]->(l1a), (root)-[:CHILD]->(l1b), (l1a)-[:CHILD]->(l2a), (l1a)-[:CHILD]->(l2b), (l1b)-[:CHILD]->(l2c)"
      label label label label label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Traverse tree with depth information *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH path = (root:%s {name: 'Root'})-[:CHILD*0..]->(node:%s) RETURN node.name AS name, length(path) AS depth ORDER BY depth, name"
           label label)
         () with
       | Ok records ->
           Printf.printf "  ✓ Tree traversal (breadth-first order):\n";
           List.iter (fun record ->
             match Record.at_text record "name", Record.at_int record "depth" with
             | Ok name, Ok depth ->
                 let indent = String.make (Int64.to_int depth * 2) ' ' in
                 Printf.printf "    %s%s (depth %Ld)\n" indent name depth
             | _ -> ()
           ) records
       | Error e -> Printf.eprintf "  ✗ Breadth-first traversal failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 9: Finding cycles in a graph *)
let example_cycle_detection session =
  Printf.printf "\nExample 9: Cycle detection\n";

  let label = Printf.sprintf "Process_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create a graph with a cycle *)
  match query_ session
    ~statement:(Printf.sprintf
      "CREATE (a:%s {name: 'A'}), (b:%s {name: 'B'}), (c:%s {name: 'C'}), (a)-[:DEPENDS_ON]->(b), (b)-[:DEPENDS_ON]->(c), (c)-[:DEPENDS_ON]->(a)"
      label label label)
    () with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Detect cycles by finding paths that return to start *)
      (match query session
         ~statement:(Printf.sprintf
           "MATCH (start:%s)-[:DEPENDS_ON*]->(start) RETURN DISTINCT start.name AS cycle_node"
           label)
         () with
       | Ok records ->
           if List.length records > 0 then begin
             Printf.printf "  ✓ Detected cycle involving nodes:\n";
             List.iter (fun record ->
               match Record.at_text record "cycle_node" with
               | Ok name -> Printf.printf "    - %s\n" name
               | _ -> ()
             ) records
           end else
             Printf.printf "  ✓ No cycles detected\n"
       | Error e -> Printf.eprintf "  ✗ Cycle detection query failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Graph Traversal Patterns\n";
    Printf.printf "========================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_variable_length_paths session;
        example_shortest_path session;
        example_pattern_comprehension session;
        example_optional_match session;
        example_collect_aggregation session;
        example_all_shortest_paths session;
        example_weighted_pathfinding session;
        example_breadth_first_traversal session;
        example_cycle_detection session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All traversal examples completed!\n";
          Printf.printf "  Demonstrated patterns:\n";
          Printf.printf "  - Variable-length paths ([:KNOWS*1..3])\n";
          Printf.printf "  - Shortest path queries (shortestPath)\n";
          Printf.printf "  - Pattern comprehension for collecting data\n";
          Printf.printf "  - OPTIONAL MATCH for missing relationships\n";
          Printf.printf "  - Collecting and aggregating results\n";
          Printf.printf "  - All shortest paths (allShortestPaths)\n";
          Printf.printf "  - Weighted pathfinding with relationship properties\n";
          Printf.printf "  - Breadth-first traversal with depth tracking\n";
          Printf.printf "  - Cycle detection in graphs\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
