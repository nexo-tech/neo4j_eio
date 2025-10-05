open Neo4j_eio

(* Test streaming with small result set *)
let test_stream_small env cfg =
  let unique_label = Printf.sprintf "TestStream_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Create 10 nodes *)
      let create_query = Printf.sprintf
        "UNWIND range(1, 10) AS i CREATE (n:%s {id: i})" unique_label in
      match Session.run session ~statement:create_query () with
      | Error e -> Error e
      | Ok _ ->

      (* Stream them with fetch_size=3 *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n.id AS id ORDER BY id" unique_label in
      match Session.run_stream session ~statement:match_query ~fetch_size:3L () with
      | Error e -> Error e
      | Ok stream ->

      (* Fetch chunks manually *)
      let rec fetch_all acc count =
        if stream.Session.exhausted then
          Ok (List.rev acc, count)
        else
          match stream.Session.fetch_next () with
          | Error e -> Error e
          | Ok chunk ->
              fetch_all (chunk :: acc) (count + 1)
      in

      match fetch_all [] 0 with
      | Error e -> Error e
      | Ok (chunks, chunk_count) ->
          let all_records = List.flatten chunks in
          Alcotest.(check bool) "got 10 records" true (List.length all_records = 10);
          Alcotest.(check bool) "fetched in multiple chunks" true (chunk_count >= 3);

      (* Cleanup *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test streaming large result set to avoid OOM *)
let test_stream_large env cfg =
  let unique_label = Printf.sprintf "TestStreamLarge_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Create 1000 nodes *)
      let create_query = Printf.sprintf
        "UNWIND range(1, 1000) AS i CREATE (n:%s {id: i})" unique_label in
      match Session.run session ~statement:create_query () with
      | Error e -> Error e
      | Ok _ ->

      (* Stream with small chunks to test memory efficiency *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n.id AS id" unique_label in
      match Session.run_stream session ~statement:match_query ~fetch_size:50L () with
      | Error e -> Error e
      | Ok stream ->

      (* Process records one chunk at a time *)
      let rec process_chunks total =
        if stream.Session.exhausted then
          Ok total
        else
          match stream.Session.fetch_next () with
          | Error e -> Error e
          | Ok chunk ->
              (* Process chunk (just count in this test) *)
              process_chunks (total + List.length chunk)
      in

      match process_chunks 0 with
      | Error e -> Error e
      | Ok total ->
          Alcotest.(check bool) "processed 1000 records" true (total = 1000);

      (* Cleanup *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test stream_to_list helper *)
let test_stream_to_list env cfg =
  let unique_label = Printf.sprintf "TestStreamToList_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Create 20 nodes *)
      let create_query = Printf.sprintf
        "UNWIND range(1, 20) AS i CREATE (n:%s {id: i})" unique_label in
      match Session.run session ~statement:create_query () with
      | Error e -> Error e
      | Ok _ ->

      (* Create stream and convert to list *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n.id AS id" unique_label in
      match Session.run_stream session ~statement:match_query ~fetch_size:5L () with
      | Error e -> Error e
      | Ok stream ->

      match Session.stream_to_list stream with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check int) "got all 20 records" 20 (List.length records);

      (* Cleanup *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test strict materialization with fetch_size still works *)
let test_strict_with_fetch_size env cfg =
  let unique_label = Printf.sprintf "TestStrict_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Create 100 nodes *)
      let create_query = Printf.sprintf
        "UNWIND range(1, 100) AS i CREATE (n:%s {id: i})" unique_label in
      match Session.run session ~statement:create_query () with
      | Error e -> Error e
      | Ok _ ->

      (* Use regular run with fetch_size - should get all records *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n.id AS id" unique_label in
      match Session.run session ~statement:match_query ~fetch_size:10L () with
      | Error e -> Error e
      | Ok records ->
          Alcotest.(check int) "got all 100 records with chunking" 100 (List.length records);

      (* Cleanup *)
      let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label in
      Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

(* Test stream exhaustion *)
let test_stream_exhaustion env cfg =
  let unique_label = Printf.sprintf "TestExhaust_%d" (Random.int 1000000) in

  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Create 5 nodes *)
      let create_query = Printf.sprintf
        "UNWIND range(1, 5) AS i CREATE (n:%s {id: i})" unique_label in
      match Session.run session ~statement:create_query () with
      | Error e -> Error e
      | Ok _ ->

      (* Stream with large fetch_size *)
      let match_query = Printf.sprintf "MATCH (n:%s) RETURN n.id AS id" unique_label in
      match Session.run_stream session ~statement:match_query ~fetch_size:100L () with
      | Error e -> Error e
      | Ok stream ->

      (* First fetch should get all records *)
      match stream.Session.fetch_next () with
      | Error e -> Error e
      | Ok chunk1 ->
          Alcotest.(check int) "first chunk has 5 records" 5 (List.length chunk1);
          Alcotest.(check bool) "stream is exhausted" true stream.Session.exhausted;

          (* Second fetch should return empty *)
          match stream.Session.fetch_next () with
          | Error e -> Error e
          | Ok chunk2 ->
              Alcotest.(check int) "second chunk is empty" 0 (List.length chunk2);

          (* Cleanup *)
          let delete_query = Printf.sprintf "MATCH (n:%s) DELETE n" unique_label in
          Session.run session ~statement:delete_query ()
    ) with
    | Ok _ -> ()
    | Error e -> Alcotest.failf "Test failed: %s" (Error.to_string e)

let () =
  Random.self_init ();
  Alcotest.run "Streaming PULL tests"
    [ "streaming API", [
        Test_helper.with_neo4j "stream small result set" `Quick test_stream_small;
        Test_helper.with_neo4j "stream large result set without OOM" `Slow test_stream_large;
        Test_helper.with_neo4j "stream_to_list helper" `Quick test_stream_to_list;
        Test_helper.with_neo4j "strict materialization with fetch_size" `Quick test_strict_with_fetch_size;
        Test_helper.with_neo4j "stream exhaustion" `Quick test_stream_exhaustion;
      ]
    ]
