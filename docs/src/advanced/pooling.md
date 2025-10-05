# Connection Pooling Best Practices

neo4j_eio does not currently include a built‑in connection pool. Each `Session` wraps a single connection and serializes requests. This page outlines pragmatic patterns to pool sessions at the application level using Eio.

When to pool
- You need higher concurrency than a single session provides.
- You want to amortize handshake/authentication overhead across many requests.

Simple fixed‑size pool (example)
```ocaml
open Neo4j_eio

module Pool = struct
  type t = { sem: Eio.Semaphore.t; mutable stash: ([ `Generic | `Unix ] Eio.Net.stream_socket_ty Eio.Resource.t) Session.t list; cfg: Config.t; env: < net : _ Eio.Net.t ; .. >; sw: Eio.Switch.t }

  let create ~sw ~env ~cfg ~size = { sem = Eio.Semaphore.make size; stash = []; cfg; env; sw }

  let acquire pool =
    Eio.Semaphore.acquire pool.sem;
    match pool.stash with
    | s :: rest -> pool.stash <- rest; Ok s
    | [] ->
        (* Create a new session on demand *)
        Session.with_session ~sw:pool.sw ~net:pool.env#net pool.cfg (fun s -> Ok s)

  let release pool s =
    pool.stash <- s :: pool.stash;
    Eio.Semaphore.release pool.sem

  let with_session pool f =
    match acquire pool with
    | Error e -> Error e
    | Ok s ->
        Fun.protect
          ~finally:(fun () -> release pool s)
          (fun () -> f s)
end
```

Usage
```ocaml
Eio_main.run @@ fun env ->
  let cfg = Config.of_env () in
  Eio.Switch.run @@ fun sw ->
    let pool = Pool.create ~sw ~env ~cfg ~size:8 in
    Eio.Fiber.all [
      (fun () -> ignore (Pool.with_session pool (fun s -> Query_builder.execute (Query_builder.raw "RETURN 1 AS n") s)));
      (fun () -> ignore (Pool.with_session pool (fun s -> Query_builder.execute (Query_builder.raw "RETURN 2 AS n") s)));
    ]
```

Operational guidance
- Size the pool to expected parallelism and server capacity; start small (e.g., number of CPU cores) and measure.
- Validate sessions on checkout if you suspect a prior failure (e.g., run `Session.reset s` or a no‑op `RETURN 1`).
- On severe errors, drop the session instead of returning it to the pool.
- Keep transactions short; long‑lived transactions tie up pooled sessions.
- Tune `~fetch_size` for streaming workloads to reduce time each session is held.

Current limitations
- Hostname in `NEO4J_URI` is ignored by the current connection path; connections target `127.0.0.1` with the specified port.
- TLS is not enabled in the session connection path yet; keep `bolt://` URIs and `NEO4J_TLS` unset.

Alternatives
- If pooling complexity isn’t needed, create one session per concurrent request using `Session.with_session` under a shared `Eio.Switch`.
