(** Performance benchmarks for neo4j_eio library

    This benchmark suite tests the performance of key operations:
    - PackStream encoding/decoding
    - Query execution (simple, parameterized, batch)
    - Transaction operations
    - Streaming vs materialized queries
    - Record extraction performance
*)

open Neo4j_eio

(* Benchmark utilities *)
let time_operation name f =
  let start = Unix.gettimeofday () in
  let result = f () in
  let elapsed = Unix.gettimeofday () -. start in
  Printf.printf "%-50s: %.6f seconds\n" name elapsed;
  result

let benchmark name iterations f =
  let start = Unix.gettimeofday () in
  for _i = 1 to iterations do
    ignore (f ())
  done;
  let elapsed = Unix.gettimeofday () -. start in
  let per_op = elapsed /. float_of_int iterations in
  Printf.printf "%-50s: %d iterations in %.6f sec (%.6f sec/op, %.0f ops/sec)\n"
    name iterations elapsed per_op (1.0 /. per_op)

(* PackStream encoding/decoding benchmarks *)
let bench_packstream () =
  Printf.printf "\n=== PackStream Encoding/Decoding ===\n";

  (* Small value *)
  let small_value = Value.Int 42L in
  benchmark "Encode small Int (42)" 10000 (fun () ->
    Packstream.encode_value small_value
  );

  (* Large list *)
  let large_list = Value.List (List.init 1000 (fun i -> Value.Int (Int64.of_int i))) in
  benchmark "Encode list of 1000 ints" 1000 (fun () ->
    Packstream.encode_value large_list
  );

  (* Large map *)
  let large_map = Value.Map (
    List.fold_left (fun acc i ->
      Value.StringMap.add (Printf.sprintf "key%d" i) (Value.Int (Int64.of_int i)) acc
    ) Value.StringMap.empty (List.init 100 (fun i -> i))
  ) in
  benchmark "Encode map with 100 entries" 1000 (fun () ->
    Packstream.encode_value large_map
  );

  (* Text value *)
  let text_value = Value.Text (String.make 1000 'x') in
  benchmark "Encode 1KB text string" 1000 (fun () ->
    Packstream.encode_value text_value
  )

