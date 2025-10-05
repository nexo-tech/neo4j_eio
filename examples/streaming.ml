(** streaming.ml - BETTER_API Edition

    This demonstrates streaming and memory-efficient processing using:
    - Query Builder DSL
    - Record.at_* for extraction
*)

open Neo4j_eio

(* Example 1: Strict materialization with Session.run *)
let example_strict_materialization session =
  Printf.printf "Example 1: Strict materialization (all results loaded)\n";

  (* Create some test data *)
  match Query_builder.execute_unit
    (Query_builder.raw "UNWIND range(1, 10) AS x CREATE (n:StreamTest {value: x})")
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Run query with strict materialization *)
      (match Query_builder.execute
         (Query_builder.raw "MATCH (n:StreamTest) RETURN n.value AS value ORDER BY n.value")
         session with
       | Ok records ->
           Printf.printf "  ✓ Loaded %d records at once (strict)\n" (List.length records);
           Printf.printf "  Values: ";
           List.iter (fun record ->
             match Record.at_int record "value" with
             | Ok n -> Printf.printf "%Ld " n
             | Error _ -> ()
           ) records;
           Printf.printf "\n  ✓ All data in memory at once\n";

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw "MATCH (n:StreamTest) DELETE n")
             session in ()
       | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e))

(* Example 2: Streaming with custom fetch size *)
let example_streaming_fetch_size session =
  Printf.printf "\nExample 2: Streaming with custom fetch size\n";

  (* Create test data *)
  match Query_builder.execute_unit
    (Query_builder.raw "UNWIND range(1, 20) AS x CREATE (n:StreamChunk {value: x})")
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Create record stream with fetch_size=5 *)
      (match Session.run_stream_records session
         ~statement:"MATCH (n:StreamChunk) RETURN n.value AS value ORDER BY n.value"
         ~fetch_size:5L
         () with
       | Error e -> Printf.eprintf "  ✗ Stream creation failed: %s\n" (Error.to_string e)
       | Ok stream ->
           Printf.printf "  ✓ Stream created with fetch_size=5\n";

           (* Fetch chunks one by one *)
           let chunk_num = ref 1 in
           let rec fetch_loop () =
             if stream.exhausted then
               Printf.printf "  ✓ Stream exhausted\n"
             else
               match stream.fetch_next_records () with
               | Error e ->
                   Printf.eprintf "  ✗ Fetch failed: %s\n" (Error.to_string e)
               | Ok [] when stream.exhausted ->
                   Printf.printf "  ✓ Stream exhausted\n"
               | Ok chunk ->
                   Printf.printf "  Chunk %d: %d records\n" !chunk_num (List.length chunk);
                   chunk_num := !chunk_num + 1;
                   fetch_loop ()
           in
           fetch_loop ();

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw "MATCH (n:StreamChunk) DELETE n")
             session in ())

(* Example 3: Memory-efficient aggregation *)
let example_memory_efficient_aggregation session =
  Printf.printf "\nExample 3: Memory-efficient aggregation (streaming sum)\n";

  (* Create test data *)
  match Query_builder.execute_unit
    (Query_builder.raw "UNWIND range(1, 100) AS x CREATE (n:AggTest {value: x})")
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Stream and aggregate without loading all data *)
      (match Session.run_stream_records session
         ~statement:"MATCH (n:AggTest) RETURN n.value AS value"
         ~fetch_size:10L
         () with
       | Error e -> Printf.eprintf "  ✗ Stream failed: %s\n" (Error.to_string e)
       | Ok stream ->
           Printf.printf "  ✓ Streaming 100 records in chunks of 10\n";

           (* Aggregate while streaming *)
           let rec aggregate_stream sum count =
             if stream.exhausted then
               (sum, count)
             else
               match stream.fetch_next_records () with
               | Error _ -> (sum, count)
               | Ok [] when stream.exhausted -> (sum, count)
               | Ok chunk ->
                   let chunk_sum = List.fold_left (fun acc record ->
                     match Record.at_int record "value" with
                     | Ok n -> acc + (Int64.to_int n)
                     | Error _ -> acc
                   ) 0 chunk in
                   let chunk_count = List.length chunk in
                   Printf.printf "  Processed chunk: %d records, sum=%d\n" chunk_count chunk_sum;
                   aggregate_stream (sum + chunk_sum) (count + chunk_count)
           in
           let (total_sum, total_count) = aggregate_stream 0 0 in
           Printf.printf "  ✓ Total: %d records, sum=%d\n" total_count total_sum;
           Printf.printf "  ✓ Memory-efficient: only 10 records in memory at a time\n";

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw "MATCH (n:AggTest) DELETE n")
             session in ())

