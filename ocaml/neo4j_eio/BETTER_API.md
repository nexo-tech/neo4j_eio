# Neo4j_eio Better API Design

This document outlines a comprehensive plan for improving the neo4j_eio API to be more elegant, composable, and ergonomic while maintaining type safety and performance.

## Master Checklist

### Phase 1 — Result Monad Utilities (Foundation)
- [ ] Task 1.1: Result monad combinators and operators (~200 lines)
- [ ] Task 1.2: Let-syntax bindings for Result (~150 lines)
- [ ] Task 1.3: Result-based query helpers (~200 lines)

### Phase 2 — Applicative Extractors
- [ ] Task 2.1: Extract monad with applicative operations (~250 lines)
- [ ] Task 2.2: Field extractors (text, int, bool, etc.) (~200 lines)
- [ ] Task 2.3: Composite extractors and examples (~150 lines)

### Phase 3 — Query Builder
- [ ] Task 3.1: Query builder with fluent API (~250 lines)
- [ ] Task 3.2: Parameter binding and composition (~200 lines)
- [ ] Task 3.3: Query execution and examples (~200 lines)

### Phase 4 — Pipeline Operators
- [ ] Task 4.1: Pipeline module with operators (~250 lines)
- [ ] Task 4.2: Query transformation pipeline (~200 lines)
- [ ] Task 4.3: Pipeline examples and tests (~150 lines)

### Phase 5 — Lens-Based Access (Advanced)
- [ ] Task 5.1: Basic lens implementation (~250 lines)
- [ ] Task 5.2: Record and value lenses (~200 lines)
- [ ] Task 5.3: Lens composition and examples (~150 lines)

### Phase 6 — High-Level DSL
- [ ] Task 6.1: Declarative query DSL (~250 lines)
- [ ] Task 6.2: Transaction DSL (~200 lines)
- [ ] Task 6.3: DSL examples and patterns (~150 lines)

### Phase 7 — Integration & Documentation
- [ ] Task 7.1: Update existing examples with new API (~300 lines)
- [ ] Task 7.2: Migration guide and cookbook (~200 lines)
- [ ] Task 7.3: Performance benchmarks and optimization

---

## Current Pain Points

### 1. Nested Pattern Matching Hell
```ocaml
(* Current ugly pattern *)
match query session ~statement:"..." () with
| Ok [record] ->
    (match Record.at_text record "name", Record.at_int record "age" with
     | Ok name, Ok age -> (* use name and age *)
     | _ -> (* error handling */)
| Ok _ -> (* unexpected format *)
| Error e -> (* query error *)
```

### 2. No Composable Query Building
```ocaml
(* Current: Parameters are separate from statement *)
let statement = "CREATE (p:Person {name: $name, age: $age})" in
let parameters = props ["name" =: text "Alice"; "age" =: int 30L] in
match query session ~statement ~parameters () with ...
```

### 3. No Monadic Composition
```ocaml
(* Current: Cannot chain operations elegantly *)
match create_person session "Alice" 30 with
| Ok person_id ->
    match create_order session person_id 100 with
    | Ok order_id -> (* success *)
    | Error e -> (* error *)
| Error e -> (* error *)
```

### 4. Verbose Result Extraction
```ocaml
(* Current: Too much ceremony for simple field access *)
match Record.at_text record "name" with
| Ok name -> Printf.printf "%s\n" name
| Error e -> Format.eprintf "%a" Record.pp_decode_error e
```

## Inspiration from Haskell

### Hasbolt's Elegant API
```haskell
-- Monadic composition with do-notation
runTransaction :: BoltActionT IO ()
runTransaction = do
  records <- queryP "CREATE (p:Person {name: $name}) RETURN p"
                    (props ["name" =: T "Alice"])
  person <- records `at` "p"
  nodeId <- person `at` "id"
  liftIO $ print nodeId

-- Using lens-based accessors
name <- record ^. key "name" . exact :: BoltActionT IO Text
```

### Modern OCaml Patterns
```ocaml
(* let* syntax from OCaml 4.08+ *)
let* x = computation1 in
let* y = computation2 x in
return (x + y)

(* Pipe operators *)
result
|> Result.map (fun x -> x + 1)
|> Result.bind process
|> Result.iter print_int
```

## Proposed Design

### Phase 1: Monadic Query Module

Create a new `Query` module with monadic composition using OCaml's built-in `let*` syntax.