(* Query execution benchmarks *)
let bench_queries env cfg =
  Printf.printf "\n=== Query Execution ===\n";

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "BenchNode_%d" (Random.int 1000000) in

      (* Simple query benchmark *)
      time_operation "Simple RETURN query" (fun () ->
        match Query_builder.execute
          (Query_builder.raw "RETURN 1 AS n")
          session with
        | Ok _ -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Parameterized query *)
      time_operation "Parameterized query" (fun () ->
        match Query_builder.execute
          (Query_builder.raw "RETURN $value AS n"
           |> Query_builder.with_params [("value", Value.Int 42L)])
          session with
        | Ok _ -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Create test data for batch operations *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "UNWIND range(1, 100) AS i CREATE (n:%s {id: i})" label))
        session in

      (* Query with filtering *)
      time_operation "Query with WHERE clause (100 nodes)" (fun () ->
        match Query_builder.execute
          (Query_builder.raw (Printf.sprintf "MATCH (n:%s) WHERE n.id > 50 RETURN n.id" label))
          session with
        | Ok _ -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Aggregation query *)
      time_operation "Aggregation query (count)" (fun () ->
        match Query_builder.execute
          (Query_builder.raw (Printf.sprintf "MATCH (n:%s) RETURN count(n) AS cnt" label))
          session with
        | Ok _ -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session in

      Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Printf.eprintf "Session error: %s\n" (Error.to_string e)

(* Batch operations benchmark *)
let bench_batch_operations env cfg =
  Printf.printf "\n=== Batch Operations ===\n";

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "BatchNode_%d" (Random.int 1000000) in

      (* Batch create with UNWIND *)
      time_operation "Batch create 1000 nodes (UNWIND)" (fun () ->
        match Query_builder.execute_unit
          (Query_builder.raw (Printf.sprintf "UNWIND range(1, 1000) AS i CREATE (n:%s {id: i})" label))
          session with
        | Ok () -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Batch update *)
      time_operation "Batch update 1000 nodes (SET)" (fun () ->
        match Query_builder.execute_unit
          (Query_builder.raw (Printf.sprintf "MATCH (n:%s) SET n.updated = true" label))
          session with
        | Ok () -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Batch delete *)
      time_operation "Batch delete 1000 nodes" (fun () ->
        match Query_builder.execute_unit
          (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
          session with
        | Ok () -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Printf.eprintf "Session error: %s\n" (Error.to_string e)

(* Transaction performance *)
let bench_transactions env cfg =
  Printf.printf "\n=== Transaction Performance ===\n";

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "TxNode_%d" (Random.int 1000000) in
      let open Transaction_dsl in

      (* Single transaction with multiple operations *)
      time_operation "Transaction with 10 CREATE operations" (fun () ->
        let rec create_nodes n =
          if n <= 0 then return ()
          else
            let* () = exec_query_builder_unit
              (Query_builder.raw (Printf.sprintf "CREATE (n:%s {id: %d})" label n)) in
            create_nodes (n - 1)
        in
        match run (create_nodes 10) session with
        | Ok () -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Transaction with rollback *)
      time_operation "Transaction with explicit rollback" (fun () ->
        let tx =
          let* () = exec_query_builder_unit
            (Query_builder.raw (Printf.sprintf "CREATE (n:%s {id: 999})" label)) in
          rollback
        in
        match run tx session with
        | Ok () -> ()
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session in

      Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Printf.eprintf "Session error: %s\n" (Error.to_string e)

(* Streaming vs materialized queries *)
let bench_streaming env cfg =
  Printf.printf "\n=== Streaming vs Materialized ===\n";

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      let label = Printf.sprintf "StreamNode_%d" (Random.int 1000000) in

      (* Create test data *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "UNWIND range(1, 1000) AS i CREATE (n:%s {id: i})" label))
        session in

      (* Materialized query *)
      time_operation "Materialized query (1000 records)" (fun () ->
        match Query_builder.execute
          (Query_builder.raw (Printf.sprintf "MATCH (n:%s) RETURN n.id" label))
          session with
        | Ok records -> Printf.printf "  → Loaded %d records\n" (List.length records)
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Streaming query *)
      time_operation "Streaming query (1000 records, fetch_size=100)" (fun () ->
        match Session.run_stream_records session
          ~statement:(Printf.sprintf "MATCH (n:%s) RETURN n.id" label)
          ~fetch_size:100L
          () with
        | Ok stream ->
            let rec consume count =
              if stream.exhausted then count
              else
                match stream.fetch_next_records () with
                | Ok chunk -> consume (count + List.length chunk)
                | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e); count
            in
            let total = consume 0 in
            Printf.printf "  → Streamed %d records\n" total
        | Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
      );

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw (Printf.sprintf "MATCH (n:%s) DELETE n" label))
        session in

      Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Printf.eprintf "Session error: %s\n" (Error.to_string e)

(* Record extraction benchmarks *)
let bench_extraction () =
  Printf.printf "\n=== Record Extraction ===\n";

  (* Create a sample record *)
  let record = Value.StringMap.empty
    |> Value.StringMap.add "name" (Value.Text "Alice")
    |> Value.StringMap.add "age" (Value.Int 30L)
    |> Value.StringMap.add "email" (Value.Text "alice@example.com")
    |> Value.StringMap.add "active" (Value.Bool true)
  in

  benchmark "Record.at_text extraction" 10000 (fun () ->
    match Record.at_text record "name" with
    | Ok _ -> ()
    | Error _ -> ()
  );

  benchmark "Record.at_int extraction" 10000 (fun () ->
    match Record.at_int record "age" with
    | Ok _ -> ()
    | Error _ -> ()
  );

  (* Extract combinator *)
  let extractor = Extract.(
    let+ name = text "name"
    and+ age = int "age"
    and+ email = text "email" in
    (name, age, email)
  ) in

  benchmark "Extract combinator (3 fields)" 10000 (fun () ->
    match Extract.run extractor record with
    | Ok _ -> ()
    | Error _ -> ()
  )

(* Main benchmark runner *)
let () =
  Random.self_init ();
  Printf.printf "Neo4j_eio Performance Benchmarks\n";
  Printf.printf "==================================\n";

  (* PackStream benchmarks (no DB required) *)
  bench_packstream ();
  bench_extraction ();

  (* Database benchmarks (require Neo4j) *)
  let cfg = Config.of_env () in
  Eio_main.run @@ fun env ->
    bench_queries env cfg;
    bench_batch_operations env cfg;
    bench_transactions env cfg;
    bench_streaming env cfg;

  Printf.printf "\n=== Benchmark Complete ===\n"
