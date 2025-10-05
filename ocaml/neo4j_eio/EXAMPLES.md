# Neo4j_eio Examples Plan

This document defines a concrete plan for creating comprehensive examples demonstrating the neo4j_eio library. Each subtask is limited to 200-300 lines of code for clarity and maintainability.

## Master Checklist

- Phase 1 — Basic Examples
  - Task 1.1: Simple queries and parameter substitution
  - Task 1.2: Error handling patterns
  - Task 1.3: Working with graph types (Node/Relationship/Path)
- Phase 2 — Advanced Examples
  - Task 2.1: Transaction patterns (explicit and functional)
  - Task 2.2: Streaming and memory-efficient processing
  - Task 2.3: Temporal and spatial types (v2)
- Phase 3 — Real-World Examples
  - Task 3.1: Basic CRUD operations
  - Task 3.2: Graph traversal patterns
  - Task 3.3: Batch operations and performance

## Phase 1 — Basic Examples

### Task 1.1: Simple queries and parameter substitution
- File: `examples/01_simple_queries.ml`
- Demonstrates:
  - Basic RETURN queries
  - Parameter substitution with `$name` syntax
  - Using `props` and `=:` helpers
  - `query`, `query_p`, `query_`, `query_p_` functions
  - Extracting values from results
- Acceptance: Compiles, runs against Neo4j, demonstrates all query functions
- Size: ~150 lines

### Task 1.2: Error handling patterns
- File: `examples/02_error_handling.ml`
- Demonstrates:
  - Syntax error handling (ClientError)
  - Type mismatch handling
  - Connection errors
  - Result pattern matching
  - Error.to_string usage
  - Recovery patterns
- Acceptance: Compiles, runs, shows all error types
- Size: ~150 lines

### Task 1.3: Working with graph types
- File: `examples/03_graph_types.ml`
- Demonstrates:
  - Creating and reading Node objects
  - Creating and reading Relationship objects
  - Creating and reading Path objects
  - Accessing node labels and properties
  - Accessing relationship types and properties
  - Path traversal
- Acceptance: Compiles, runs, demonstrates all graph types
- Size: ~200 lines

## Phase 2 — Advanced Examples

### Task 2.1: Transaction patterns
- File: `examples/04_transactions.ml`
- Demonstrates:
  - Explicit BEGIN/COMMIT/ROLLBACK
  - `transact` helper for automatic rollback
  - Transaction isolation
  - Multi-query transactions
  - Error handling in transactions
  - Rollback verification
- Acceptance: Compiles, runs, demonstrates commit and rollback
- Size: ~200 lines

### Task 2.2: Streaming and memory-efficient processing
- File: `examples/05_streaming.ml`
- Demonstrates:
  - Strict materialization with `Session.run`
  - Streaming with `Session.run_stream`
  - Custom fetch sizes
  - Stream.fetch_next() loop
  - Session.stream_to_list helper
  - Memory-efficient aggregation
  - Early termination
- Acceptance: Compiles, runs, shows memory efficiency
- Size: ~250 lines

### Task 2.3: Temporal and spatial types
- File: `examples/06_temporal_spatial.ml`
- Demonstrates:
  - Point2D and Point3D (Cartesian and WGS-84)
  - Duration types
  - Date, Time, LocalTime
  - LocalDateTime
  - DateTimeOffset and DateTimeZoneId
  - Extracting fields from temporal types
  - Using temporal types in queries
- Acceptance: Compiles, runs, demonstrates all v2 types
- Size: ~250 lines

## Phase 3 — Real-World Examples

### Task 3.1: Basic CRUD operations
- File: `examples/07_crud.ml`
- Demonstrates:
  - Create: Creating nodes and relationships
  - Read: MATCH patterns and RETURN
  - Update: SET property operations
  - Delete: DELETE and DETACH DELETE
  - MERGE operations
  - Using UNWIND for batch creates
- Acceptance: Compiles, runs, shows complete CRUD cycle
- Size: ~200 lines

### Task 3.2: Graph traversal patterns
- File: `examples/08_traversal.ml`
- Demonstrates:
  - Variable-length paths `[:KNOWS*1..3]`
  - Shortest path queries
  - Pattern comprehension
  - OPTIONAL MATCH
  - Collecting results
  - Graph algorithms (simple pathfinding)