#### 1.1: Core Query Monad
```ocaml
(* File: src/query.mli *)
module Query : sig
  type 'a t  (* Query monad *)

  (* Monadic operations *)
  val return : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val map : ('a -> 'b) -> 'a t -> 'b t
  val (let*) : 'a t -> ('a -> 'b t) -> 'b t
  val (let+) : 'a t -> ('a -> 'b) -> 'b t
  val (and+) : 'a t -> 'b t -> ('a * 'b) t

  (* Query construction *)
  val cypher : string -> 'a t
  val with_params : (string * Value.value) list -> 'a t -> 'a t
  val param : string -> Value.value -> string * Value.value
  val (=:) : string -> Value.value -> string * Value.value

  (* Execution *)
  val run : 'a t -> session -> ('a, Error.t) result
  val run_exn : 'a t -> session -> 'a
end
```

Example usage:
```ocaml
let create_person name age =
  let open Query in
  let* () = cypher "CREATE (p:Person {name: $name, age: $age})"
            |> with_params ["name" =: text name; "age" =: int age] in
  return ()

let find_person name =
  let open Query in
  cypher "MATCH (p:Person {name: $name}) RETURN p"
  |> with_params ["name" =: text name]
```

#### 1.2: Record Extraction DSL
```ocaml
(* File: src/extract.mli *)
module Extract : sig
  type 'a t  (* Extraction monad *)

  (* Monadic operations *)
  val return : 'a -> 'a t
  val (let*) : 'a t -> ('a -> 'b t) -> 'b t
  val (let+) : 'a t -> ('a -> 'b) -> 'b t
  val (and+) : 'a t -> 'b t -> ('a * 'b) t

  (* Field extractors *)
  val field : string -> 'a Record.decoder -> 'a t
  val text : string -> string t
  val int : string -> int64 t
  val bool : string -> bool t
  val float : string -> float t
  val node : string -> Value.node t
  val path : string -> Value.path t

  (* Optional extractors *)
  val optional : 'a t -> 'a option t
  val default : 'a -> 'a t -> 'a t

  (* List extractors *)
  val list : string -> 'a Record.decoder -> 'a list t

  (* Execution *)
  val extract : 'a t -> Record.t -> ('a, Record.decode_error) result
  val extract_exn : 'a t -> Record.t -> 'a
end
```

Example usage:
```ocaml
let person_extractor =
  let open Extract in
  let+ name = text "name"
  and+ age = int "age"
  and+ email = optional (text "email") in
  (name, age, email)

(* Usage *)
match Query.run query session with
| Ok records ->
    List.iter (fun record ->
      match Extract.extract person_extractor record with
      | Ok (name, age, email) -> Printf.printf "%s: %Ld\n" name age
      | Error e -> (* handle error *)
    ) records
| Error e -> (* query error *)
```

#### 1.3: Unified Query Builder
```ocaml
(* File: src/cypher.mli *)
module Cypher : sig
  type 'a t

  (* Query construction *)
  val create : string -> 'a Extract.t -> 'a list t
  val match_ : string -> 'a Extract.t -> 'a list t
  val merge : string -> unit t
  val delete : string -> unit t

  (* With parameters *)
  val (|?) : 'a t -> (string * Value.value) list -> 'a t

  (* Combinators *)
  val single : 'a list t -> 'a option t
  val expect_one : 'a list t -> 'a t
  val first : 'a list t -> 'a option t

  (* Execution *)
  val execute : 'a t -> session -> ('a, Error.t) result
  val (>>=) : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
end
```

Example usage:
```ocaml
let open Cypher in
let person_query =
  match_ "MATCH (p:Person {name: $name}) RETURN p.name AS name, p.age AS age"
    Extract.(let+ name = text "name"
             and+ age = int "age" in
             (name, age))
  |? ["name" =: text "Alice"]
  |> expect_one

match execute person_query session with
| Ok (name, age) -> Printf.printf "%s: %Ld\n" name age
| Error e -> (* error *)
```

### Phase 2: Pipeline Operators

Create fluent pipeline-based API for query composition.

