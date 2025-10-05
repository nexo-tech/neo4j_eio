OCaml Eio Driver Parity Inventory (Hasbolt)

Purpose
- Enumerate hasbolt’s public API, datatypes, errors, and behaviors to reproduce with OCaml + Eio.
- Serve as the authoritative checklist for functional parity.

Top-Level APIs (Strict vs Lazy)
- Strict API re-exports (Database.Bolt):
  - `query : Text -> BoltActionT m [Record]` hasbolt/src/Database/Bolt.hs:17
  - `queryP : Text -> Map Text Value -> BoltActionT m [Record]` hasbolt/src/Database/Bolt.hs:21
  - `query_ : Text -> BoltActionT m ()` hasbolt/src/Database/Bolt/Connection.hs:40
  - `queryP_ : Text -> Map Text Value -> BoltActionT m ()` hasbolt/src/Database/Bolt/Connection.hs:36
  - `transact : BoltActionT m a -> BoltActionT m a` hasbolt/src/Database/Bolt/Transaction.hs:10
  - `connect : BoltCfg -> m Pipe` (via Pipe.connect) hasbolt/src/Database/Bolt/Connection/Pipe.hs:19
  - `close : Pipe -> m ()` hasbolt/src/Database/Bolt/Connection/Pipe.hs:31
  - `reset : Pipe -> m ()` hasbolt/src/Database/Bolt/Connection/Pipe.hs:36
  - `run, runE` to execute `BoltActionT` hasbolt/src/Database/Bolt/Connection.hs:23
- Lazy API (Database.Bolt.Lazy): re-exports the lazy `query`, `queryP` from Connection.

Core Monads and Types
- `BoltActionT m a` — ReaderT Pipe over ExceptT BoltError m hasbolt/src/Database/Bolt/Connection/Type.hs:35
- `Pipe` — active connection + settings hasbolt/src/Database/Bolt/Connection/Type.hs:74
- `BoltCfg` — connection config (host, port, auth, TLS, timeouts, version) hasbolt/src/Database/Bolt/Connection/Type.hs:48
- `Request` — Bolt request ADT (INIT/HELLO, RUN, PULL/DISCARD, BEGIN/COMMIT/ROLLBACK, RESET, GOODBYE) hasbolt/src/Database/Bolt/Connection/Type.hs:95
- `Response` — SUCCESS, RECORD, IGNORED, FAILURE hasbolt/src/Database/Bolt/Connection/Type.hs:85
- `BoltError` — driver errors (UnsupportedServerVersion, AuthentificationFailed, ResetFailed, CannotReadChunk, WrongMessageFormat, NoStructureInResponse, ResponseError, RecordHasNoKey, NonHasboltError, TimeOut) hasbolt/src/Database/Bolt/Connection/Type.hs:19
- `ResponseError` — server failure mapped to Known/Unknown hasbolt/src/Database/Bolt/Connection/Type.hs:12

Values and Records
- `Value` — `N | B | I | F | T | L | M | S` hasbolt/src/Database/Bolt/Value/Type.hs:80
- `Structure` — signature + fields hasbolt/src/Database/Bolt/Value/Type.hs:28
- `IsValue` — typeclass to pack into `Value` hasbolt/src/Database/Bolt/Value/Type.hs:95
- `BoltValue` — pack/unpack class for PackStream hasbolt/src/Database/Bolt/Value/Type.hs:55
- `FromStructure/ToStructure` — convert `Structure` <=/=> typed values hasbolt/src/Database/Bolt/Value/Type.hs:44
- Graph entities (FromStructure instances):
  - `Node { nodeIdentity :: Int, labels :: [Text], nodeProps :: Map Text Value }` hasbolt/src/Database/Bolt/Value/Type.hs:119
  - `Relationship { relIdentity :: Int, startNodeId :: Int, endNodeId :: Int, relType :: Text, relProps :: Map Text Value }` hasbolt/src/Database/Bolt/Value/Type.hs:127
  - `URelationship { urelIdentity :: Int, urelType :: Text, urelProps :: Map Text Value }` hasbolt/src/Database/Bolt/Value/Type.hs:135
  - `Path { pathNodes :: [Node], pathRelationships :: [URelationship], pathSequence :: [Int] }` hasbolt/src/Database/Bolt/Value/Type.hs:142
- `Record` — `Map Text Value` hasbolt/src/Database/Bolt/Record.hs:18
- Record extraction
  - `class RecordValue a` with `exactEither` hasbolt/src/Database/Bolt/Record.hs:21
  - `exact`, `exactMaybe` hasbolt/src/Database/Bolt/Record.hs:24
  - `at :: Record -> Text -> BoltActionT m a` hasbolt/src/Database/Bolt/Record.hs:61
  - `maybeAt :: Record -> Text -> BoltActionT m (Maybe a)` hasbolt/src/Database/Bolt/Record.hs:67
