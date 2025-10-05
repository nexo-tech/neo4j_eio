# Cypher (Fluent Pipeline) Reference

Fluent builder, decoder, transformations, and execution for queries (see ocaml/src/cypher.ml).

Build
- `query : string -> 'a t` (base returns `Record.t list`)
- `query_unit : string -> unit t`
- `with_params : (string * Value.value) list -> 'a t -> 'a t`
- Param helpers: `param`, `(=:)`, `props`, `text/int/float/bool/null/list/value_map`

Decode
- `extract : Extract.'a t -> 'a list t`

Shape
- `single : 'a list t -> 'a option t`
- `expect_one : 'a list t -> 'a t`
- `first/head : 'a list t -> 'a option t`
- `take : int -> 'a list t -> 'a list t`

Transform (selection)
- `map`, `filter`, `concat_map/flat_map`, `fold_left/fold_right/reduce`
- Aggregates: `count`, `exists`, `for_all`, `find`, `find_map`, `sum_int/_float`, `average_int/_float`, `min_by`, `max_by`
- Ordering/batching: `sort/_by`, `reverse`, `chunk/batch`, `sliding_window`
- Sets/partition: `distinct`, `deduplicate_by`, `partition`, `group_by`, `span/break_at`, `take_while`, `drop_while`
- Utilities: `nth`, `index_of`, `indexed`, `interleave`, `cons/snoc`, `replicate`, `unzip`, `transpose`, `flatten`
- Errors/control: `or_else`, `catch`, `recover`, `when_ok`, `unless_ok`

Compose
- `let*`, `let+`, `and+`, `(>>=)`, `(>>|)`, `(|>)`
- `sequence`, `sequence_unit`
- Transactions: `in_transaction : (Session.t -> ('a, Error.t) result) -> 'a t`

Execute
- `run : 'a t -> Session.t -> ('a, Error.t) result`
- `run_exn : 'a t -> Session.t -> 'a`
- `run_in/execute : Session.t -> 'a t -> ('a, Error.t) result`
- `run_in_exn/execute_exn`
- Operator: `q |>> session`
