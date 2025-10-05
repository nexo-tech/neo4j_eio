(* File: examples/batch.ml *)
(* Task 3.3: Demonstrates batch operations and performance patterns *)

open Neo4j_eio

(* Example 1: UNWIND for batch inserts *)
let example_unwind_batch_insert session =
  Printf.printf "Example 1: UNWIND for batch inserts\n";

  let label = Printf.sprintf "User_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create 1000 users in a single query using UNWIND *)
  let users = List.init 1000 (fun i ->
    Value.Map (props [
      "id" =: int (Int64.of_int i);
      "name" =: text (Printf.sprintf "User%d" i);
      "email" =: text (Printf.sprintf "user%d@example.com" i);
    ])
  ) in

  let start_time = Unix.gettimeofday () in
  match query_ session
    ~statement:(Printf.sprintf
      "UNWIND $users AS user CREATE (u:%s {id: user.id, name: user.name, email: user.email})"
      label)
    ~parameters:(props ["users" =: Value.List users])
    () with
  | Error e -> Printf.eprintf "  ✗ Batch insert failed: %s\n" (Error.to_string e)
  | Ok () ->
      let elapsed = Unix.gettimeofday () -. start_time in
      Printf.printf "  ✓ Created 1000 users in %.3f seconds using UNWIND\n" elapsed;

      (* Verify count *)
      (match query session
         ~statement:(Printf.sprintf "MATCH (u:%s) RETURN count(u) AS cnt" label)
         () with
       | Ok [record] ->
           (match Record.at_int record "cnt" with
            | Ok cnt -> Printf.printf "  ✓ Verified %Ld users in database\n" cnt
            | _ -> ())
       | _ -> ());

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 2: Parameterized batch operations *)
let example_parameterized_batch session =
  Printf.printf "\nExample 2: Parameterized batch operations with MERGE\n";

  let label = Printf.sprintf "Product_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Batch MERGE to avoid duplicates *)
  let products = List.init 500 (fun i ->
    Value.Map (props [
      "sku" =: text (Printf.sprintf "SKU%d" i);
      "name" =: text (Printf.sprintf "Product %d" i);
      "price" =: float (10.0 +. float_of_int i);
    ])
  ) in

  let start_time = Unix.gettimeofday () in
  match query_ session
    ~statement:(Printf.sprintf
      "UNWIND $products AS p MERGE (prod:%s {sku: p.sku}) ON CREATE SET prod.name = p.name, prod.price = p.price ON MATCH SET prod.price = p.price"
      label)
    ~parameters:(props ["products" =: Value.List products])
    () with
  | Error e -> Printf.eprintf "  ✗ Batch MERGE failed: %s\n" (Error.to_string e)
  | Ok () ->
      let elapsed = Unix.gettimeofday () -. start_time in
      Printf.printf "  ✓ MERGE 500 products in %.3f seconds\n" elapsed;

      (* Run again to test ON MATCH *)
      let start_time2 = Unix.gettimeofday () in
      (match query_ session
         ~statement:(Printf.sprintf
           "UNWIND $products AS p MERGE (prod:%s {sku: p.sku}) ON CREATE SET prod.name = p.name, prod.price = p.price ON MATCH SET prod.price = p.price"
           label)
         ~parameters:(props ["products" =: Value.List products])
         () with
       | Ok () ->
           let elapsed2 = Unix.gettimeofday () -. start_time2 in
           Printf.printf "  ✓ Second MERGE (ON MATCH) in %.3f seconds\n" elapsed2
       | Error e -> Printf.eprintf "  ✗ Second MERGE failed: %s\n" (Error.to_string e));

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 3: Transaction batching for performance *)
let example_transaction_batching session =
  Printf.printf "\nExample 3: Transaction batching for performance\n";

  let label = Printf.sprintf "Order_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create 500 orders in a single transaction with batching *)
  match Session.begin_transaction session () with
  | Error e -> Printf.eprintf "  ✗ BEGIN failed: %s\n" (Error.to_string e)
  | Ok () ->
      Printf.printf "  ✓ Transaction begun\n";

      let batch_size = 100 in
      let total_orders = 500 in
      let num_batches = (total_orders + batch_size - 1) / batch_size in

      let start_time = Unix.gettimeofday () in
      let rec process_batches batch_num =
        if batch_num >= num_batches then
          Ok ()
        else
          let offset = batch_num * batch_size in
          let count = min batch_size (total_orders - offset) in
          let orders = List.init count (fun i ->
            let order_id = offset + i in
            Value.Map (props [
              "order_id" =: int (Int64.of_int order_id);
              "customer" =: text (Printf.sprintf "Customer%d" (order_id mod 100));
              "amount" =: float (100.0 +. float_of_int order_id);
            ])
          ) in

          match query_ session
            ~statement:(Printf.sprintf
              "UNWIND $orders AS o CREATE (ord:%s {order_id: o.order_id, customer: o.customer, amount: o.amount})"
              label)
            ~parameters:(props ["orders" =: Value.List orders])
            () with
          | Error e -> Error e
          | Ok () -> process_batches (batch_num + 1)
      in

      (match process_batches 0 with
       | Error e ->
           Printf.eprintf "  ✗ Batch processing failed: %s\n" (Error.to_string e);
           let _ = Session.rollback session in ()
       | Ok () ->
           let elapsed = Unix.gettimeofday () -. start_time in
           Printf.printf "  ✓ Created %d orders in %d batches (%.3f seconds)\n" total_orders num_batches elapsed;

           (match Session.commit session with
            | Error e -> Printf.eprintf "  ✗ COMMIT failed: %s\n" (Error.to_string e)
            | Ok () ->
                Printf.printf "  ✓ Transaction committed\n";

                (* Cleanup *)
                let _ = query_ session
                  ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
                  () in
                Printf.printf "  ✓ Cleanup completed\n"))