#### 2.1: Query Pipeline Module
```ocaml
(* File: src/pipeline.mli *)
module Pipeline : sig
  type ('a, 'b) t  (* Pipeline from 'a to 'b *)

  (* Core operators *)
  val (|>>) : 'a -> ('a -> 'b) -> 'b  (* Forward pipe *)
  val (>>|) : ('a -> 'b) -> ('b -> 'c) -> 'a -> 'c  (* Composition *)
  val (>>=) : 'a t -> ('a -> 'b t) -> 'b t  (* Monadic bind *)
  val (>>?) : ('a, Error.t) result t -> ('a -> ('b, Error.t) result t) -> ('b, Error.t) result t

  (* Query stages *)
  val query : string -> Record.t list t
  val with_params : (string * Value.value) list -> 'a t -> 'a t
  val extract : 'a Extract.t -> Record.t list t -> 'a list t
  val map_records : (Record.t -> 'a) -> Record.t list t -> 'a list t
  val filter : ('a -> bool) -> 'a list t -> 'a list t
  val take : int -> 'a list t -> 'a list t
  val head : 'a list t -> 'a option t

  (* Execution *)
  val run : 'a t -> session -> ('a, Error.t) result
end
```

Example usage:
```ocaml
let find_persons_pipeline =
  Pipeline.(
    query "MATCH (p:Person) WHERE p.age > $min_age RETURN p.name, p.age"
    |> with_params ["min_age" =: int 18L]
    |> extract Extract.(let+ name = text "name" and+ age = int "age" in (name, age))
    |> filter (fun (_, age) -> age < 65L)
    |> take 10
  )

let result = Pipeline.run find_persons_pipeline session
```

#### 2.2: Infix Combinators
```ocaml
(* File: src/combinators.mli *)
module Combinators : sig
  (* Result combinators *)
  val (let*) : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
  val (let+) : ('a, 'e) result -> ('a -> 'b) -> ('b, 'e) result
  val (and+) : ('a, 'e) result -> ('b, 'e) result -> ('a * 'b, 'e) result
  val (>>|) : ('a, 'e) result -> ('a -> 'b) -> ('b, 'e) result
  val (>>=) : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result

  (* Query combinators *)
  val (@>) : string -> (string * Value.value) list -> Query.t
  val (@@) : Query.t -> 'a Extract.t -> ('a list, Error.t) result
  val (@!) : ('a list, Error.t) result -> ('a -> 'b) -> ('b list, Error.t) result

  (* Extraction combinators *)
  val (<$>) : ('a -> 'b) -> 'a Extract.t -> 'b Extract.t
  val (<*>) : ('a -> 'b) Extract.t -> 'a Extract.t -> 'b Extract.t
  val (<|>) : 'a Extract.t -> 'a Extract.t -> 'a Extract.t  (* Alternative *)
end
```

Example usage:
```ocaml
let open Combinators in

(* Applicative style *)
let person =
  (fun name age email -> {name; age; email})
  <$> Extract.text "name"
  <*> Extract.int "age"
  <*> Extract.optional (Extract.text "email")

(* Query with infix *)
let result =
  "MATCH (p:Person {name: $name}) RETURN p" @> ["name" =: text "Alice"]
  @@ person
  >>| List.hd
```

### Phase 3: Lens-Based Accessors

Implement lens/optics-based field access inspired by Haskell's lens library.

#### 3.1: Lens Module
```ocaml
(* File: src/lens.mli *)
module Lens : sig
  type ('s, 'a) t  (* Lens from 's to 'a *)

  (* Lens construction *)
  val lens : ('s -> 'a) -> ('s -> 'a -> 's) -> ('s, 'a) t
  val field : string -> (Record.t, Value.value) t

  (* Lens operators *)
  val (^.) : 's -> ('s, 'a) t -> 'a  (* View *)
  val (^?) : 's -> ('s, 'a) t -> 'a option  (* Preview *)
  val (.~) : ('s, 'a) t -> 'a -> 's -> 's  (* Set *)
  val (%~) : ('s, 'a) t -> ('a -> 'a) -> 's -> 's  (* Over/modify *)
  val (^..) : 's -> ('s, 'a) t -> 'a list  (* ToList *)

  (* Composition *)
  val (>>>) : ('a, 'b) t -> ('b, 'c) t -> ('a, 'c) t

  (* Prisms for value types *)
  val text : (Value.value, string) t
  val int : (Value.value, int64) t
  val bool : (Value.value, bool) t
  val node : (Value.value, Value.node) t

  (* Record lenses *)
  val at : string -> (Record.t, Value.value option) t
  val key : string -> (Record.t, Value.value) t
end
```

Example usage:
```ocaml
let open Lens in

(* Access nested values *)
let name = record ^. key "person" >>> key "name" >>> text
let age = record ^. key "person" >>> key "age" >>> int

(* Optional access *)
let email = record ^? key "person" >>> key "email" >>> text

(* Modify values *)
let updated = record |> (key "age" >>> int) .~ 31L
```

