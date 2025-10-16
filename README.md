# neo4j_eio

OCaml driver for Neo4j 5+ using the Bolt protocol and [Eio](https://github.com/ocaml-multicore/eio) for effects-based I/O.

## Features

- **Bolt Protocol Support**: Negotiates Bolt v5, v4, and v3 with Neo4j servers
- **Effects-Based I/O**: Built on Eio for modern OCaml 5+ concurrency
- **Type-Safe API**: Strong typing with Result-based error handling
- **Complete Value Support**: All Neo4j types including v2 temporal/spatial types (Point2D/3D, Duration, Date/Time variants)
- **Transactions**: Explicit BEGIN/COMMIT/ROLLBACK and functional `transact` helper
- **Streaming**: Lazy record consumption with configurable fetch sizes
- **TLS Support**: Secure connections via `tls-eio` (planned)
- **Record Decoding**: Type-directed accessors (`at`, `exact`, `maybe_at`)

## Installation

```bash
opam install neo4j_eio
```

Or from source:

```bash
# Create local switch with OCaml 5.2.1+
opam switch create . 5.2.1
eval $(opam env)

# Install dependencies
opam install dune eio eio_main alcotest

# Build
dune build

# Run tests (requires Neo4j running on localhost:7687)
dune runtest
```

## Quick Start

```ocaml
open Neo4j_eio

(* Simple query returning titles *)
let get_nineties_movies session =
  match Neo4j.query session
    ~statement:"MATCH (m:Movie) WHERE m.released >= 1990 AND m.released < 2000 RETURN m.title AS title"
    () with
  | Ok records ->
      List.filter_map (function
        | [Value.Text title] -> Some title
        | _ -> None
      ) records
  | Error e ->
      Printf.eprintf "Query failed: %s\n" (Error.to_string e);
      []

(* Query with parameters *)
let get_actors_by_name session name =
  let open Neo4j in
  match query_p session
    ~statement:"MATCH (p:Person) WHERE p.name CONTAINS $name RETURN p"
    ~parameters:(props ["name" =: Value.Text name])
    () with
  | Ok records ->
      List.filter_map (function
        | [Value.Node node] ->
            Value.StringMap.find_opt "name" node.node_props
        | _ -> None
      ) records
  | Error e ->
      Printf.eprintf "Query failed: %s\n" (Error.to_string e);
      []

(* Main *)
let () =
  Eio_main.run @@ fun env ->
    let cfg = Config.make
      ~uri:"bolt://localhost:7687"
      ~user:"neo4j"
      ~password:"testpass"
      () in

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        (* Run queries *)
        let movies = get_nineties_movies session in
        Printf.printf "Nineties movies:\n";
        List.iter (Printf.printf "  %s\n") movies;

        let actors = get_actors_by_name session "Tom" in
        Printf.printf "\nActors named Tom:\n";
        List.iter (function
          | Value.Text name -> Printf.printf "  %s\n" name
          | _ -> ()
        ) actors;

        Ok ()
      ) with
      | Ok () -> ()
      | Error e -> Printf.eprintf "Session failed: %s\n" (Error.to_string e)
```

## Configuration

Create a configuration with `Config.make`:

```ocaml
let cfg = Config.make
  ~uri:"bolt://localhost:7687"    (* or neo4j:// for routing *)
  ~user:"neo4j"
  ~password:"your_password"
  ~user_agent:"MyApp/1.0"          (* optional *)
  ~fetch_size:1000L                (* optional, default 1000 *)
  ()
```

Or use environment variables:

```ocaml
(* Reads NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD *)
let cfg = Config.of_env ()
```

## Query API

The library provides several query functions mirroring different use cases:

```ocaml
(* Query with parameters, return records *)
let query_p session ~statement ~parameters () : (Value.value list list, Error.t) result

(* Query without parameters, return records *)
let query session ~statement () : (Value.value list list, Error.t) result

(* Query with parameters, ignore results *)
let query_p_ session ~statement ~parameters () : (unit, Error.t) result

(* Query without parameters, ignore results *)
let query_ session ~statement () : (unit, Error.t) result
```

### Parameter Building

Use the `=:` operator and `props` helper to build parameter maps:

```ocaml
let open Neo4j in

(* Simple parameters *)
let params = props [
  "name" =: Value.Text "Alice";
  "age" =: Value.Int 30L;
]

(* Nested properties *)
let params = props [
  "person" =: Value.Map (props [
    "name" =: Value.Text "Bob";
    "born" =: Value.Int 1990L;
  ])
]

(* Use in query *)
let result = query_p session
  ~statement:"CREATE (p:Person {name: $person.name, born: $person.born})"
  ~parameters:params
  ()
```

## Record Decoding

Use the `Record` module for type-safe field extraction:

```ocaml
open Neo4j_eio

(* Decode exact types with error handling *)
let name = Record.exact_text record "name"    (* Returns (string, Error.t) result *)
let age = Record.exact_int record "age"       (* Returns (int64, Error.t) result *)

(* Access by position or key *)
let value = Record.at record "field_name"     (* Returns (Value.value, Error.t) result *)
let value = Record.at_index record 0          (* Returns (Value.value, Error.t) result *)

(* Optional access *)
let maybe_name = Record.maybe_at record "name"   (* Returns Value.value option *)
let maybe_exact = Record.maybe_exact_text record "name"  (* Returns string option *)
```

## Graph Types

Neo4j graph entities are represented as OCaml records:

```ocaml
type node = {
  node_id: int64;
  node_labels: string list;
  node_props: Value.value Value.StringMap.t;
}

type relationship = {
  rel_id: int64;
  start_node_id: int64;
  end_node_id: int64;
  rel_type: string;
  rel_props: Value.value Value.StringMap.t;
}

type path = {
  path_nodes: node list;
  path_rels: unbound_relationship list;
  path_sequence: int list;
}
```

Example usage:

```ocaml
match query session ~statement:"MATCH (p:Person {name: 'Alice'}) RETURN p" () with
| Ok [[Value.Node node]] ->
    Printf.printf "Node ID: %Ld\n" node.node_id;
    Printf.printf "Labels: %s\n" (String.concat ", " node.node_labels);
    (match Value.StringMap.find_opt "name" node.node_props with
     | Some (Value.Text name) -> Printf.printf "Name: %s\n" name
     | _ -> ())
| _ -> ()
```

## Transactions

### Explicit Transactions

```ocaml
let create_user session name age =
  match Session.begin_transaction session () with
  | Error e -> Error e
  | Ok () ->
      match Neo4j.query_p session
        ~statement:"CREATE (p:Person {name: $name, age: $age})"
        ~parameters:(Neo4j.props [
          "name" =: Value.Text name;
          "age" =: Value.Int age;
        ])
        () with
      | Error e ->
          let _ = Session.rollback session in
          Error e
      | Ok _ ->
          Session.commit session
```

### Functional Transactions

The `transact` helper automatically commits on success and rolls back on error:

```ocaml
let transfer_data session =
  Session.transact session (fun tx ->
    match Neo4j.query tx ~statement:"CREATE (n:Node {id: 1})" () with
    | Error e -> Error e
    | Ok _ ->
        match Neo4j.query tx ~statement:"CREATE (n:Node {id: 2})" () with
        | Error e -> Error e  (* Automatic rollback *)
        | Ok _ -> Ok ()       (* Automatic commit *)
  )
```

## Streaming Large Results

For large result sets, use streaming to avoid loading everything into memory:

```ocaml
(* Create a stream with custom fetch size *)
match Session.run_stream session
  ~statement:"UNWIND range(1, 1000000) AS n RETURN n"
  ~fetch_size:100L
  () with
| Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
| Ok stream ->
    (* Process chunks lazily *)
    let rec consume () =
      if stream.exhausted then
        ()
      else
        match stream.fetch_next () with
        | Error e -> Printf.eprintf "Fetch error: %s\n" (Error.to_string e)
        | Ok chunk ->
            Printf.printf "Got %d records\n" (List.length chunk);
            consume ()
    in
    consume ()

(* Or materialize entire stream *)
match Session.run_stream session ~statement:"..." () with
| Ok stream -> Session.stream_to_list stream
| Error e -> Error e
```

## Temporal and Spatial Types

Neo4j v2 types are fully supported:

```ocaml
(* Point types *)
type point2d = { srid: int64; x: float; y: float }
type point3d = { srid: int64; x: float; y: float; z: float }

(* Temporal types *)
type duration = { months: int64; days: int64; seconds: int64; nanoseconds: int64 }
type date = { days_since_epoch: int64 }
type local_time = { nanoseconds_since_midnight: int64 }
type time = { nanoseconds_since_midnight: int64; timezone_offset_seconds: int64 }
type local_datetime = { seconds_since_epoch: int64; nanoseconds: int64 }
type datetime_offset = { seconds_since_epoch: int64; nanoseconds: int64; timezone_offset_seconds: int64 }
type datetime_zone_id = { seconds_since_epoch: int64; nanoseconds: int64; timezone_id: string }
```

Example:

```ocaml
match query session ~statement:"RETURN point({x: 1.5, y: 2.5}) AS pt" () with
| Ok [[Value.Point2D pt]] ->
    Printf.printf "Point: (%f, %f) SRID: %Ld\n" pt.x pt.y pt.srid
| _ -> ()

match query session ~statement:"RETURN duration('P1Y2M3DT4H5M6S') AS d" () with
| Ok [[Value.Duration d]] ->
    Printf.printf "Duration: %Ld months, %Ld days, %Ld seconds\n"
      d.months d.days d.seconds
| _ -> ()
```

## Error Handling

All operations return `(result, Error.t) result`:

```ocaml
type error =
  | Protocol of string
  | Io of string
  | Auth of string
  | Server of { code: string; message: string }
  | Decode of string
  | Record_error of string

let to_string : error -> string
let from_failure_map : Value.value Value.StringMap.t -> error
```

Example error handling:

```ocaml
match query session ~statement:"INVALID CYPHER" () with
| Ok records -> (* Process records *)
| Error (Server { code; message }) ->
    Printf.eprintf "Server error %s: %s\n" code message
| Error (Protocol msg) ->
    Printf.eprintf "Protocol error: %s\n" msg
| Error e ->
    Printf.eprintf "Error: %s\n" (Error.to_string e)
```

## Testing with Docker

Start Neo4j with Docker Compose:

```yaml
# docker-compose.yml
services:
  neo4j:
    image: neo4j:5
    ports:
      - "7474:7474"  # HTTP
      - "7687:7687"  # Bolt
    environment:
      NEO4J_AUTH: neo4j/testpass
```

```bash
docker compose up -d neo4j

# Set environment variables
export NEO4J_URI=bolt://localhost:7687
export NEO4J_USER=neo4j
export NEO4J_PASSWORD=testpass

# Run tests
dune runtest
```

## Concurrency

Each `Session` serializes access with a mutex, making it safe to use from multiple Eio fibers. However, only one request can be in-flight at a time per session.

For concurrent queries, create multiple sessions:

```ocaml
Eio.Switch.run @@ fun sw ->
  Eio.Fiber.both
    (fun () ->
      Session.with_session ~sw ~net cfg (fun s1 ->
        Neo4j.query s1 ~statement:"RETURN 1" ()
      )
    )
    (fun () ->
      Session.with_session ~sw ~net cfg (fun s2 ->
        Neo4j.query s2 ~statement:"RETURN 2" ()
      )
    )
```

## Protocol Compatibility

- **Neo4j 5.x**: Bolt v5 (primary)
- **Neo4j 4.x**: Bolt v4
- **Neo4j 3.5+**: Bolt v3

The driver negotiates the highest supported version automatically.

## Examples

See the `examples/` directory for complete working examples:

- `simple_query.ml` - Basic queries and parameter usage
- `transactions.ml` - Transaction patterns
- `graph_types.ml` - Working with nodes, relationships, and paths
- `streaming.ml` - Streaming large result sets

## API Documentation

Module structure:

- `Neo4j_eio.Value` - All PackStream value types and graph entities
- `Neo4j_eio.Config` - Connection configuration
- `Neo4j_eio.Session` - Session management and low-level API
- `Neo4j_eio.Neo4j` - High-level query API (`query`, `query_p`, `=:`, `props`)
- `Neo4j_eio.Record` - Record decoding helpers
- `Neo4j_eio.Error` - Error types and handling
- `Neo4j_eio.Connection` - Low-level connection (advanced)
- `Neo4j_eio.Protocol` - Bolt protocol messages (advanced)
- `Neo4j_eio.Packstream` - PackStream encoding/decoding (advanced)

## License

MIT License

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass: `dune runtest`
2. Code is formatted: `dune build @fmt`
3. New features include tests and documentation
