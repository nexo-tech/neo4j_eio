(** DSL Patterns and Best Practices

    This demonstrates advanced patterns combining Query Builder DSL
    and Transaction DSL for real-world use cases.
*)

[@@@warning "-32"]  (* Allow unused values - this is example code *)

open Neo4j_eio

(** Pattern 1: Repository-style data access *)
module PersonRepository = struct
  type person = {
    id: int64;
    name: string;
    age: int64;
  }

  let label = "Person"

  let create ~name ~age =
    let open Transaction_dsl in
    let* records = exec_query_builder
        (Query_builder.create_node
           (Printf.sprintf "(p:%s {name: $name, age: $age})" label)
         |> Query_builder.with_params [
              ("name", Value.Text name);
              ("age", Value.Int age)
            ]
         |> Query_builder.return ["id(p) AS id"; "p.name AS name"; "p.age AS age"]) in
    match records with
    | [record] ->
        (match Record.at_int record "id",
               Record.at_text record "name",
               Record.at_int record "age" with
         | Ok id, Ok name, Ok age -> return { id; name; age }
         | _ -> fail (Error.Protocol "Failed to decode person"))
    | _ -> fail (Error.Protocol "Expected single person")

  let find_by_id id =
    let open Transaction_dsl in
    let* records = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
         |> Query_builder.where (Printf.sprintf "id(p) = %Ld" id)
         |> Query_builder.return ["id(p) AS id"; "p.name AS name"; "p.age AS age"]) in
    match records with
    | [record] ->
        (match Record.at_int record "id",
               Record.at_text record "name",
               Record.at_int record "age" with
         | Ok id, Ok name, Ok age -> return (Some { id; name; age })
         | _ -> return None)
    | _ -> return None

  let find_all () =
    let open Transaction_dsl in
    let* records = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
         |> Query_builder.return ["id(p) AS id"; "p.name AS name"; "p.age AS age"]
         |> Query_builder.limit 100) in
    let persons = List.filter_map (fun record ->
      match Record.at_int record "id",
            Record.at_text record "name",
            Record.at_int record "age" with
      | Ok id, Ok name, Ok age -> Some { id; name; age }
      | _ -> None
    ) records in
    return persons

  let update person =
    let open Transaction_dsl in
    exec_query_builder_unit
      (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
       |> Query_builder.where (Printf.sprintf "id(p) = %Ld" person.id)
       |> Query_builder.set [
            Printf.sprintf "p.name = '%s'" person.name;
            Printf.sprintf "p.age = %Ld" person.age
          ])

  let delete id =
    let open Transaction_dsl in
    exec_query_builder_unit
      (Query_builder.match_ (Printf.sprintf "(p:%s)" label)
       |> Query_builder.where (Printf.sprintf "id(p) = %Ld" id)
       |> Query_builder.detach_delete ["p"])
end

(** Pattern 2: Transactional batch operations *)
let batch_insert_persons names_and_ages session =
  let open Transaction_dsl in

  let create_batch = iter (fun (name, age) ->
    exec_query_builder_unit
      (Query_builder.create_node
         (Printf.sprintf "(p:Person {name: '%s', age: %Ld})" name age))
  ) names_and_ages in

  run create_batch session

(** Pattern 3: Conditional transaction logic *)
let conditional_create ~name ~age ~dry_run session =
  let open Transaction_dsl in

  let tx =
    let* person = PersonRepository.create ~name ~age in
    let* () = if dry_run then rollback else commit in
    return person
  in

  run tx session

(** Pattern 4: Error recovery pattern *)
let create_with_fallback ~name ~age ~fallback_age session =
  let open Transaction_dsl in

  let tx =
    catch
      (PersonRepository.create ~name ~age)
      (fun _err ->
         (* If creation fails, try with fallback age *)
         PersonRepository.create ~name ~age:fallback_age)
  in

  run tx session

