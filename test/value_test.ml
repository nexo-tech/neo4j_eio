open Neo4j_eio

let test_primitives () =
  let null_val = Value.Null in
  let bool_val = Value.Bool true in
  let int_val = Value.Int 42L in
  let text_val = Value.Text "hello" in
  let bytes_val = Value.Bytes "data" in

  Alcotest.(check string) "null" "null" (Format.asprintf "%a" Value.pp_value null_val);
  Alcotest.(check string) "bool" "true" (Format.asprintf "%a" Value.pp_value bool_val);
  Alcotest.(check string) "int" "42" (Format.asprintf "%a" Value.pp_value int_val);
  Alcotest.(check string) "text" "\"hello\"" (Format.asprintf "%a" Value.pp_value text_val);
  Alcotest.(check string) "bytes" "Bytes(4)" (Format.asprintf "%a" Value.pp_value bytes_val)

let test_collections () =
  let list_val = Value.List [Value.Int 1L; Value.Int 2L; Value.Int 3L] in
  let map_val = Value.Map (Value.StringMap.of_seq (List.to_seq [
    ("name", Value.Text "Alice");
    ("age", Value.Int 30L)
  ])) in

  let list_str = Format.asprintf "%a" Value.pp_value list_val in
  let map_str = Format.asprintf "%a" Value.pp_value map_val in

  Alcotest.(check bool) "list contains ints" true (String.length list_str > 0);
  Alcotest.(check bool) "map contains fields" true (String.length map_str > 0)

let test_temporal_types () =
  let duration = Value.Duration { months = 1L; days = 2L; seconds = 3L; nanoseconds = 4L } in
  let date = Value.Date { days_since_epoch = 18000L } in
  let local_time = Value.LocalTime { nanoseconds_since_midnight = 43200000000000L } in
  let time = Value.Time { nanoseconds_since_midnight = 43200000000000L; timezone_offset_seconds = 3600L } in
  let local_datetime = Value.LocalDateTime { seconds_since_epoch = 1609459200L; nanoseconds = 0L } in
  let datetime_offset = Value.DateTimeOffset { seconds_since_epoch = 1609459200L; nanoseconds = 0L; timezone_offset_seconds = 3600L } in
  let datetime_zone = Value.DateTimeZoneId { seconds_since_epoch = 1609459200L; nanoseconds = 0L; timezone_id = "Europe/Paris" } in

  let duration_str = Format.asprintf "%a" Value.pp_value duration in
  let date_str = Format.asprintf "%a" Value.pp_value date in
  let local_time_str = Format.asprintf "%a" Value.pp_value local_time in
  let time_str = Format.asprintf "%a" Value.pp_value time in
  let local_datetime_str = Format.asprintf "%a" Value.pp_value local_datetime in
  let datetime_offset_str = Format.asprintf "%a" Value.pp_value datetime_offset in
  let datetime_zone_str = Format.asprintf "%a" Value.pp_value datetime_zone in

  Alcotest.(check bool) "duration prints" true (String.contains duration_str 'D');
  Alcotest.(check bool) "date prints" true (String.contains date_str 'D');
  Alcotest.(check bool) "local_time prints" true (String.contains local_time_str 'L');
  Alcotest.(check bool) "time prints" true (String.contains time_str 'T');
  Alcotest.(check bool) "local_datetime prints" true (String.contains local_datetime_str 'L');
  Alcotest.(check bool) "datetime_offset prints" true (String.contains datetime_offset_str 'D');
  Alcotest.(check bool) "datetime_zone prints" true (String.contains datetime_zone_str 'D')

let test_spatial_types () =
  let point2d = Value.Point2D { srid = 4326L; x = 12.3; y = 56.7 } in
  let point3d = Value.Point3D { srid = 4979L; x = 12.3; y = 56.7; z = 100.0 } in

  let point2d_str = Format.asprintf "%a" Value.pp_value point2d in
  let point3d_str = Format.asprintf "%a" Value.pp_value point3d in

  Alcotest.(check bool) "point2d prints" true (String.contains point2d_str 'P');
  Alcotest.(check bool) "point2d has x" true (String.contains point2d_str 'x');
  Alcotest.(check bool) "point3d prints" true (String.contains point3d_str 'P');
  Alcotest.(check bool) "point3d has z" true (String.contains point3d_str 'z')

let test_graph_types () =
  let node = Value.Node {
    node_id = 1L;
    labels = ["Person"; "Employee"];
    props = Value.StringMap.of_seq (List.to_seq [("name", Value.Text "Alice")])
  } in

  let rel = Value.Relationship {
    rel_id = 2L;
    start_node_id = 1L;
    end_node_id = 3L;
    rel_type = "KNOWS";
    rel_props = Value.StringMap.of_seq (List.to_seq [("since", Value.Int 2020L)])
  } in

  let urel = Value.UnboundRelationship {
    urel_id = 4L;
    urel_type = "LIKES";
    urel_props = Value.StringMap.empty
  } in

  let path = Value.Path {
    path_nodes = [];
    path_rels = [];
    path_seq = []
  } in

  let node_str = Format.asprintf "%a" Value.pp_value node in
  let rel_str = Format.asprintf "%a" Value.pp_value rel in
  let urel_str = Format.asprintf "%a" Value.pp_value urel in
  let path_str = Format.asprintf "%a" Value.pp_value path in

  Alcotest.(check bool) "node prints" true (String.contains node_str 'N');
  Alcotest.(check bool) "node has Alice" true (String.contains node_str 'A');
  Alcotest.(check bool) "rel prints" true (String.contains rel_str 'R');
  Alcotest.(check bool) "rel has KNOWS" true (String.contains rel_str 'K');
  Alcotest.(check bool) "urel prints" true (String.contains urel_str 'U');
  Alcotest.(check bool) "path prints" true (String.contains path_str 'P')

let () =
  Alcotest.run "value types"
    [ "primitives", [ Alcotest.test_case "primitives" `Quick test_primitives ]
    ; "collections", [ Alcotest.test_case "collections" `Quick test_collections ]
    ; "temporal", [ Alcotest.test_case "temporal types" `Quick test_temporal_types ]
    ; "spatial", [ Alcotest.test_case "spatial types" `Quick test_spatial_types ]
    ; "graph", [ Alcotest.test_case "graph types" `Quick test_graph_types ]
    ]
