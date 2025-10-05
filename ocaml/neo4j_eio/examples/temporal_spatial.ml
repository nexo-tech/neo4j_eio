(* File: examples/temporal_spatial.ml *)
(* Task 2.3: Demonstrates temporal and spatial types *)

open Neo4j_eio

(* Example 1: Point2D - Cartesian *)
let example_point2d_cartesian session =
  Printf.printf "Example 1: Point2D - Cartesian coordinate system\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN point({x: 3.0, y: 4.0}) AS pt"
    () with
  | Ok [record] ->
      (match Record.at_point2d record "pt" with
       | Ok pt ->
           Printf.printf "  ✓ Point2D: srid=%Ld, x=%g, y=%g\n" pt.Value.srid pt.Value.x pt.Value.y;
           Printf.printf "  ✓ SRID 7203 = Cartesian 2D\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 2: Point2D - WGS-84 (Geographic) *)
let example_point2d_wgs84 session =
  Printf.printf "\nExample 2: Point2D - WGS-84 (latitude/longitude)\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN point({latitude: 37.7749, longitude: -122.4194}) AS pt"
    () with
  | Ok [record] ->
      (match Record.at_point2d record "pt" with
       | Ok pt ->
           Printf.printf "  ✓ Point2D: srid=%Ld, x=%g, y=%g\n" pt.Value.srid pt.Value.x pt.Value.y;
           Printf.printf "  ✓ SRID 4326 = WGS-84 (Geographic)\n";
           Printf.printf "  ✓ Location: San Francisco (lat=%g, lon=%g)\n" pt.Value.y pt.Value.x
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 3: Point3D - Cartesian *)
let example_point3d_cartesian session =
  Printf.printf "\nExample 3: Point3D - Cartesian 3D coordinates\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN point({x: 1.0, y: 2.0, z: 3.0}) AS pt"
    () with
  | Ok [record] ->
      (match Record.at_point3d record "pt" with
       | Ok pt ->
           Printf.printf "  ✓ Point3D: srid=%Ld, x=%g, y=%g, z=%g\n"
             pt.Value.srid pt.Value.x pt.Value.y pt.Value.z;
           Printf.printf "  ✓ SRID 9157 = Cartesian 3D\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 4: Point3D - WGS-84 with height *)
let example_point3d_wgs84 session =
  Printf.printf "\nExample 4: Point3D - WGS-84 with height\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN point({latitude: 51.5074, longitude: -0.1278, height: 100.0}) AS pt"
    () with
  | Ok [record] ->
      (match Record.at_point3d record "pt" with
       | Ok pt ->
           Printf.printf "  ✓ Point3D: srid=%Ld, x=%g, y=%g, z=%g\n"
             pt.Value.srid pt.Value.x pt.Value.y pt.Value.z;
           Printf.printf "  ✓ SRID 4979 = WGS-84 3D\n";
           Printf.printf "  ✓ Location: London (lat=%g, lon=%g, height=%gm)\n"
             pt.Value.y pt.Value.x pt.Value.z
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 5: Duration *)
let example_duration session =
  Printf.printf "\nExample 5: Duration type\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN duration({months: 2, days: 14, hours: 16, minutes: 30, seconds: 45}) AS dur"
    () with
  | Ok [record] ->
      (match Record.at_duration record "dur" with
       | Ok dur ->
           Printf.printf "  ✓ Duration: months=%Ld, days=%Ld, seconds=%Ld, nanoseconds=%Ld\n"
             dur.Value.months dur.Value.days dur.Value.seconds dur.Value.nanoseconds;
           Printf.printf "  ✓ Represents: 2 months, 14 days, 16h 30m 45s\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 6: Date *)
let example_date session =
  Printf.printf "\nExample 6: Date type\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN date('2025-10-05') AS dt"
    () with
  | Ok [record] ->
      (match Record.at_date record "dt" with
       | Ok dt ->
           Printf.printf "  ✓ Date: days_since_epoch=%Ld\n" dt.Value.days_since_epoch;
           Printf.printf "  ✓ Represents: 2025-10-05\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 7: LocalTime *)
let example_local_time session =
  Printf.printf "\nExample 7: LocalTime (time without timezone)\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN localtime('12:34:56.789') AS t"
    () with
  | Ok [record] ->
      (match Record.at_local_time record "t" with
       | Ok t ->
           Printf.printf "  ✓ LocalTime: nanoseconds_since_midnight=%Ld\n"
             t.Value.nanoseconds_since_midnight;
           Printf.printf "  ✓ Represents: 12:34:56.789 (no timezone)\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 8: Time with timezone offset *)
let example_time_with_offset session =
  Printf.printf "\nExample 8: Time with timezone offset\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN time('12:34:56.789+02:00') AS t"
    () with
  | Ok [record] ->
      (match Record.at_time record "t" with
       | Ok t ->
           Printf.printf "  ✓ Time: nanoseconds=%Ld, offset_seconds=%Ld\n"
             t.Value.nanoseconds_since_midnight t.Value.timezone_offset_seconds;
           Printf.printf "  ✓ Represents: 12:34:56.789+02:00\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 9: LocalDateTime *)
let example_local_datetime session =
  Printf.printf "\nExample 9: LocalDateTime (datetime without timezone)\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN localdatetime('2025-10-05T15:30:45.123') AS dt"
    () with
  | Ok [record] ->
      (match Record.at_local_datetime record "dt" with
       | Ok dt ->
           Printf.printf "  ✓ LocalDateTime: seconds=%Ld, nanoseconds=%Ld\n"
             dt.Value.seconds_since_epoch dt.Value.nanoseconds;
           Printf.printf "  ✓ Represents: 2025-10-05T15:30:45.123 (no timezone)\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 10: DateTime with timezone offset *)
let example_datetime_offset session =
  Printf.printf "\nExample 10: DateTime with timezone offset\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN datetime('2025-10-05T15:30:45.123+02:00') AS dt"
    () with
  | Ok [record] ->
      (match Record.at_datetime_offset record "dt" with
       | Ok dt ->
           Printf.printf "  ✓ DateTimeOffset: seconds=%Ld, nanoseconds=%Ld, offset=%Ld\n"
             dt.Value.seconds_since_epoch dt.Value.nanoseconds dt.Value.timezone_offset_seconds;
           Printf.printf "  ✓ Represents: 2025-10-05T15:30:45.123+02:00\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 11: DateTime with named timezone *)
let example_datetime_zone_id session =
  Printf.printf "\nExample 11: DateTime with named timezone\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN datetime('2025-10-05T15:30:45.123[Europe/Paris]') AS dt"
    () with
  | Ok [record] ->
      (match Record.at_datetime_zone_id record "dt" with
       | Ok dt ->
           Printf.printf "  ✓ DateTimeZoneId: seconds=%Ld, nanoseconds=%Ld, zone=%s\n"
             dt.Value.seconds_since_epoch dt.Value.nanoseconds dt.Value.timezone_id;
           Printf.printf "  ✓ Represents: 2025-10-05T15:30:45.123 in timezone %s\n"
             dt.Value.timezone_id
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 12: Storing and retrieving temporal/spatial data *)
let example_storing_temporal_spatial session =
  Printf.printf "\nExample 12: Storing and retrieving temporal/spatial data\n";

  let label = Printf.sprintf "Event_%d" (Random.int 1000000) in
  let open Neo4j in

  (* Create a node with temporal and spatial properties *)
  match query session
    ~statement:(Printf.sprintf
      "CREATE (e:%s {name: 'Conference', location: point({latitude: 48.8566, longitude: 2.3522}), start_time: datetime('2025-10-05T09:00:00[Europe/Paris]')}) RETURN e.name AS name, e.location AS location, e.start_time AS start_time"
      label)
    () with
  | Ok [record] ->
      (match Record.at_text record "name",
             Record.at_point2d record "location",
             Record.at_datetime_zone_id record "start_time" with
       | Ok name, Ok location, Ok start_time ->
           Printf.printf "  ✓ Created event: %s\n" name;
           Printf.printf "    Location: lat=%g, lon=%g (Paris)\n"
             location.Value.y location.Value.x;
           Printf.printf "    Start time: %s\n" start_time.Value.timezone_id;

           (* Cleanup *)
           let _ = query_ session
             ~statement:(Printf.sprintf "MATCH (n:%s) DELETE n" label)
             () in
           Printf.printf "  ✓ Cleanup completed\n"
       | _ ->
           Printf.printf "  ✗ Decode error\n")
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 13: Duration calculations *)
let example_duration_calculations session =
  Printf.printf "\nExample 13: Duration calculations\n";

  let open Neo4j in
  match query session
    ~statement:"RETURN duration.between(date('2025-01-01'), date('2025-10-05')) AS dur"
    () with
  | Ok [record] ->
      (match Record.at_duration record "dur" with
       | Ok dur ->
           Printf.printf "  ✓ Duration between 2025-01-01 and 2025-10-05:\n";
           Printf.printf "    Months: %Ld, Days: %Ld\n" dur.Value.months dur.Value.days;
           Printf.printf "  ✓ Represents: ~9 months\n"
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Example 14: Distance between points *)
let example_point_distance session =
  Printf.printf "\nExample 14: Calculating distance between points\n";

  let open Neo4j in
  match query session
    ~statement:"WITH point({latitude: 48.8566, longitude: 2.3522}) AS paris, point({latitude: 51.5074, longitude: -0.1278}) AS london RETURN point.distance(paris, london) AS dist"
    () with
  | Ok [record] ->
      (match Record.at_float record "dist" with
       | Ok dist ->
           Printf.printf "  ✓ Distance from Paris to London: %.2f meters\n" dist;
           Printf.printf "  ✓ Approximately %.2f kilometers\n" (dist /. 1000.0)
       | Error e ->
           Format.eprintf "  ✗ Decode error: %a@." Record.pp_decode_error e)
  | Ok _ -> Printf.printf "  ✗ Unexpected result format\n"
  | Error e -> Printf.eprintf "  ✗ Query failed: %s\n" (Error.to_string e)

(* Main entry point *)
let () =
  Random.self_init ();
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Temporal and Spatial Types\n";
    Printf.printf "===========================\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_point2d_cartesian session;
        example_point2d_wgs84 session;
        example_point3d_cartesian session;
        example_point3d_wgs84 session;
        example_duration session;
        example_date session;
        example_local_time session;
        example_time_with_offset session;
        example_local_datetime session;
        example_datetime_offset session;
        example_datetime_zone_id session;
        example_storing_temporal_spatial session;
        example_duration_calculations session;
        example_point_distance session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\n✓ All temporal/spatial examples completed!\n";
          Printf.printf "  Demonstrated types:\n";
          Printf.printf "  - Point2D (Cartesian and WGS-84)\n";
          Printf.printf "  - Point3D (Cartesian and WGS-84 with height)\n";
          Printf.printf "  - Duration (months, days, seconds, nanoseconds)\n";
          Printf.printf "  - Date, LocalTime, Time\n";
          Printf.printf "  - LocalDateTime, DateTimeOffset, DateTimeZoneId\n";
          Printf.printf "  - Record.at_* functions for ergonomic field access\n"
      | Error e ->
          Printf.eprintf "\n✗ Session failed: %s\n" (Error.to_string e);
          exit 1