- Helpers
  - `(=:) :: Text -> a -> (Text, Value)` hasbolt/src/Database/Bolt/Value/Type.hs:112
  - `props :: [(Text, Value)] -> Map Text Value` hasbolt/src/Database/Bolt/Value/Type.hs:116

Protocol and Framing
- Handshake proposal: magic `0x6060B017`, version negotiation (client proposes `[version,0,0,0]`; must match `BoltCfg.version`) hasbolt/src/Database/Bolt/Connection/Pipe.hs:87
- INIT/HELLO: `createInit` produces HELLO for v3+ and INIT for v1/v2 hasbolt/src/Database/Bolt/Connection/Instances.hs:49
- Message signatures (RUN, PULL/DISCARD, BEGIN/COMMIT/ROLLBACK, RESET, GOODBYE) constants in hasbolt/src/Database/Bolt/Value/Helpers.hs:83
- Chunked messages: size-prefixed chunks + terminal 0 hasbolt/src/Database/Bolt/Connection/Pipe.hs:57
- Responses decoding to SUCCESS/RECORD/FAILURE/IGNORED hasbolt/src/Database/Bolt/Connection/Instances.hs:22

Connection Management
- `connect`: TCP with optional TLS, timeout wrapping hasbolt/src/Database/Bolt/Connection/Connection.hs:18
- `close`: sends GOODBYE for v3+, then socket close hasbolt/src/Database/Bolt/Connection/Pipe.hs:31
- `reset`: sends RESET, expects SUCCESS hasbolt/src/Database/Bolt/Connection/Pipe.hs:36
- Error recovery: `processError` uses RESET for v3+, ACK_FAILURE for v1/v2 hasbolt/src/Database/Bolt/Connection/Pipe.hs:50

Query Execution
- `querySL strict stmt params` → RUN, PULL_ALL; keys from SUCCESS metadata field `"fields"` hasbolt/src/Database/Bolt/Connection.hs:44
- Strict vs lazy: strict collects fully; lazy uses `unsafeInterleaveIO` to stream while fetching hasbolt/src/Database/Bolt/Connection.hs:64
- `query_` variants discard results via DISCARD_ALL hasbolt/src/Database/Bolt/Connection.hs:33
- Low-level: `sendRawRequest` sends arbitrary Request and returns first SUCCESS, otherwise resets/ack and throws mapped error hasbolt/src/Database/Bolt/Connection.hs:84

Transactions
- `transact`: BEGIN → actions → COMMIT, rollback on exceptions hasbolt/src/Database/Bolt/Transaction.hs:10
- v1/v2 fallback: issues `BEGIN/COMMIT/ROLLBACK` queries; v3+ uses explicit messages hasbolt/src/Database/Bolt/Transaction.hs:21

Error Semantics to Preserve
- Server failures mapped to `KnownResponseFailure code message` (from response map keys `code` and `message`) hasbolt/src/Database/Bolt/Connection/Instances.hs:69
- Driver errors include UnsupportedServerVersion, AuthentificationFailed on HELLO/INIT failure, ResetFailed, CannotReadChunk, WrongMessageFormat (wraps `UnpackError`), RecordHasNoKey, TimeOut.

New Types (Neo4j 3.4+ / PackStream v2)
- README documents Point2D/Point3D, Duration, Date/Time variants with structure signatures; hasbolt does not provide specialized typed wrappers but can carry them as `Structure` within `Value` hasbolt/README.md:52
- OCaml driver must provide typed representations and decode/encode by signatures.

Tests/Examples to Mirror
- From README: simple queries, parameters, record accessors, errors for wrong types/fields, transaction example hasbolt/README.md:18
- Integration: `test/TransactionSpec.hs` covers commit/rollback, syntax error mapping, wrong return type handling, cleanup via `MATCH ... DELETE` hasbolt/test/TransactionSpec.hs:11

Behavioral Invariants
- One in-flight request per connection; errors leave connection failed until RESET/ACK_FAILURE.
- Fetch uses pull loop until SUCCESS terminator; FAILURE triggers reset path then error.
- Keys derive from initial SUCCESS metadata `fields` array.
- `at`/`exact` report precise unpacking errors; `maybeAt` returns None when key missing.

OCaml Parity Targets (Summary)
- Public API functions: connect/close/reset/run/runE/query/query_p/query_/query_p_/transact.
- Types: Value, Structure, Node, Relationship, URelationship, Path, Record, errors, config.
- Protocol: INIT/HELLO, RUN, PULL/DISCARD, BEGIN/COMMIT/ROLLBACK, RESET, GOODBYE; version negotiation; chunked framing.
- Tests: replicate README flows and TransactionSpec scenarios against Docker Neo4j (bolt://localhost:7687, neo4j/test).