(* Example 4: Early termination *)
let example_early_termination session =
  Printf.printf "\nExample 4: Early termination (stop when condition met)\n";

  (* Create test data *)
  match Query_builder.execute_unit
    (Query_builder.raw "UNWIND range(1, 50) AS x CREATE (n:EarlyStop {value: x})")
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Stream and stop early *)
      (match Session.run_stream_records session
         ~statement:"MATCH (n:EarlyStop) RETURN n.value AS value ORDER BY n.value"
         ~fetch_size:10L
         () with
       | Error e -> Printf.eprintf "  ✗ Stream failed: %s\n" (Error.to_string e)
       | Ok stream ->
           Printf.printf "  ✓ Streaming 50 records, stopping when value > 25\n";

           (* Find first value > 25 *)
           let rec find_target () =
             if stream.exhausted then
               Printf.printf "  ✗ Target not found\n"
             else
               match stream.fetch_next_records () with
               | Error e -> Printf.eprintf "  ✗ Fetch failed: %s\n" (Error.to_string e)
               | Ok [] when stream.exhausted -> Printf.printf "  ✗ Target not found\n"
               | Ok chunk ->
                   let found = List.find_opt (fun record ->
                     match Record.at_int record "value" with
                     | Ok n -> n > 25L
                     | Error _ -> false
                   ) chunk in
                   (match found with
                    | Some record ->
                        (match Record.at_int record "value" with
                         | Ok n ->
                             Printf.printf "  ✓ Found target: %Ld (stopped early!)\n" n;
                             Printf.printf "  ✓ Didn't need to fetch remaining records\n"
                         | Error _ -> ())
                    | None ->
                        Printf.printf "  Checked chunk, continuing...\n";
                        find_target ())
           in
           find_target ();

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw "MATCH (n:EarlyStop) DELETE n")
             session in ())

(* Example 5: Using record_stream_to_list helper *)
let example_record_stream_to_list session =
  Printf.printf "\nExample 5: Using record_stream_to_list helper\n";

  (* Create test data *)
  match Query_builder.execute_unit
    (Query_builder.raw "UNWIND range(1, 15) AS x CREATE (n:ToList {value: x})")
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Create record stream *)
      (match Session.run_stream_records session
         ~statement:"MATCH (n:ToList) RETURN n.value AS value ORDER BY n.value"
         ~fetch_size:5L
         () with
       | Error e -> Printf.eprintf "  ✗ Stream failed: %s\n" (Error.to_string e)
       | Ok stream ->
           Printf.printf "  ✓ Stream created with fetch_size=5\n";

           (* Convert entire stream to list *)
           (match Session.record_stream_to_list stream with
            | Error e -> Printf.eprintf "  ✗ record_stream_to_list failed: %s\n" (Error.to_string e)
            | Ok records ->
                Printf.printf "  ✓ Converted stream to list: %d records\n" (List.length records);
                Printf.printf "  ✓ Helper automatically fetched all chunks\n";

                (* Cleanup *)
                let _ = Query_builder.execute_unit
                  (Query_builder.raw "MATCH (n:ToList) DELETE n")
                  session in ()))

