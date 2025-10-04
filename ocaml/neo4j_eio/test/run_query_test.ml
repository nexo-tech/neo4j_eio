open Neo4j_eio

let test_run_simple_query env cfg =
  Eio.Switch.run @@ fun sw ->
    match Connection.authenticate ~sw ~net:env#net cfg with
    | Error e ->
        Alcotest.failf "Authentication failed: %s" (Error.to_string e)
    | Ok (_version, flow) ->
        (* Run a simple RETURN query *)
        let result = Connection.run_query flow ~statement:"RETURN 1 AS num" () in
        Connection.goodbye flow;

        match result with
        | Error e ->
            Alcotest.failf "Query failed: %s" (Error.to_string e)
        | Ok records ->
            Alcotest.(check bool) "got at least one record" true (List.length records >= 1);
            (* Verify the result *)
            match records with
            | Value.Int n :: _ ->
                Alcotest.(check int64) "returned value is 1" 1L n
            | _ ->
                Alcotest.fail "Expected Int value in record"

let test_run_multiple_records env cfg =
  Eio.Switch.run @@ fun sw ->
    match Connection.authenticate ~sw ~net:env#net cfg with
    | Error e ->
        Alcotest.failf "Authentication failed: %s" (Error.to_string e)
    | Ok (_version, flow) ->
        (* Run a query that returns multiple records *)
        let result = Connection.run_query flow ~statement:"UNWIND [1, 2, 3] AS x RETURN x" () in
        Connection.goodbye flow;

        match result with
        | Error e ->
            Alcotest.failf "Query failed: %s" (Error.to_string e)
        | Ok records ->
            Alcotest.(check int) "got 3 records" 3 (List.length records);
            (* Verify values *)
            match records with
            | [Value.Int 1L; Value.Int 2L; Value.Int 3L] ->
                Alcotest.(check bool) "values are correct" true true
            | _ ->
                Alcotest.failf "Expected [1, 2, 3], got %d records" (List.length records)

let () =
  Alcotest.run "run/pull queries"
    [ "queries", [
        Test_helper.with_neo4j "run simple query" `Quick test_run_simple_query;
        Test_helper.with_neo4j "run multiple records" `Quick test_run_multiple_records;
      ]
    ]
