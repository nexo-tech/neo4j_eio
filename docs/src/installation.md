# Installation and Setup

This guide shows how to install neo4j_eio, configure your environment, and verify a first connection to Neo4j. Run all shell commands from the `ocaml/` directory unless stated otherwise.

Requirements
- OCaml 5.1+ (Eio requires OCaml 5)
- Dune 3.9+
- Neo4j 3.5+ (tested with Neo4j 5; negotiates Bolt v5/v4/v3)

Install via opam
- If published: `opam install neo4j_eio`
- From this repo (pin):
  - `cd ocaml`
  - `opam switch create . 5.2.1` (or any 5.1+)
  - `eval $(opam env)`
  - `opam pin add neo4j_eio .` (pulls all deps) or `opam install . --deps-only -y`
  - `dune build`

Run tests locally (requires Neo4j running)
- Start Neo4j with Docker Compose using the provided config:
  - `docker compose up -d neo4j`
  - This exposes Bolt on `bolt://127.0.0.1:7687` with credentials `neo4j/testpass`.
- Export environment variables (optional; these match the compose defaults):
  - `export NEO4J_URI=bolt://127.0.0.1:7687`
  - `export NEO4J_USER=neo4j`
  - `export NEO4J_PASSWORD=testpass`
- Run tests (from `ocaml/`): `dune runtest`

Configure the driver
Use `Config.of_env ()` or build a `Config.t` explicitly. Supported environment variables:
- `NEO4J_URI` or `NEO4J_HOST` + `NEO4J_PORT` (default `bolt://127.0.0.1:7687`)
- `NEO4J_USER` (or `NEO4J_USERNAME`) and `NEO4J_PASSWORD`
- `NEO4J_FETCH_SIZE` (int, default 1000)
- `NEO4J_USER_AGENT` (default `neo4j_eio/0.1.0`)
- `NEO4J_LOG_LEVEL` (`debug|info|warn|error|silent`; default `info`)
- `NEO4J_TLS` (`1|true|yes` to enable) or use `bolt+s://` / `neo4j+s://` in `NEO4J_URI`
- `NEO4J_TLS_CA` (path to a CA file for TLS verification)

TLS notes (current status)
- The current connection path does not enable TLS; keep `NEO4J_TLS` unset and use `bolt://` URIs.
- `bolt+s://` and `NEO4J_TLS=1` are not supported yet in the session path; TLS support is planned.

First connection (sanity check)
This program reads configuration from environment variables and runs a trivial query.

```ocaml
open Neo4j_eio

let () =
  Eio_main.run @@ fun env ->
    let cfg = Config.of_env () in
    Eio.Switch.run @@ fun sw ->
      match Session.with_session ~sw ~net:env#net cfg (fun session ->
        let open Transaction_dsl in
        let tx =
          let* rows = exec_query_builder (Query_builder.raw "RETURN 1 AS ok") in
          match rows with
          | [r] -> (match Record.at_int r "ok" with Ok 1L -> return () | _ -> fail (Error.Protocol "unexpected"))
          | _ -> fail (Error.Protocol "no row")
        in
        Transaction_dsl.run tx session
      ) with
      | Ok () -> Printf.printf "Connected OK\n"
      | Error e -> Printf.eprintf "Connection failed: %s\n" (Error.to_string e)
```

Running examples
- The repository ships several runnable examples under `ocaml/examples`.
- After building, run any of them from `ocaml/`, for example:
  - `dune exec examples/simple_queries.exe`
  - `dune exec examples/transactions.exe`
  - `dune exec examples/streaming.exe`

Common setup issues
- Connection refused: ensure Neo4j is running and `NEO4J_URI` host:port is correct.
- Authentication failed: verify `NEO4J_USER` / `NEO4J_PASSWORD`.
- TLS handshake problems: TLS is currently not enabled; use non-TLS `bolt://` and local Neo4j.

Host targeting (current status)
- Connections are made to `127.0.0.1` (loopback) using the port parsed from `NEO4J_URI`.
- Ensure Neo4j is running locally (e.g., via the provided Docker Compose) and listen on the specified Bolt port.