(* Example 4: Streaming large imports *)
let example_streaming_import session =
  Printf.printf "\nExample 4: Streaming large dataset import\n";

  let label = Printf.sprintf "Event_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Import 2000 events using streaming to avoid memory issues *)
  let total_events = 2000 in
  let batch_size = 200 in
  let num_batches = total_events / batch_size in

  let start_time = Unix.gettimeofday () in
  let rec import_batch batch_num =
    if batch_num >= num_batches then
      Ok ()
    else
      let offset = batch_num * batch_size in
      let events = List.init batch_size (fun i ->
        let event_id = offset + i in
        Value.Map (props [
          "event_id" =: int (Int64.of_int event_id);
          "timestamp" =: int (Int64.add (Int64.of_float (Unix.time ())) (Int64.of_int event_id));
          "type" =: text (if event_id mod 3 = 0 then "click" else if event_id mod 3 = 1 then "view" else "purchase");
        ])
      ) in

      match query_ session
        ~statement:(Printf.sprintf
          "UNWIND $events AS e CREATE (ev:%s {event_id: e.event_id, timestamp: e.timestamp, type: e.type})"
          label)
        ~parameters:(props ["events" =: Value.List events])
        () with
      | Error e -> Error e
      | Ok () ->
          if (batch_num + 1) mod 2 = 0 then
            Printf.printf "  ✓ Imported batch %d/%d (%d events)\n" (batch_num + 1) num_batches ((batch_num + 1) * batch_size);
          import_batch (batch_num + 1)
  in

  (match import_batch 0 with
   | Error e -> Printf.eprintf "  ✗ Streaming import failed: %s\n" (Error.to_string e)
   | Ok () ->
       let elapsed = Unix.gettimeofday () -. start_time in
       Printf.printf "  ✓ Imported %d events in %.3f seconds (%.0f events/sec)\n"
         total_events elapsed (float_of_int total_events /. elapsed);

       (* Cleanup *)
       let _ = query_ session
         ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
         () in
       Printf.printf "  ✓ Cleanup completed\n")

