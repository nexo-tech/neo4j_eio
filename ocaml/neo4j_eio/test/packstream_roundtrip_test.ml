open Neo4j_eio

let test_roundtrip name value =
  Alcotest.test_case name `Quick (fun () ->
    let encoded = Packstream.encode_value value in
    match Packstream.decode_value_from_string encoded with
    | Ok decoded ->
        Alcotest.(check bool) (name ^ " roundtrip") true (value = decoded)
    | Error msg ->
        Alcotest.failf "Decode failed: %s" msg)

let primitives_tests = [
  test_roundtrip "null" Value.Null;
  test_roundtrip "bool true" (Value.Bool true);
  test_roundtrip "bool false" (Value.Bool false);
  test_roundtrip "int 0" (Value.Int 0L);
  test_roundtrip "int 42" (Value.Int 42L);
  test_roundtrip "int -1" (Value.Int (-1L));
  test_roundtrip "int 1000" (Value.Int 1000L);
  test_roundtrip "int 100000" (Value.Int 100000L);
  test_roundtrip "int 10000000000" (Value.Int 10000000000L);
  test_roundtrip "float 1.5" (Value.Float 1.5);
  test_roundtrip "float -3.14" (Value.Float (-3.14));
  test_roundtrip "text hello" (Value.Text "hello");
  test_roundtrip "text empty" (Value.Text "");
  test_roundtrip "text long" (Value.Text (String.make 100 'x'));
  test_roundtrip "bytes" (Value.Bytes "data");
]

let collections_tests = [
  test_roundtrip "empty list" (Value.List []);
  test_roundtrip "list [1,2,3]" (Value.List [Value.Int 1L; Value.Int 2L; Value.Int 3L]);
  test_roundtrip "nested list" (Value.List [Value.List [Value.Int 1L]; Value.Int 2L]);
  test_roundtrip "empty map" (Value.Map Value.StringMap.empty);
  test_roundtrip "map {a:1}" (Value.Map (Value.StringMap.of_seq (List.to_seq [("a", Value.Int 1L)])));
  test_roundtrip "map {a:1,b:2}" (Value.Map (Value.StringMap.of_seq (List.to_seq [
    ("a", Value.Int 1L);
    ("b", Value.Int 2L)
  ])));
]

let structs_tests = [
  test_roundtrip "struct" (Value.Struct { signature = 0x42; fields = [Value.Int 1L; Value.Text "test"] });
]

let graph_tests = [
  test_roundtrip "node" (Value.Node {
    node_id = 123L;
    labels = ["Person"; "Employee"];
    props = Value.StringMap.of_seq (List.to_seq [("name", Value.Text "Alice")])
  });

  test_roundtrip "relationship" (Value.Relationship {
    rel_id = 456L;
    start_node_id = 1L;
    end_node_id = 2L;
    rel_type = "KNOWS";
    rel_props = Value.StringMap.of_seq (List.to_seq [("since", Value.Int 2020L)])
  });

  test_roundtrip "unbound relationship" (Value.UnboundRelationship {
    urel_id = 789L;
    urel_type = "LIKES";
    urel_props = Value.StringMap.empty
  });

  test_roundtrip "path" (Value.Path {
    path_nodes = [
      { node_id = 1L; labels = ["A"]; props = Value.StringMap.empty };
      { node_id = 2L; labels = ["B"]; props = Value.StringMap.empty }
    ];
    path_rels = [
      { urel_id = 10L; urel_type = "LINK"; urel_props = Value.StringMap.empty }
    ];
    path_seq = [1; 1]
  });
]

let temporal_tests = [
  test_roundtrip "duration" (Value.Duration {
    months = 1L;
    days = 2L;
    seconds = 3L;
    nanoseconds = 4L
  });

  test_roundtrip "date" (Value.Date { days_since_epoch = 18000L });

  test_roundtrip "local_time" (Value.LocalTime {
    nanoseconds_since_midnight = 43200000000000L
  });

  test_roundtrip "time" (Value.Time {
    nanoseconds_since_midnight = 43200000000000L;
    timezone_offset_seconds = 3600L
  });

  test_roundtrip "local_datetime" (Value.LocalDateTime {
    seconds_since_epoch = 1609459200L;
    nanoseconds = 0L
  });

  test_roundtrip "datetime_offset" (Value.DateTimeOffset {
    seconds_since_epoch = 1609459200L;
    nanoseconds = 0L;
    timezone_offset_seconds = 3600L
  });

  test_roundtrip "datetime_zone_id" (Value.DateTimeZoneId {
    seconds_since_epoch = 1609459200L;
    nanoseconds = 0L;
    timezone_id = "Europe/Paris"
  });
]

let spatial_tests = [
  test_roundtrip "point2d" (Value.Point2D {
    srid = 4326L;
    x = 12.3;
    y = 56.7
  });

  test_roundtrip "point3d" (Value.Point3D {
    srid = 4979L;
    x = 12.3;
    y = 56.7;
    z = 100.0
  });
]

let () =
  Alcotest.run "packstream roundtrip"
    [ "primitives", primitives_tests
    ; "collections", collections_tests
    ; "structs", structs_tests
    ; "graph", graph_tests
    ; "temporal", temporal_tests
    ; "spatial", spatial_tests
    ]
