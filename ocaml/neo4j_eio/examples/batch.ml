(** Batch Operations - BETTER_API Edition

    This demonstrates batch operations and performance patterns using:
    - Query Builder DSL for declarative batch operations
    - Transaction DSL for atomic batch processing
    - UNWIND for efficient bulk inserts
*)

open Neo4j_eio

(* Example 1: UNWIND for batch inserts *)
let example_unwind_batch_insert session =
  Printf.printf "Example 1: UNWIND for batch inserts\n";

  let label = Printf.sprintf "User_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  (* Create 1000 users in a single query using UNWIND *)
  let users = List.init 1000 (fun i ->
    let open Value in
    Map (StringMap.empty
         |> StringMap.add "id" (Int (Int64.of_int i))
         |> StringMap.add "name" (Text (Printf.sprintf "User%d" i))
         |> StringMap.add "email" (Text (Printf.sprintf "user%d@example.com" i)))
  ) in

  let start_time = Unix.gettimeofday () in
  let tx =
    let* () = exec_query_builder_unit
        (Query_builder.unwind "$users" "user"
         |> Query_builder.with_params [("users", Value.List users)]
         |> Query_builder.create (Printf.sprintf "(u:%s {id: user.id, name: user.name, email: user.email})" label)) in

    let elapsed = Unix.gettimeofday () -. start_time in
    Printf.printf "  ✓ Created 1000 users in %.3f seconds using UNWIND\n" elapsed;

    (* Verify count *)
    let* records = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(u:%s)" label)
         |> Query_builder.return ["count(u) AS cnt"]) in
    (match records with
     | [record] ->
         (match Record.at_int record "cnt" with
          | Ok cnt -> Printf.printf "  ✓ Verified %Ld users in database\n" cnt
          | _ -> ());
         (* Cleanup *)
         exec_query_builder_unit
           (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
            |> Query_builder.delete ["n"])
     | _ -> return ())
  in
  (match run tx session with
   | Ok () -> Printf.printf "  ✓ Cleanup completed\n"
   | Error e -> Printf.eprintf "  ✗ Batch insert failed: %s\n" (Error.to_string e))

(* Example 2: Parameterized batch operations *)
let example_parameterized_batch session =
  Printf.printf "\nExample 2: Parameterized batch operations with MERGE\n";

  let label = Printf.sprintf "Product_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  (* Batch MERGE to avoid duplicates *)
  let products = List.init 500 (fun i ->
    let open Value in
    Map (StringMap.empty
         |> StringMap.add "sku" (Text (Printf.sprintf "SKU%d" i))
         |> StringMap.add "name" (Text (Printf.sprintf "Product %d" i))
         |> StringMap.add "price" (Float (10.0 +. float_of_int i)))
  ) in

  let start_time = Unix.gettimeofday () in
  let tx =
    let* () = exec_query_builder_unit
        (Query_builder.raw (Printf.sprintf
           "UNWIND $products AS p MERGE (prod:%s {sku: p.sku}) ON CREATE SET prod.name = p.name, prod.price = p.price ON MATCH SET prod.price = p.price"
           label)
         |> Query_builder.with_params [("products", Value.List products)]) in

    let elapsed = Unix.gettimeofday () -. start_time in
    Printf.printf "  ✓ MERGE 500 products in %.3f seconds\n" elapsed;

    (* Run again to test ON MATCH *)
    let start_time2 = Unix.gettimeofday () in
    let* () = exec_query_builder_unit
        (Query_builder.raw (Printf.sprintf
           "UNWIND $products AS p MERGE (prod:%s {sku: p.sku}) ON CREATE SET prod.name = p.name, prod.price = p.price ON MATCH SET prod.price = p.price"
           label)
         |> Query_builder.with_params [("products", Value.List products)]) in

    let elapsed2 = Unix.gettimeofday () -. start_time2 in
    Printf.printf "  ✓ Second MERGE (ON MATCH) in %.3f seconds\n" elapsed2;

    (* Cleanup *)
    exec_query_builder_unit
      (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
       |> Query_builder.delete ["n"])
  in
  (match run tx session with
   | Ok () -> Printf.printf "  ✓ Cleanup completed\n"
   | Error e -> Printf.eprintf "  ✗ Batch MERGE failed: %s\n" (Error.to_string e))

(* Example 3: Transaction batching for performance *)
let example_transaction_batching session =
  Printf.printf "\nExample 3: Transaction batching for performance\n";

  let label = Printf.sprintf "Order_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let batch_size = 100 in
  let total_orders = 500 in
  let num_batches = (total_orders + batch_size - 1) / batch_size in

  let start_time = Unix.gettimeofday () in

  let rec process_batches batch_num =
    if batch_num >= num_batches then
      return ()
    else
      let offset = batch_num * batch_size in
      let count = min batch_size (total_orders - offset) in
      let orders = List.init count (fun i ->
        let order_id = offset + i in
        let open Value in
        Map (StringMap.empty
             |> StringMap.add "order_id" (Int (Int64.of_int order_id))
             |> StringMap.add "customer" (Text (Printf.sprintf "Customer%d" (order_id mod 100)))
             |> StringMap.add "amount" (Float (100.0 +. float_of_int order_id)))
      ) in

      let* () = exec_query_builder_unit
          (Query_builder.unwind "$orders" "o"
           |> Query_builder.with_params [("orders", Value.List orders)]
           |> Query_builder.create (Printf.sprintf "(ord:%s {order_id: o.order_id, customer: o.customer, amount: o.amount})" label)) in
      process_batches (batch_num + 1)
  in

  let tx =
    let* () = process_batches 0 in
    let elapsed = Unix.gettimeofday () -. start_time in
    Printf.printf "  ✓ Created %d orders in %d batches (%.3f seconds)\n" total_orders num_batches elapsed;

    (* Cleanup *)
    exec_query_builder_unit
      (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
       |> Query_builder.delete ["n"])
  in

  (match run tx session with
   | Ok () -> Printf.printf "  ✓ Transaction committed and cleanup completed\n"
   | Error e -> Printf.eprintf "  ✗ Transaction batching failed: %s\n" (Error.to_string e))