(* Example 5: Avoiding Cartesian products *)
let example_avoiding_cartesian_products session =
  Printf.printf "\nExample 5: Avoiding Cartesian products\n";

  let label1 = Printf.sprintf "Person_%d" (Random.int 1000000) in
  let label2 = Printf.sprintf "Company_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create test data *)
  let _ = query_ session
    ~statement:(Printf.sprintf
      "UNWIND range(1, 50) AS i CREATE (p:%s {id: i, name: 'Person' + i})"
      label1)
    () in
  let _ = query_ session
    ~statement:(Printf.sprintf
      "UNWIND range(1, 50) AS i CREATE (c:%s {id: i, name: 'Company' + i})"
      label2)
    () in

  (* BAD: Cartesian product (creates 50*50 = 2500 relationships) *)
  Printf.printf "  ⚠ Bad pattern: MATCH (p), MATCH (c) would create Cartesian product\n";
  Printf.printf "  ✓ Using proper pattern instead...\n";

  (* GOOD: Using WITH and WHERE to avoid Cartesian product *)
  let start_time = Unix.gettimeofday () in
  match query_ session
    ~statement:(Printf.sprintf
      "MATCH (p:%s) WITH p MATCH (c:%s) WHERE p.id = c.id CREATE (p)-[:WORKS_AT]->(c)"
      label1 label2)
    () with
  | Error e -> Printf.eprintf "  ✗ Relationship creation failed: %s\n" (Error.to_string e)
  | Ok () ->
      let elapsed = Unix.gettimeofday () -. start_time in
      Printf.printf "  ✓ Created 50 relationships (avoiding Cartesian product) in %.3f seconds\n" elapsed;

      (* Verify relationship count *)
      (match query session
         ~statement:(Printf.sprintf "MATCH (p:%s)-[r:WORKS_AT]->(c:%s) RETURN count(r) AS cnt" label1 label2)
         () with
       | Ok [record] ->
           (match Record.at_int record "cnt" with
            | Ok cnt -> Printf.printf "  ✓ Verified %Ld relationships (expected 50, not 2500)\n" cnt
            | _ -> ())
       | _ -> ());

      (* Cleanup *)
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label1)
        () in
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label2)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 6: Index usage patterns *)
let example_index_usage session =
  Printf.printf "\nExample 6: Index usage for query performance\n";

  let label = Printf.sprintf "Customer_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create customers *)
  let customers = List.init 1000 (fun i ->
    Value.Map (props [
      "customer_id" =: int (Int64.of_int i);
      "email" =: text (Printf.sprintf "customer%d@example.com" i);
      "country" =: text (if i mod 5 = 0 then "US" else if i mod 5 = 1 then "UK" else if i mod 5 = 2 then "CA" else if i mod 5 = 3 then "DE" else "FR");
    ])
  ) in

  match query_ session
    ~statement:(Printf.sprintf
      "UNWIND $customers AS c CREATE (cust:%s {customer_id: c.customer_id, email: c.email, country: c.country})"
      label)
    ~parameters:(props ["customers" =: Value.List customers])
    () with
  | Error e -> Printf.eprintf "  ✗ Customer creation failed: %s\n" (Error.to_string e)
  | Ok () ->
      Printf.printf "  ✓ Created 1000 customers\n";

      (* Create index on email for fast lookups *)
      (match query_ session
         ~statement:(Printf.sprintf "CREATE INDEX IF NOT EXISTS FOR (c:%s) ON (c.email)" label)
         () with
       | Ok () -> Printf.printf "  ✓ Created index on email field\n"
       | Error e -> Printf.eprintf "  ✗ Index creation failed: %s\n" (Error.to_string e));

      (* Query using indexed field - should be fast *)
      let start_time = Unix.gettimeofday () in
      (match query session
         ~statement:(Printf.sprintf "MATCH (c:%s {email: $email}) RETURN c.customer_id AS id" label)
         ~parameters:(props ["email" =: text "customer500@example.com"])
         () with
       | Ok [record] ->
           let elapsed = Unix.gettimeofday () -. start_time in
           (match Record.at_int record "id" with
            | Ok id -> Printf.printf "  ✓ Found customer %Ld using index in %.6f seconds\n" id elapsed
            | _ -> ())
       | _ -> ());

      (* Range query using non-indexed field *)
      let start_time2 = Unix.gettimeofday () in
      (match query session
         ~statement:(Printf.sprintf "MATCH (c:%s {country: 'US'}) RETURN count(c) AS cnt" label)
         () with
       | Ok [record] ->
           let elapsed2 = Unix.gettimeofday () -. start_time2 in
           (match Record.at_int record "cnt" with
            | Ok cnt -> Printf.printf "  ✓ Found %Ld US customers (full scan) in %.6f seconds\n" cnt elapsed2
            | _ -> ())
       | _ -> ());

      (* Cleanup index and data *)
      let _ = query_ session
        ~statement:(Printf.sprintf "DROP INDEX ON :%s(email) IF EXISTS" label)
        () in
      let _ = query_ session
        ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
        () in
      Printf.printf "  ✓ Cleanup completed\n"

