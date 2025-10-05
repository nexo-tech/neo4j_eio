open Neo4j_eio

(**
   Comprehensive examples of lens and traversal composition.

   This demonstrates Task 5.3: real-world usage patterns combining
   lenses (Task 5.1) and traversals (Task 5.2) for elegant data access.
*)

(** Example 1: Basic lens composition for nested field access *)
let example_nested_field_access session =
  Printf.printf "\nExample 1: Nested Field Access with Lenses\n";
  Printf.printf "===========================================\n";

  let label = Printf.sprintf "Person_%d" (Random.int 1000000) in

  (* Create a person node *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "CREATE (p:%s {name: 'Alice', age: 30, email: 'alice@example.com'})" label)
    |> run_in_exn session
  ) in

  (* Query and use lenses for field access *)
  let result = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p.name AS name, p.age AS age, p.email AS email" label)
    |> run_in_exn session
  ) in

  (match result with
   | [record] ->
       (* Using lens operators for clean access *)
       let open Lens in
       let name = record ^. field_text "name" in
       let age = record ^. field_int "age" in
       let email = record ^? field_text "email" in (* Optional access *)

       Printf.printf "  Name: %s\n" (Option.value name ~default:"Unknown");
       Printf.printf "  Age: %Ld\n" (Option.value age ~default:0L);
       Printf.printf "  Email: %s\n" (Option.value email ~default:"N/A");
   | _ -> Printf.printf "  Unexpected result\n");

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  ✓ Lens-based field access complete!\n"

(** Example 2: Traversals for aggregating over collections *)
let example_collection_aggregation session =
  Printf.printf "\nExample 2: Collection Aggregation with Traversals\n";
  Printf.printf "==================================================\n";

  let label = Printf.sprintf "Employee_%d" (Random.int 1000000) in

  (* Create employee data *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "UNWIND [{name: 'Alice', dept: 'Engineering', salary: 80000},
              {name: 'Bob', dept: 'Engineering', salary: 85000},
              {name: 'Charlie', dept: 'Sales', salary: 70000},
              {name: 'Diana', dept: 'Engineering', salary: 90000},
              {name: 'Eve', dept: 'Sales', salary: 75000}] AS emp
       CREATE (e:%s {name: emp.name, dept: emp.dept, salary: emp.salary})" label)
    |> run_in_exn session
  ) in

  (* Query all employees *)
  let employees = Cypher.(
    query (Printf.sprintf "MATCH (e:%s) RETURN e.name AS name, e.dept AS dept, e.salary AS salary" label)
    |> run_in_exn session
  ) in

  (* Use traversals to aggregate *)
  let open Traversal in

  (* Extract all salaries *)
  let salary_trav = records >>> Lens.field_int "salary" in
  let all_salaries = employees ^.. salary_trav in

  (* Calculate statistics *)
  let total_salary = sum_int salary_trav employees in
  let avg_salary = average_int salary_trav employees in
  let min_salary = minimum Int64.compare salary_trav employees in
  let max_salary = maximum Int64.compare salary_trav employees in

  Printf.printf "  Total employees: %d\n" (count records employees);
  Printf.printf "  All salaries: [%s]\n"
    (String.concat "; " (List.map Int64.to_string all_salaries));
  Printf.printf "  Total payroll: $%Ld\n" total_salary;
  Printf.printf "  Average salary: $%Ld\n" (Option.value avg_salary ~default:0L);
  Printf.printf "  Min salary: $%Ld\n" (Option.value min_salary ~default:0L);
  Printf.printf "  Max salary: $%Ld\n" (Option.value max_salary ~default:0L);

  (* Filter using predicates *)
  let high_earners = any (fun s -> s >= 85000L) salary_trav employees in
  Printf.printf "  Has high earners (≥$85k): %b\n" high_earners;

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  ✓ Collection aggregation complete!\n"

(** Example 3: Combining lenses with fallback values *)
let example_lens_fallbacks session =
  Printf.printf "\nExample 3: Lens Fallbacks and Alternatives\n";
  Printf.printf "==========================================\n";

  let label = Printf.sprintf "User_%d" (Random.int 1000000) in

  (* Create users with optional fields *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "CREATE (u1:%s {username: 'alice', displayName: 'Alice Wonder'}),
              (u2:%s {username: 'bob'}),
              (u3:%s {username: 'charlie', displayName: 'Charlie Brown'})"
      label label label)
    |> run_in_exn session
  ) in

  let users = Cypher.(
    query (Printf.sprintf "MATCH (u:%s) RETURN u.username AS username, u.displayName AS displayName" label)
    |> run_in_exn session
  ) in

  (* Use lens combinators for fallback logic *)
  let open Lens in

  Printf.printf "  User display names:\n";
  List.iter (fun record ->
    (* Try displayName, fall back to username *)
    let display =
      match record ^. field_text "displayName" with
      | Some name -> name
      | None -> Option.value (record ^. field_text "username") ~default:"Anonymous"
    in
    let username = Option.value (record ^. field_text "username") ~default:"unknown" in
    Printf.printf "    @%s: %s\n" username display
  ) users;

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  ✓ Lens fallback patterns complete!\n"

