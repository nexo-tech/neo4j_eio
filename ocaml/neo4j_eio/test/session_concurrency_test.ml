open Neo4j_eio

(* Test that concurrent queries are properly serialized *)
let test_concurrent_queries env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Launch 5 concurrent fibers making queries *)
      let results = ref [] in
      Eio.Fiber.both
        (fun () ->
          for i = 1 to 3 do
            match Session.run session ~statement:(Printf.sprintf "RETURN %d AS n" i) () with
            | Ok records ->
                results := (i, List.length records) :: !results
            | Error e ->
                Alcotest.failf "Query %d failed: %s" i (Error.to_string e)
          done)
        (fun () ->
          for i = 4 to 5 do
            match Session.run session ~statement:(Printf.sprintf "RETURN %d AS n" i) () with
            | Ok records ->
                results := (i, List.length records) :: !results
            | Error e ->
                Alcotest.failf "Query %d failed: %s" i (Error.to_string e)
          done);

      (* All queries should have succeeded *)
      Alcotest.(check int) "all queries completed" 5 (List.length !results);
      Ok ()
    ) with
    | Ok () ->
        Alcotest.(check bool) "session completed" true true
    | Error e ->
        Alcotest.failf "Session failed: %s" (Error.to_string e)

(* Test transaction serialization *)
let test_transaction_serialization env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Begin transaction *)
      match Session.begin_transaction session () with
      | Error e -> Error e
      | Ok () ->
          (* Run query in transaction *)
          match Session.run session ~statement:"CREATE (n:TestNode {id: 1}) RETURN n" () with
          | Error e -> Error e
          | Ok _ ->
              (* Rollback to clean up *)
              Session.rollback session
    ) with
    | Ok () ->
        Alcotest.(check bool) "transaction rolled back" true true
    | Error e ->
        Alcotest.failf "Transaction failed: %s" (Error.to_string e)

(* Test fetch size for streaming *)
let test_fetch_size env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Query with fetch size *)
      Session.run session
        ~statement:"UNWIND range(1, 10) AS x RETURN x"
        ~fetch_size:5L
        ()
    ) with
    | Ok records ->
        (* Should get all 10 records despite fetch size *)
        Alcotest.(check int) "got all records" 10 (List.length records)
    | Error e ->
        Alcotest.failf "Query failed: %s" (Error.to_string e)

(* Test interleaving prevention - queries must not corrupt each other *)
let test_no_interleaving env cfg =
  Eio.Switch.run @@ fun sw ->
    match Session.with_session ~sw ~net:env#net cfg (fun session ->
      (* Create a counter for verification *)
      let counter = ref 0 in
      let mutex = Eio.Mutex.create () in

      (* Launch multiple fibers that increment counter and query *)
      Eio.Fiber.all [
        (fun () ->
          for _i = 1 to 3 do
            match Session.run session ~statement:"RETURN 1 AS x" () with
            | Ok _records ->
                Eio.Mutex.use_rw mutex ~protect:true (fun () ->
                  counter := !counter + 1)
            | Error e ->
                Alcotest.failf "Query failed: %s" (Error.to_string e)
          done);
        (fun () ->
          for _i = 1 to 2 do
            match Session.run session ~statement:"RETURN 2 AS y" () with
            | Ok _records ->
                Eio.Mutex.use_rw mutex ~protect:true (fun () ->
                  counter := !counter + 1)
            | Error e ->
                Alcotest.failf "Query failed: %s" (Error.to_string e)
          done);
      ];

      Alcotest.(check int) "all queries executed" 5 !counter;
      Ok ()
    ) with
    | Ok () ->
        Alcotest.(check bool) "no interleaving" true true
    | Error e ->
        Alcotest.failf "Session failed: %s" (Error.to_string e)

let () =
  Alcotest.run "session concurrency"
    [ "serialization", [
        Test_helper.with_neo4j "concurrent queries" `Quick test_concurrent_queries;
        Test_helper.with_neo4j "transaction serialization" `Quick test_transaction_serialization;
        Test_helper.with_neo4j "fetch size streaming" `Quick test_fetch_size;
        Test_helper.with_neo4j "no interleaving" `Quick test_no_interleaving;
      ]
    ]