- Acceptance: Compiles, runs, demonstrates traversal
- Size: ~250 lines

### Task 3.3: Batch operations and performance
- File: `examples/09_batch.ml`
- Demonstrates:
  - UNWIND for batch inserts
  - Parameterized batch operations
  - Transaction batching for performance
  - Streaming large imports
  - Avoiding Cartesian products
  - Index usage patterns
- Acceptance: Compiles, runs, shows performance patterns
- Size: ~250 lines

## Example Structure Template

Each example should follow this structure:

```ocaml
(* File: examples/NN_name.ml *)
(* Description: What this example demonstrates *)

open Neo4j_eio

(* Example 1: Brief description *)
let example_1 session =
  Printf.printf "Example 1: Brief description\n";
  (* ... implementation ... *)
  ()

(* Example 2: Brief description *)
let example_2 session =
  Printf.printf "\nExample 2: Brief description\n";
  (* ... implementation ... *)
  ()

(* Cleanup helper *)
let cleanup session =
  (* Clean up any test data *)
  ()

(* Main entry point *)
let () =
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in

    Printf.printf "Example: Name\n";
    Printf.printf "=============\n\n";

    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        example_1 session;
        example_2 session;
        (* ... more examples ... *)
        cleanup session;
        Ok ()
      ) with
      | Ok () ->
          Printf.printf "\nAll examples completed!\n"
      | Error e ->
          Printf.eprintf "\nError: %s\n" (Error.to_string e);
          exit 1
```

## Common Patterns

### Value Construction Helpers
```ocaml
open Neo4j

(* Use these helpers instead of constructors *)
let params = props [
  "name" =: Value.text "Alice";
  "age" =: Value.int 30L;
  "score" =: Value.float 95.5;
  "active" =: Value.bool true;
]
```

### Result Pattern Matching
```ocaml
(* Single field result *)
match query session ~statement:"RETURN 1 AS n" () with
| Ok [Value.Int n] -> Printf.printf "Got: %Ld\n" n
| Ok _ -> Printf.printf "Unexpected format\n"
| Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)

(* Multiple field result *)
match query session ~statement:"RETURN 1 AS a, 2 AS b" () with
| Ok [Value.Int a; Value.Int b] -> Printf.printf "a=%Ld b=%Ld\n" a b
| Ok _ -> Printf.printf "Unexpected format\n"
| Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)

(* Multiple record result (UNWIND) *)
match query session ~statement:"UNWIND [1,2,3] AS n RETURN n" () with
| Ok values ->
    List.iter (function
      | Value.Int n -> Printf.printf "%Ld\n" n
      | _ -> ()
    ) values
| Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
```

### Cleanup Pattern
```ocaml
(* Use unique labels for test data *)
let label = Printf.sprintf "Test_%d" (Random.int 1000000) in

(* ... create test data with label ... *)

(* Cleanup at end *)
let _ = Neo4j.query_ session
  ~statement:(Printf.sprintf "MATCH (n:%s) DETACH DELETE n" label)
  () in
()
```

## Build Configuration

All examples share a single dune file:

```
(executables
 (names
   01_simple_queries
   02_error_handling
   03_graph_types
   04_transactions
   05_streaming
   06_temporal_spatial
   07_crud
   08_traversal
   09_batch)
 (libraries neo4j_eio eio eio_main))
```

## Running Examples

```bash
# Set environment
export NEO4J_URI=bolt://localhost:7687
export NEO4J_USER=neo4j
export NEO4J_PASSWORD=testpass

# Build all examples
dune build examples/

# Run a specific example
dune exec examples/01_simple_queries.exe

# Or run directly
./_build/default/examples/01_simple_queries.exe
```

## Documentation Integration

After all examples are complete:
- Add examples/ section to README.md
- Reference specific examples for each feature
- Include output snippets in README
- Ensure examples compile and run in CI

## Acceptance Criteria

Each example must:
1. Compile without warnings
2. Run successfully against Neo4j 5
3. Clean up all test data
4. Be self-contained (no dependencies between examples)
5. Include clear comments explaining each step
6. Use unique labels to avoid conflicts
7. Follow the consistent structure template
8. Be 200-300 lines maximum (except where noted)
9. Demonstrate real-world usage patterns
10. Handle errors appropriately
