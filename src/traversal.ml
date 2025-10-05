(** Traversals for working with collections *)

(** A traversal extracts multiple values from a structure *)
type ('s, 'a) t = 's -> 'a list

(** {1 Construction} *)

let traverse f = f

let each = fun lst -> lst

let records = fun lst -> lst

let values = fun lst -> lst

let filtered pred = fun lst ->
  List.filter pred lst

(** {1 Operators} *)

let (^..) s trav = trav s

let (^?) s trav =
  match trav s with
  | x :: _ -> Some x
  | [] -> None

let (%~) trav f = fun lst ->
  let items = trav lst in
  List.map f items

(** {1 Composition} *)

(** Compose a traversal with a lens *)
let (>>>) trav lens = fun s ->
  let items = trav s in
  List.filter_map lens items

let compose_lens = (>>>)

(** Compose two traversals *)
let compose_traversals trav1 trav2 = fun s ->
  let items = trav1 s in
  List.concat_map trav2 items

(** {1 Extraction} *)

let to_list s trav = trav s

let to_option s trav = s ^? trav

let head trav s =
  match trav s with
  | x :: _ -> Some x
  | [] -> None

let last trav s =
  match trav s with
  | [] -> None
  | lst -> Some (List.hd (List.rev lst))

(** {1 Folds} *)

let fold f init trav s =
  let items = trav s in
  List.fold_left f init items

let fold_right f trav s init =
  let items = trav s in
  List.fold_right f items init

let fold_int trav init f s =
  fold f init trav s

let fold_float trav init f s =
  fold f init trav s

(** {1 Aggregations} *)

let sum_int trav s =
  fold Int64.add 0L trav s

let sum_float trav s =
  fold (+.) 0.0 trav s

let count trav s =
  List.length (trav s)

let length = count

let average_int trav s =
  let items = trav s in
  match items with
  | [] -> None
  | _ ->
      let sum = List.fold_left Int64.add 0L items in
      let len = Int64.of_int (List.length items) in
      Some (Int64.div sum len)

let average_float trav s =
  let items = trav s in
  match items with
  | [] -> None
  | _ ->
      let sum = List.fold_left (+.) 0.0 items in
      let len = float_of_int (List.length items) in
      Some (sum /. len)

let minimum compare trav s =
  let items = trav s in
  match items with
  | [] -> None
  | x :: xs -> Some (List.fold_left (fun acc item ->
      if compare item acc < 0 then item else acc
    ) x xs)

let maximum compare trav s =
  let items = trav s in
  match items with
  | [] -> None
  | x :: xs -> Some (List.fold_left (fun acc item ->
      if compare item acc > 0 then item else acc
    ) x xs)

(** {1 Predicates} *)

let any pred trav s =
  let items = trav s in
  List.exists pred items

let all pred trav s =
  let items = trav s in
  List.for_all pred items

let none pred trav s =
  not (any pred trav s)

let has trav s =
  match trav s with
  | [] -> false
  | _ -> true

(** {1 Transformations} *)

let map f trav = fun s ->
  let items = trav s in
  List.map f items

let filter pred trav = fun s ->
  let items = trav s in
  List.filter pred items

let take n trav = fun s ->
  let items = trav s in
  let rec take_n acc n lst =
    if n <= 0 then List.rev acc
    else match lst with
    | [] -> List.rev acc
    | x :: xs -> take_n (x :: acc) (n - 1) xs
  in
  take_n [] n items

let drop n trav = fun s ->
  let items = trav s in
  let rec drop_n n lst =
    if n <= 0 then lst
    else match lst with
    | [] -> []
    | _ :: xs -> drop_n (n - 1) xs
  in
  drop_n n items

(** {1 Utilities} *)

let concat trav s =
  let items = trav s in
  List.concat items

let concat_map f trav s =
  let items = trav s in
  List.concat_map f items

let partition pred trav s =
  let items = trav s in
  List.partition pred items