(** Pattern 5: Aggregation pipeline *)
let get_age_statistics session =
  let open Transaction_dsl in

  let tx =
    let* records = exec_query_builder
        (Query_builder.match_ "(p:Person)"
         |> Query_builder.return [
              "count(p) AS total";
              "avg(p.age) AS avg_age";
              "min(p.age) AS min_age";
              "max(p.age) AS max_age"
            ]) in
    match records with
    | [record] ->
        (match Record.at_int record "total",
               Record.at_int record "avg_age",
               Record.at_int record "min_age",
               Record.at_int record "max_age" with
         | Ok total, Ok avg, Ok min, Ok max ->
             Format.printf "Stats: total=%Ld, avg=%Ld, min=%Ld, max=%Ld\n%!"
               total avg min max;
             return ()
         | _ -> return ())
    | _ -> return ()
  in

  run tx session

(** Pattern 6: Pagination helper *)
let paginated_query ~page ~page_size session =
  let open Transaction_dsl in
  let offset = page * page_size in

  let tx =
    let* records = exec_query_builder
        (Query_builder.match_ "(p:Person)"
         |> Query_builder.return ["p.name AS name"; "p.age AS age"]
         |> Query_builder.order_by "p.name"
         |> Query_builder.skip offset
         |> Query_builder.limit page_size) in
    return records
  in

  run tx session

(** Pattern 7: Relationship creation pattern *)
let create_friendship ~person1_id ~person2_id session =
  let open Transaction_dsl in

  let tx =
    let* () = exec_query_builder_unit
        (Query_builder.match_ "(p1:Person), (p2:Person)"
         |> Query_builder.where (Printf.sprintf "id(p1) = %Ld AND id(p2) = %Ld"
                                   person1_id person2_id)
         |> Query_builder.create "(p1)-[r:FRIENDS_WITH]->(p2)")
    in
    return ()
  in

  run tx session

(** Pattern 8: Complex multi-step transaction *)
let transfer_relationship ~from_id ~to_id ~rel_type session =
  let open Transaction_dsl in

  let tx =
    (* Step 1: Find existing relationships *)
    let* old_rels = exec_query_builder
        (Query_builder.match_ (Printf.sprintf "(from)-[r:%s]->(target)" rel_type)
         |> Query_builder.where (Printf.sprintf "id(from) = %Ld" from_id)
         |> Query_builder.return ["id(target) AS target_id"]) in

    (* Step 2: Delete old relationships *)
    let* () = exec_query_builder_unit
        (Query_builder.match_ (Printf.sprintf "(from)-[r:%s]->()" rel_type)
         |> Query_builder.where (Printf.sprintf "id(from) = %Ld" from_id)
         |> Query_builder.delete ["r"]) in

    (* Step 3: Create new relationships *)
    let* () = iter (fun record ->
        match Record.at_int record "target_id" with
        | Ok target_id ->
            exec_query_builder_unit
              (Query_builder.match_ "(from), (to), (target)"
               |> Query_builder.where (Printf.sprintf
                   "id(from) = %Ld AND id(to) = %Ld AND id(target) = %Ld"
                   from_id to_id target_id)
               |> Query_builder.create (Printf.sprintf "(to)-[r:%s]->(target)" rel_type))
        | Error _ -> return ()
      ) old_rels in

    return ()
  in

  run tx session