#### 3.2: Traversal Module
```ocaml
(* File: src/traversal.mli *)
module Traversal : sig
  type ('s, 'a) t

  (* Traversal construction *)
  val traverse : ('s -> 'a list) -> ('s, 'a) t
  val each : ('a list, 'a) t
  val records : (Record.t list, Record.t) t

  (* Traversal operators *)
  val (^..) : 's -> ('s, 'a) t -> 'a list  (* ToList *)
  val (.~) : ('s, 'a) t -> 'a -> 's -> 's  (* Set all *)
  val (%~) : ('s, 'a) t -> ('a -> 'a) -> 's -> 's  (* Map *)
  val (^?) : 's -> ('s, 'a) t -> 'a option  (* First *)

  (* Fold *)
  val fold : ('b -> 'a -> 'b) -> 'b -> ('s, 'a) t -> 's -> 'b
  val sum : ('s, int64) t -> 's -> int64
  val any : ('a -> bool) -> ('s, 'a) t -> 's -> bool
end
```

Example usage:
```ocaml
let open Traversal in

(* Extract all names from records *)
let names =
  records_list
  ^.. records
  >>> Lens.key "name"
  >>> Lens.text

(* Sum all ages *)
let total_age =
  fold (+) 0L
    (records >>> Lens.key "age" >>> Lens.int)
    records_list
```

### Phase 4: High-Level DSL

Create a declarative DSL for common patterns.

#### 4.1: Query Builder DSL
```ocaml
(* File: src/dsl.mli *)
module DSL : sig
  (* Query builder *)
  type 'a builder

  val select : string list -> 'a builder
  val from : string -> 'a builder -> 'a builder
  val where : string -> 'a builder -> 'a builder
  val order_by : string -> 'a builder -> 'a builder
  val limit : int -> 'a builder -> 'a builder
  val with_params : (string * Value.value) list -> 'a builder -> 'a builder

  (* Execution *)
  val returning : 'a Extract.t -> 'a builder -> 'a list Query.t
  val build : 'a builder -> string * (string * Value.value) list
end
```

Example usage:
```ocaml
let open DSL in

let query =
  select ["p.name", "p.age"]
  |> from "(p:Person)"
  |> where "p.age > $min_age"
  |> order_by "p.age DESC"
  |> limit 10
  |> with_params ["min_age" =: int 18L]
  |> returning Extract.(let+ name = text "name" and+ age = int "age" in (name, age))
```

#### 4.2: Transaction DSL
```ocaml
(* File: src/transaction_dsl.mli *)
module TransactionDSL : sig
  type 'a t

  (* Transaction operations *)
  val begin_ : unit -> unit t
  val commit : unit t
  val rollback : unit t

  (* Query in transaction *)
  val exec : 'a Query.t -> 'a t
  val exec_ : unit Query.t -> unit t

  (* Control flow *)
  val when_ : bool -> unit t -> unit t
  val unless : bool -> unit t -> unit t
  val retry : int -> 'a t -> 'a t

  (* Combinators *)
  val (let*) : 'a t -> ('a -> 'b t) -> 'b t
  val sequence : 'a t list -> 'a list t

  (* Execution *)
  val run : 'a t -> session -> ('a, Error.t) result
  val run_exn : 'a t -> session -> 'a
end
```

Example usage:
```ocaml
let open TransactionDSL in

let transfer_funds from_id to_id amount =
  let* () = exec (debit_account from_id amount) in
  let* () = exec (credit_account to_id amount) in
  commit

let result = run (transfer_funds 1 2 100) session
```

### Phase 5: PPX Extensions (Optional)

Add PPX syntax extensions for even more ergonomic code.

#### 5.1: Record Extraction PPX
```ocaml
(* Using PPX *)
let%extract {name; age; email} = record in
Printf.printf "%s: %d\n" name age

(* Expands to *)
let open Extract in
match extract (let+ name = text "name"
               and+ age = int "age"
               and+ email = optional (text "email") in
               (name, age, email)) record with
| Ok (name, age, email) -> Printf.printf "%s: %d\n" name age
| Error e -> (* error *)
```