(* Example 7: Batch relationship creation with filtering *)
let example_batch_relationship_creation session =
  Printf.printf "\nExample 7: Efficient batch relationship creation\n";

  let user_label = Printf.sprintf "User_%d" (Random.int 1000000) in
  let post_label = Printf.sprintf "Post_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create users and posts *)
  let _ = query_ session
    ~statement:(Printf.sprintf "UNWIND range(1, 100) AS i CREATE (u:%s {user_id: i})" user_label)
    () in
  let _ = query_ session
    ~statement:(Printf.sprintf "UNWIND range(1, 200) AS i CREATE (p:%s {post_id: i, author_id: ((i - 1) %% 100) + 1})" post_label)
    () in

  Printf.printf "  ✓ Created 100 users and 200 posts\n";

  (* Create relationships efficiently using MATCH with WHERE *)
  let start_time = Unix.gettimeofday () in
  match query session
    ~statement:(Printf.sprintf
      "MATCH (u:%s), (p:%s) WHERE u.user_id = p.author_id CREATE (u)-[:AUTHORED]->(p) RETURN count(*) AS created"
      user_label post_label)
    () with
  | Ok [record] ->
      let elapsed = Unix.gettimeofday () -. start_time in
      (match Record.at_int record "created" with
       | Ok cnt -> Printf.printf "  ✓ Created %Ld relationships in %.3f seconds\n" cnt elapsed
       | _ -> ())
  | _ -> ();

  (* Cleanup *)
  let _ = query_ session
    ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" user_label)
    () in
  let _ = query_ session
    ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" post_label)
    () in
  Printf.printf "  ✓ Cleanup completed\n"

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Batch Operations and Performance Patterns\n";
    Printf.printf "==========================================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_unwind_batch_insert session;
        example_parameterized_batch session;
        example_transaction_batching session;
        example_streaming_import session;
        example_avoiding_cartesian_products session;
        example_index_usage session;
        example_batch_relationship_creation session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All batch operation examples completed!\n";
          Printf.printf "  Demonstrated patterns:\n";
          Printf.printf "  - UNWIND for efficient batch inserts\n";
          Printf.printf "  - Parameterized batch operations with MERGE\n";
          Printf.printf "  - Transaction batching for large datasets\n";
          Printf.printf "  - Streaming imports to manage memory\n";
          Printf.printf "  - Avoiding Cartesian products with proper MATCH patterns\n";
          Printf.printf "  - Index creation and usage for performance\n";
          Printf.printf "  - Efficient batch relationship creation\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
