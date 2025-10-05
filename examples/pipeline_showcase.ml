open Neo4j_eio

(**
   Comprehensive pipeline showcase demonstrating the complete fluent API.
   This combines pipeline operators (Task 4.1) with transformations (Task 4.2)
   to show real-world query composition patterns.
*)

(* Example 1: E-commerce Order Processing Pipeline *)
let example_ecommerce_pipeline session =
  Printf.printf "\nExample 1: E-commerce Order Processing\n";
  Printf.printf "=========================================\n";

  let label = Printf.sprintf "Order_%d" (Random.int 1000000) in

  (* Create sample orders *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "UNWIND [{id: 1, customer: 'Alice', amount: 150.0, status: 'pending'},
              {id: 2, customer: 'Bob', amount: 75.0, status: 'completed'},
              {id: 3, customer: 'Alice', amount: 200.0, status: 'pending'},
              {id: 4, customer: 'Charlie', amount: 50.0, status: 'completed'},
              {id: 5, customer: 'Alice', amount: 125.0, status: 'pending'}] AS order
       CREATE (o:%s {id: order.id, customer: order.customer, amount: order.amount, status: order.status})" label)
    |> run_in_exn session
  ) in

  (* Pipeline: Get pending orders, group by customer, calculate totals *)
  let customer_totals = Cypher.(
    query (Printf.sprintf "MATCH (o:%s {status: 'pending'}) RETURN o.customer AS customer, o.amount AS amount" label)
    |> extract Extract.(
      let+ customer = text "customer"
      and+ amount = float "amount" in
      (customer, amount)
    )
    |> group_by fst
    |> map (List.map (fun (customer, orders) ->
      let total = List.fold_left (fun acc (_, amt) -> acc +. amt) 0.0 orders in
      (customer, total, List.length orders)
    ))
    |> sort_by (fun (_, total, _) -> -.total)
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Top customers by pending order value:\n";
  List.iter (fun (customer, total, count) ->
    Printf.printf "    %s: $%.2f (%d orders)\n" customer total count
  ) customer_totals;
  Printf.printf "  ✓ E-commerce pipeline complete!\n"

(* Example 2: Log Analysis Pipeline *)
let example_log_analysis_pipeline session =
  Printf.printf "\nExample 2: Log Analysis Pipeline\n";
  Printf.printf "==================================\n";

  let label = Printf.sprintf "Log_%d" (Random.int 1000000) in

  (* Create sample logs *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "UNWIND [{level: 'ERROR', msg: 'Database connection failed'},
              {level: 'INFO', msg: 'Server started'},
              {level: 'ERROR', msg: 'Null pointer exception'},
              {level: 'WARN', msg: 'Slow query detected'},
              {level: 'ERROR', msg: 'Timeout exception'},
              {level: 'INFO', msg: 'Request completed'}] AS log
       CREATE (l:%s {level: log.level, message: log.msg})" label)
    |> run_in_exn session
  ) in

  (* Pipeline: Extract errors, deduplicate, sort *)
  let error_summary = Cypher.(
    query (Printf.sprintf "MATCH (l:%s) RETURN l.level AS level, l.message AS msg" label)
    |> extract Extract.(
      let+ level = text "level"
      and+ msg = text "msg" in
      (level, msg)
    )
    |> filter (fun (level, _) -> level = "ERROR")
    |> map (List.map snd)
    |> deduplicate_by (=)
    |> sort String.compare
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Unique error messages:\n";
  List.iter (fun msg -> Printf.printf "    - %s\n" msg) error_summary;
  Printf.printf "  ✓ Log analysis complete!\n"

(* Example 3: Social Network Analysis *)
let example_social_network_pipeline session =
  Printf.printf "\nExample 3: Social Network Analysis\n";
  Printf.printf "===================================\n";

  let label = Printf.sprintf "User_%d" (Random.int 1000000) in

  (* Create sample social network *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "CREATE (a:%s {name: 'Alice', followers: 1500}),
              (b:%s {name: 'Bob', followers: 800}),
              (c:%s {name: 'Charlie', followers: 2000}),
              (d:%s {name: 'Diana', followers: 500}),
              (e:%s {name: 'Eve', followers: 1200})"
      label label label label label)
    |> run_in_exn session
  ) in

  (* Pipeline: Get users, calculate tiers, format output *)
  let user_tiers = Cypher.(
    query (Printf.sprintf "MATCH (u:%s) RETURN u.name AS name, u.followers AS followers" label)
    |> extract Extract.(
      let+ name = text "name"
      and+ followers = int "followers" in
      (name, followers)
    )
    |> map (List.map (fun (name, followers) ->
      let tier =
        if followers >= 2000L then "Influencer"
        else if followers >= 1000L then "Popular"
        else "Regular"
      in
      (name, Int64.to_int followers, tier)
    ))
    |> sort_by (fun (_, followers, _) -> -followers)
    |> indexed
    |> map (List.map (fun (rank, (name, followers, tier)) ->
      Printf.sprintf "#%d %s (%d followers) - %s" (rank + 1) name followers tier
    ))
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  User rankings:\n";
  List.iter (fun line -> Printf.printf "    %s\n" line) user_tiers;
  Printf.printf "  ✓ Social network analysis complete!\n"

(* Example 4: Time Series Data Processing *)
let example_timeseries_pipeline session =
  Printf.printf "\nExample 4: Time Series Moving Average\n";
  Printf.printf "======================================\n";

  let label = Printf.sprintf "Metric_%d" (Random.int 1000000) in

  (* Create sample time series data *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "UNWIND range(1, 10) AS t
       CREATE (m:%s {time: t, value: t * t})" label)
    |> run_in_exn session
  ) in

  (* Pipeline: Get metrics, calculate moving average with window size 3 *)
  let moving_avg = Cypher.(
    query (Printf.sprintf "MATCH (m:%s) RETURN m.time AS time, m.value AS value ORDER BY m.time" label)
    |> extract Extract.(
      let+ time = int "time"
      and+ value = int "value" in
      (time, value)
    )
    |> sliding_window 3
    |> map (List.map (fun window ->
      let times = List.map fst window in
      let values = List.map snd window in
      let avg = List.fold_left Int64.add 0L values
                |> fun sum -> Int64.div sum (Int64.of_int (List.length values)) in
      let mid_time = List.nth times (List.length times / 2) in
      (mid_time, avg)
    ))
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Moving average (window=3):\n";
  List.iter (fun (time, avg) ->
    Printf.printf "    Time %Ld: %Ld\n" time avg
  ) moving_avg;
  Printf.printf "  ✓ Time series processing complete!\n"

(* Example 5: Data Validation Pipeline *)
let example_validation_pipeline session =
  Printf.printf "\nExample 5: Data Validation Pipeline\n";
  Printf.printf "====================================\n";

  let label = Printf.sprintf "Record_%d" (Random.int 1000000) in

  (* Create sample records with some invalid data *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "UNWIND [{id: 1, email: 'alice@example.com', age: 25},
              {id: 2, email: 'invalid', age: 30},
              {id: 3, email: 'bob@example.com', age: -5},
              {id: 4, email: 'charlie@example.com', age: 35}] AS rec
       CREATE (r:%s {id: rec.id, email: rec.email, age: rec.age})" label)
    |> run_in_exn session
  ) in

  (* Pipeline: Extract, validate, report issues *)
  let validation_report = Cypher.(
    query (Printf.sprintf "MATCH (r:%s) RETURN r.id AS id, r.email AS email, r.age AS age" label)
    |> extract Extract.(
      let+ id = int "id"
      and+ email = text "email"
      and+ age = int "age" in
      (id, email, age)
    )
    |> map (List.filter_map (fun (id, email, age) ->
      let issues = [] in
      let issues = if not (String.contains email '@') then "Invalid email" :: issues else issues in
      let issues = if age < 0L then "Invalid age" :: issues else issues in
      if issues = [] then None
      else Some (id, String.concat ", " issues)
    ))
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Validation issues:\n";
  if validation_report = [] then
    Printf.printf "    No issues found!\n"
  else
    List.iter (fun (id, issues) ->
      Printf.printf "    Record %Ld: %s\n" id issues
    ) validation_report;
  Printf.printf "  ✓ Validation complete!\n"

(* Example 6: Batch Processing Pipeline *)
let example_batch_processing session =
  Printf.printf "\nExample 6: Batch Processing\n";
  Printf.printf "============================\n";

  let label = Printf.sprintf "Item_%d" (Random.int 1000000) in

  (* Create items *)
  let _ = Cypher.(
    query_unit (Printf.sprintf
      "UNWIND range(1, 20) AS n
       CREATE (i:%s {id: n, processed: false})" label)
    |> run_in_exn session
  ) in

  (* Pipeline: Get items, batch into groups of 5, process *)
  let batch_summary = Cypher.(
    query (Printf.sprintf "MATCH (i:%s) RETURN i.id AS id ORDER BY i.id" label)
    |> extract Extract.(int "id")
    |> chunk 5
    |> map (List.mapi (fun batch_num items ->
      (batch_num + 1, List.length items, List.hd items, List.hd (List.rev items))
    ))
    |> run_in_exn session
  ) in

  let _ = Cypher.(
    query_unit (Printf.sprintf "MATCH (n:%s) DELETE n" label)
    |> run_in session
  ) in

  Printf.printf "  Batch processing summary:\n";
  List.iter (fun (batch_num, size, first, last) ->
    Printf.printf "    Batch %d: %d items (IDs %Ld-%Ld)\n" batch_num size first last
  ) batch_summary;
  Printf.printf "  ✓ Batch processing complete!\n"

let () =
  Random.self_init ();
  Printf.printf "Pipeline Showcase: Real-World Examples\n";
  Printf.printf "======================================\n";
  Printf.printf "Demonstrating Task 4.1 (operators) + Task 4.2 (transformations)\n";

  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
    let cfg = Config.of_env () in

    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      example_ecommerce_pipeline session;
      example_log_analysis_pipeline session;
      example_social_network_pipeline session;
      example_timeseries_pipeline session;
      example_validation_pipeline session;
      example_batch_processing session;
      Ok ()
    ) with
    | Ok () ->
        Printf.printf "\n✓ All pipeline showcase examples completed successfully!\n"
    | Error e ->
        Printf.eprintf "\n✗ Execution failed: %s\n" (Error.to_string e);
        exit 1