(** Example 4: Node property access with lenses *)
let example_node_property_lenses session =
  Printf.printf "\nExample 4: Node Property Access\n";
  Printf.printf "================================\n";

  let label = Printf.sprintf "Product_%d" (Random.int 1000000) in

  (* Create product nodes *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "CREATE (p:%s {name: 'Laptop', price: 1200, inStock: true})" label)
    |> run_in_exn session
  ) in

  (* Query returning full nodes *)
  let result = Cypher.(
    query (Printf.sprintf "MATCH (p:%s) RETURN p" label)
    |> run_in_exn session
  ) in

  (match result with
   | [record] ->
       let open Lens in
       (* Access the node value *)
       let node = record ^. field_node "p" in
       (match node with
        | Some n ->
            (* Use node-specific lenses *)
            let name = n ^. node_prop_text "name" in
            let price = n ^. node_prop_int "price" in
            let in_stock = n ^. node_prop_bool "inStock" in
            let id = n ^. node_id in
            let labels = n ^. node_labels in

            Printf.printf "  Product: %s\n" (Option.value name ~default:"Unknown");
            Printf.printf "  Price: $%Ld\n" (Option.value price ~default:0L);
            Printf.printf "  In Stock: %b\n" (Option.value in_stock ~default:false);
            Printf.printf "  Node ID: %Ld\n" (Option.value id ~default:(-1L));
            Printf.printf "  Labels: [%s]\n"
              (String.concat "; " (Option.value labels ~default:[]));
        | None -> Printf.printf "  Failed to extract node\n")
   | _ -> Printf.printf "  Unexpected result\n");

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  ✓ Node property access complete!\n"

(** Example 5: Traversal transformations and filtering *)
let example_traversal_transformations session =
  Printf.printf "\nExample 5: Traversal Transformations\n";
  Printf.printf "====================================\n";

  let label = Printf.sprintf "Score_%d" (Random.int 1000000) in

  (* Create test scores *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "UNWIND range(1, 20) AS id
       CREATE (s:%s {id: id, score: id * 5})" label)
    |> run_in_exn session
  ) in

  let scores = Cypher.(
    query (Printf.sprintf "MATCH (s:%s) RETURN s.score AS score ORDER BY s.score" label)
    |> run_in_exn session
  ) in

  let open Traversal in

  (* Various transformation operations *)
  let score_trav = records >>> Lens.field_int "score" in

  (* Filter high scores *)
  let high_scores = scores ^.. filter (fun s -> s >= 50L) score_trav in

  (* Take first 5 *)
  let top_5 = scores ^.. take 5 score_trav in

  (* Drop first 10 *)
  let after_10 = scores ^.. drop 10 score_trav in

  Printf.printf "  All scores: %d total\n" (count records scores);
  Printf.printf "  High scores (≥50): [%s]\n"
    (String.concat ", " (List.map Int64.to_string high_scores));
  Printf.printf "  First 5: [%s]\n"
    (String.concat ", " (List.map Int64.to_string top_5));
  Printf.printf "  After 10: [%s]\n"
    (String.concat ", " (List.map Int64.to_string after_10));

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  ✓ Traversal transformations complete!\n"

(** Example 6: Complex composition - nested data structures *)
let example_complex_composition session =
  Printf.printf "\nExample 6: Complex Lens/Traversal Composition\n";
  Printf.printf "=============================================\n";

  let label = Printf.sprintf "Team_%d" (Random.int 1000000) in

  (* Create teams with members *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "CREATE (t1:%s {name: 'Alpha Team', size: 5, active: true}),
              (t2:%s {name: 'Beta Team', size: 3, active: true}),
              (t3:%s {name: 'Gamma Team', size: 7, active: false})"
      label label label)
    |> run_in_exn session
  ) in

  let teams = Cypher.(
    query (Printf.sprintf
      "MATCH (t:%s) RETURN t.name AS name, t.size AS size, t.active AS active ORDER BY t.size DESC"
      label)
    |> run_in_exn session
  ) in

  let open Traversal in

  (* Complex queries with predicates *)
  let size_trav = records >>> Lens.field_int "size" in

  let total_members = sum_int size_trav teams in
  let active_teams = teams ^.. filter (fun r ->
    match Lens.(r ^. field_bool "active") with
    | Some true -> true
    | _ -> false
  ) records in

  Printf.printf "  Total teams: %d\n" (count records teams);
  Printf.printf "  Active teams: %d\n" (List.length active_teams);
  Printf.printf "  Total team members: %Ld\n" total_members;

  (* Find largest team *)
  let largest_size = maximum Int64.compare size_trav teams in
  Printf.printf "  Largest team size: %Ld\n" (Option.value largest_size ~default:0L);

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  ✓ Complex composition complete!\n"

let () =
  Random.self_init ();
  Printf.printf "Lens & Traversal Composition Examples\n";
  Printf.printf "======================================\n";
  Printf.printf "Demonstrating Tasks 5.1, 5.2, and 5.3\n";

  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
    let cfg = Config.of_env () in

    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      example_nested_field_access session;
      example_collection_aggregation session;
      example_lens_fallbacks session;
      example_node_property_lenses session;
      example_traversal_transformations session;
      example_complex_composition session;
      Ok ()
    ) with
    | Ok () ->
        Printf.printf "\n✓ All lens composition examples completed successfully!\n"
    | Error e ->
        Printf.eprintf "\n✗ Execution failed: %s\n" (Error.to_string e);
        exit 1