#### 5.2: Query Interpolation PPX
```ocaml
(* Using PPX *)
let%cypher records =
  {|MATCH (p:Person {name: $name}) RETURN p|}
  ~name:"Alice"
in
(* Process records *)

(* Expands to proper query execution *)
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- **Task 1.1**: Implement Query monad with let* syntax
- **Task 1.2**: Implement Extract monad with applicative operators
- **Task 1.3**: Create unified Cypher query builder
- **Task 1.4**: Add comprehensive tests for monadic composition

### Phase 2: Operators (Week 3)
- **Task 2.1**: Implement Pipeline module with operator overloading
- **Task 2.2**: Create Combinators module with infix operators
- **Task 2.3**: Add pipe-based query composition
- **Task 2.4**: Create examples showing operator usage

### Phase 3: Optics (Week 4-5)
- **Task 3.1**: Implement Lens module for record field access
- **Task 3.2**: Implement Traversal module for collections
- **Task 3.3**: Create Prism module for value type access
- **Task 3.4**: Add lens-based examples

### Phase 4: DSL (Week 6)
- **Task 4.1**: Implement query builder DSL
- **Task 4.2**: Implement transaction DSL
- **Task 4.3**: Create pattern matching DSL
- **Task 4.4**: Add high-level DSL examples

### Phase 5: Polish (Week 7-8)
- **Task 5.1**: Optimize performance of monadic code
- **Task 5.2**: Add PPX extensions (optional)
- **Task 5.3**: Update all examples to use new API
- **Task 5.4**: Write migration guide from old API
- **Task 5.5**: Comprehensive documentation with comparisons

## API Comparison

### Before (Current):
```ocaml
match query session
  ~statement:"CREATE (p:Person {name: $name, age: $age}) RETURN p.name AS name, p.age AS age"
  ~parameters:(props ["name" =: text "Alice"; "age" =: int 30L])
  () with
| Ok [record] ->
    (match Record.at_text record "name", Record.at_int record "age" with
     | Ok name, Ok age -> Printf.printf "%s: %Ld\n" name age
     | _ -> Printf.printf "Decode error\n")
| Ok _ -> Printf.printf "Unexpected format\n"
| Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
```

### After (Monadic):
```ocaml
let open Cypher in
let person =
  create "CREATE (p:Person {name: $name, age: $age}) RETURN p.name AS name, p.age AS age"
    Extract.(let+ name = text "name" and+ age = int "age" in (name, age))
  |? ["name" =: text "Alice"; "age" =: int 30L]
  |> expect_one

match execute person session with
| Ok (name, age) -> Printf.printf "%s: %Ld\n" name age
| Error e -> Printf.eprintf "Error: %s\n" (Error.to_string e)
```

### After (Pipeline):
```ocaml
let open Pipeline in
"CREATE (p:Person {name: $name, age: $age}) RETURN p.name, p.age"
|> with_params ["name" =: text "Alice"; "age" =: int 30L]
|> extract Extract.(let+ name = text "name" and+ age = int "age" in (name, age))
|> head
|> run session
>>| function
| Some (name, age) -> Printf.printf "%s: %Ld\n" name age
| None -> Printf.printf "Not found\n"
```

### After (Lens):
```ocaml
let open Lens in
let person_name = key "name" >>> text in
let person_age = key "age" >>> int in

match query session "..." with
| Ok [record] ->
    let name = record ^. person_name in
    let age = record ^. person_age in
    Printf.printf "%s: %Ld\n" name age
| _ -> (* error *)
```

## Design Principles

1. **Composability**: All operations should compose naturally
2. **Type Safety**: Leverage OCaml's type system for compile-time guarantees
3. **Ergonomics**: Minimize boilerplate and ceremony
4. **Performance**: Zero-cost abstractions where possible
5. **Gradual Adoption**: New API coexists with old, allows migration
6. **Discoverability**: Clear naming and documentation
7. **Correctness**: Comprehensive tests for all combinators

## Success Metrics

- [ ] Reduce code verbosity by 50% for common patterns
- [ ] Eliminate nested pattern matching in 90% of cases
- [ ] Enable point-free style where beneficial
- [ ] Achieve same or better performance as current API
- [ ] 100% test coverage for new modules
- [ ] Migration guide covers all use cases
- [ ] Documentation with 50+ examples

## Notes

- Inspired by: Haskell's `persistent`, `esqueleto`, `opaleye`, and `lens` libraries
- OCaml patterns from: Jane Street's `ppx_let`, `Core`, and monadic libraries
- Balance between Haskell's elegance and OCaml's pragmatism
- Maintain compatibility with Eio's effects-based model
- Consider error handling at every composition point