(* Example 4: Streaming large imports *)
let example_streaming_import session =
  Printf.printf "\nExample 4: Streaming large dataset import\n";

  let label = Printf.sprintf "Event_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let total_events = 2000 in
  let batch_size = 200 in
  let num_batches = total_events / batch_size in

  let start_time = Unix.gettimeofday () in

  let rec import_batch batch_num =
    if batch_num >= num_batches then
      return ()
    else
      let offset = batch_num * batch_size in
      let events = List.init batch_size (fun i ->
        let event_id = offset + i in
        let open Value in
        Map (StringMap.empty
             |> StringMap.add "event_id" (Int (Int64.of_int event_id))
             |> StringMap.add "timestamp" (Int (Int64.add (Int64.of_float (Unix.time ())) (Int64.of_int event_id)))
             |> StringMap.add "type" (Text (if event_id mod 3 = 0 then "click" else if event_id mod 3 = 1 then "view" else "purchase")))
      ) in

      let* () = exec_query_builder_unit
          (Query_builder.unwind "$events" "e"
           |> Query_builder.with_params [("events", Value.List events)]
           |> Query_builder.create (Printf.sprintf "(ev:%s {event_id: e.event_id, timestamp: e.timestamp, type: e.type})" label)) in

      if (batch_num + 1) mod 2 = 0 then
        Printf.printf "  ✓ Imported batch %d/%d (%d events)\n" (batch_num + 1) num_batches ((batch_num + 1) * batch_size);
      import_batch (batch_num + 1)
  in

  let tx =
    let* () = import_batch 0 in
    let elapsed = Unix.gettimeofday () -. start_time in
    Printf.printf "  ✓ Imported %d events in %.3f seconds (%.0f events/sec)\n"
      total_events elapsed (float_of_int total_events /. elapsed);

    (* Cleanup *)
    exec_query_builder_unit
      (Query_builder.match_ (Printf.sprintf "(n:%s)" label)
       |> Query_builder.delete ["n"])
  in

  (match run tx session with
   | Ok () -> Printf.printf "  ✓ Cleanup completed\n"
   | Error e -> Printf.eprintf "  ✗ Streaming import failed: %s\n" (Error.to_string e))

(* Example 5: Batch relationship creation *)
let example_batch_relationship_creation session =
  Printf.printf "\nExample 5: Efficient batch relationship creation\n";

  let user_label = Printf.sprintf "User_%d" (Random.int 1000000) in
  let post_label = Printf.sprintf "Post_%d" (Random.int 1000000) in
  let open Transaction_dsl in

  let tx =
    (* Create users and posts *)
    let* () = exec_query_builder_unit
        (Query_builder.raw (Printf.sprintf "UNWIND range(1, 100) AS i CREATE (u:%s {user_id: i})" user_label)) in
    let* () = exec_query_builder_unit
        (Query_builder.raw (Printf.sprintf "UNWIND range(1, 200) AS i CREATE (p:%s {post_id: i, author_id: ((i - 1) %% 100) + 1})" post_label)) in

    Printf.printf "  ✓ Created 100 users and 200 posts\n";

    (* Create relationships efficiently *)
    let start_time = Unix.gettimeofday () in
    let* records = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(u:%s), (p:%s)" user_label post_label)
         |> Query_builder.where "u.user_id = p.author_id"
         |> Query_builder.create "(u)-[:AUTHORED]->(p)"
         |> Query_builder.return ["count(*) AS created"]) in

    let* () = (match records with
     | [record] ->
         let elapsed = Unix.gettimeofday () -. start_time in
         (match Record.at_int record "created" with
          | Ok cnt ->
              Printf.printf "  ✓ Created %Ld relationships in %.3f seconds\n" cnt elapsed;
              return ()
          | _ -> return ())
     | _ -> return ()) in

    (* Cleanup *)
    let* () = exec_query_builder_unit
        (Query_builder.match_ (Printf.sprintf "(n:%s)" user_label)
         |> Query_builder.detach_delete ["n"]) in
    exec_query_builder_unit
      (Query_builder.match_ (Printf.sprintf "(n:%s)" post_label)
       |> Query_builder.delete ["n"])
  in

  (match run tx session with
   | Ok () -> Printf.printf "  ✓ Cleanup completed\n"
   | Error e -> Printf.eprintf "  ✗ Failed: %s\n" (Error.to_string e))

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Batch Operations - BETTER_API Edition\n";
    Printf.printf "======================================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_unwind_batch_insert session;
        example_parameterized_batch session;
        example_transaction_batching session;
        example_streaming_import session;
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
          Printf.printf "  - Efficient batch relationship creation\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