let run_examples env =
  let open Eio in
  Switch.run @@ fun sw ->

    let cfg = Config.of_env () in

    match Session.with_session ~sw ~net:env#net cfg (fun session ->

      (* Pattern 1: Repository *)
      Format.printf "\n=== Pattern 1: Repository ===\n%!";
      let open Transaction_dsl in
      let tx1 = let* alice = PersonRepository.create ~name:"Alice" ~age:30L in
                let* bob = PersonRepository.create ~name:"Bob" ~age:35L in
                Format.printf "Created: Alice (id=%Ld), Bob (id=%Ld)\n%!"
                  alice.PersonRepository.id bob.PersonRepository.id;
                return (alice, bob) in

      let (alice, bob) = match run tx1 session with
        | Ok result -> result
        | Error e ->
            Format.eprintf "Error: %s\n%!" (Error.to_string e);
            exit 1
      in

      (* Pattern 2: Batch insert *)
      Format.printf "\n=== Pattern 2: Batch Insert ===\n%!";
      let batch_data = [
        ("Charlie", 25L);
        ("Diana", 28L);
        ("Eve", 32L);
      ] in
      (match batch_insert_persons batch_data session with
       | Ok () -> Format.printf "Batch inserted %d persons\n%!" (List.length batch_data)
       | Error e -> Format.eprintf "Batch error: %s\n%!" (Error.to_string e));

      (* Pattern 3: Dry run *)
      Format.printf "\n=== Pattern 3: Dry Run ===\n%!";
      (match conditional_create ~name:"Dry Run Test" ~age:99L ~dry_run:true session with
       | Ok person ->
           Format.printf "Dry run returned person id=%Ld (but rolled back)\n%!"
             person.PersonRepository.id
       | Error e -> Format.eprintf "Dry run error: %s\n%!" (Error.to_string e));

      (* Pattern 4: Error recovery *)
      Format.printf "\n=== Pattern 4: Error Recovery ===\n%!";
      (match create_with_fallback ~name:"Frank" ~age:40L ~fallback_age:0L session with
       | Ok person ->
           Format.printf "Created with recovery: id=%Ld\n%!" person.PersonRepository.id
       | Error e -> Format.eprintf "Recovery failed: %s\n%!" (Error.to_string e));

      (* Pattern 5: Aggregation *)
      Format.printf "\n=== Pattern 5: Aggregation ===\n%!";
      (match get_age_statistics session with
       | Ok () -> ()
       | Error e -> Format.eprintf "Aggregation error: %s\n%!" (Error.to_string e));

      (* Pattern 6: Pagination *)
      Format.printf "\n=== Pattern 6: Pagination ===\n%!";
      (match paginated_query ~page:0 ~page_size:3 session with
       | Ok records ->
           Format.printf "Page 0: %d records\n%!" (List.length records)
       | Error e -> Format.eprintf "Pagination error: %s\n%!" (Error.to_string e));

      (* Pattern 7: Relationships *)
      Format.printf "\n=== Pattern 7: Create Friendship ===\n%!";
      (match create_friendship
               ~person1_id:alice.PersonRepository.id
               ~person2_id:bob.PersonRepository.id
               session with
       | Ok () -> Format.printf "Created friendship\n%!"
       | Error e -> Format.eprintf "Friendship error: %s\n%!" (Error.to_string e));

      (* Pattern 8: Complex transaction *)
      Format.printf "\n=== Pattern 8: Transfer Relationships ===\n%!";
      (match transfer_relationship
               ~from_id:alice.PersonRepository.id
               ~to_id:bob.PersonRepository.id
               ~rel_type:"FRIENDS_WITH"
               session with
       | Ok () -> Format.printf "Transferred relationships\n%!"
       | Error e -> Format.eprintf "Transfer error: %s\n%!" (Error.to_string e));

      (* Cleanup *)
      Format.printf "\n=== Cleanup ===\n%!";
      let cleanup = Query_builder.match_ "(n:Person)"
                    |> Query_builder.detach_delete ["n"] in
      (match Query_builder.execute_unit cleanup session with
       | Ok () -> Format.printf "Cleanup complete\n%!"
       | Error e -> Format.eprintf "Cleanup error: %s\n%!" (Error.to_string e));

      Ok ()
    ) with
    | Ok () -> ()
    | Error e -> Format.eprintf "Session error: %s\n%!" (Error.to_string e)

let () =
  Eio_main.run (fun env ->
    run_examples env
  )