(* Example 6: Comparing strict vs streaming memory usage *)
let example_memory_comparison session =
  Printf.printf "\nExample 6: Memory efficiency comparison\n";

  let count = 1000 in

  (* Create large dataset *)
  match Query_builder.execute_unit
    (Query_builder.raw (Printf.sprintf "UNWIND range(1, %d) AS x CREATE (n:MemTest {value: x, data: 'padding_' + x})" count))
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Strict: loads all at once *)
      Printf.printf "  Strict materialization:\n";
      (match Query_builder.execute
         (Query_builder.raw "MATCH (n:MemTest) RETURN n.value AS value")
         session with
       | Ok records ->
           Printf.printf "    ✓ Loaded %d records at once\n" (List.length records);
           Printf.printf "    Memory: ALL %d records in memory\n" count
       | Error e -> Printf.eprintf "    ✗ Query failed: %s\n" (Error.to_string e));

      (* Streaming: loads in chunks *)
      Printf.printf "  Streaming:\n";
      (match Session.run_stream_records session
         ~statement:"MATCH (n:MemTest) RETURN n.value AS value"
         ~fetch_size:100L
         () with
       | Error e -> Printf.eprintf "    ✗ Stream failed: %s\n" (Error.to_string e)
       | Ok stream ->
           Printf.printf "    ✓ Stream created with fetch_size=100\n";
           Printf.printf "    Memory: MAX 100 records in memory at once\n";
           Printf.printf "    ✓ %dx less memory usage!\n" (count / 100);

           (* Consume stream *)
           let rec consume () =
             if not stream.exhausted then
               match stream.fetch_next_records () with
               | Ok _ -> consume ()
               | Error _ -> ()
           in
           consume ());

      (* Cleanup *)
      let _ = Query_builder.execute_unit
        (Query_builder.raw "MATCH (n:MemTest) DELETE n")
        session in ()

(* Example 7: Processing stream chunks *)
let example_streaming_chunks session =
  Printf.printf "\nExample 7: Processing stream chunks\n";

  (* Create test data *)
  match Query_builder.execute_unit
    (Query_builder.raw "UNWIND range(1, 12) AS x CREATE (n:ChunkTest {id: x, name: 'Node_' + x})")
    session with
  | Error e -> Printf.eprintf "  ✗ CREATE failed: %s\n" (Error.to_string e)
  | Ok () ->
      (* Stream and process chunks *)
      (match Session.run_stream_records session
         ~statement:"MATCH (n:ChunkTest) RETURN n.id AS id, n.name AS name ORDER BY n.id"
         ~fetch_size:4L
         () with
       | Error e -> Printf.eprintf "  ✗ Stream failed: %s\n" (Error.to_string e)
       | Ok stream ->
           Printf.printf "  ✓ Stream created with fetch_size=4\n";

           let chunk_num = ref 1 in
           let rec process_stream () =
             if stream.exhausted then
               Printf.printf "  ✓ Stream complete\n"
             else
               match stream.fetch_next_records () with
               | Error e -> Printf.eprintf "  ✗ Fetch failed: %s\n" (Error.to_string e)
               | Ok [] when stream.exhausted -> Printf.printf "  ✓ Stream complete\n"
               | Ok chunk ->
                   Printf.printf "  Chunk %d (%d records)\n" !chunk_num (List.length chunk);
                   chunk_num := !chunk_num + 1;
                   process_stream ()
           in
           process_stream ();

           (* Cleanup *)
           let _ = Query_builder.execute_unit
             (Query_builder.raw "MATCH (n:ChunkTest) DELETE n")
             session in ())

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Streaming and Memory-Efficient Processing\n";
    Printf.printf "=========================================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_strict_materialization session;
        example_streaming_fetch_size session;
        example_memory_efficient_aggregation session;
        example_early_termination session;
        example_record_stream_to_list session;
        example_memory_comparison session;
        example_streaming_chunks session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All streaming examples completed!\n";
          Printf.printf "  Streaming API advantages:\n";
          Printf.printf "  - Memory-efficient: process large datasets\n";
          Printf.printf "  - Early termination: stop when condition met\n";
          Printf.printf "  - Custom fetch sizes: tune performance\n";
          Printf.printf "  - Record-based API: ergonomic field access\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
