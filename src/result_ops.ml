(** Result monad combinators and operators for elegant error handling *)

(* Core Monadic Operations *)

let return x = Ok x

let fail e = Error e

let bind r f =
  match r with
  | Ok x -> f x
  | Error e -> Error e

let map f r =
  match r with
  | Ok x -> Ok (f x)
  | Error e -> Error e

let map_error f r =
  match r with
  | Ok x -> Ok x
  | Error e -> Error (f e)

let join r =
  match r with
  | Ok (Ok x) -> Ok x
  | Ok (Error e) -> Error e
  | Error e -> Error e

(* Let-Syntax Bindings *)

let (let*) = bind

let (let+) r f = map f r

let (and+) r1 r2 =
  match r1, r2 with
  | Ok x, Ok y -> Ok (x, y)
  | Error e, _ -> Error e
  | _, Error e -> Error e

(* Infix Operators *)

let (>>=) = bind

let (>>|) r f = map f r

let (>=>) f g x = bind (f x) g

let (<=<) g f = f >=> g

(* Applicative Operations *)

let pure = return

let apply rf r =
  match rf, r with
  | Ok f, Ok x -> Ok (f x)
  | Error e, _ -> Error e
  | _, Error e -> Error e

let (<*>) = apply

let (<$>) f r = map f r

let lift2 f r1 r2 =
  match r1, r2 with
  | Ok x, Ok y -> Ok (f x y)
  | Error e, _ -> Error e
  | _, Error e -> Error e

let lift3 f r1 r2 r3 =
  match r1, r2, r3 with
  | Ok x, Ok y, Ok z -> Ok (f x y z)
  | Error e, _, _ -> Error e
  | _, Error e, _ -> Error e
  | _, _, Error e -> Error e

(* Alternative Operations *)

let (<|>) r1 r2 =
  match r1 with
  | Ok _ -> r1
  | Error _ -> r2

let alt rs =
  match rs with
  | [] -> failwith "alt: empty list"
  | r :: rs ->
      List.fold_left (fun acc r ->
        match acc with
        | Ok _ -> acc
        | Error _ -> r
      ) r rs

let guard cond err =
  if cond then Ok () else Error err

(* Combinators *)

let sequence rs =
  let rec go acc = function
    | [] -> Ok (List.rev acc)
    | r :: rs ->
        match r with
        | Ok x -> go (x :: acc) rs
        | Error e -> Error e
  in
  go [] rs

let traverse f xs =
  let rec go acc = function
    | [] -> Ok (List.rev acc)
    | x :: xs ->
        match f x with
        | Ok y -> go (y :: acc) xs
        | Error e -> Error e
  in
  go [] xs

let fold_left_m f init xs =
  let rec go acc = function
    | [] -> Ok acc
    | x :: xs ->
        match f acc x with
        | Ok acc' -> go acc' xs
        | Error e -> Error e
  in
  go init xs

let fold_right_m f xs init =
  let rec go = function
    | [] -> Ok init
    | x :: xs ->
        match go xs with
        | Ok acc ->
            f x acc
        | Error e -> Error e
  in
  go xs

let filter_m p xs =
  let rec go acc = function
    | [] -> Ok (List.rev acc)
    | x :: xs ->
        match p x with
        | Ok true -> go (x :: acc) xs
        | Ok false -> go acc xs
        | Error e -> Error e
  in
  go [] xs

let map_m = traverse

let iter_m f xs =
  let rec go = function
    | [] -> Ok ()
    | x :: xs ->
        match f x with
        | Ok () -> go xs
        | Error e -> Error e
  in
  go xs

(* Utility Functions *)

let is_ok = function
  | Ok _ -> true
  | Error _ -> false

let is_error = function
  | Ok _ -> false
  | Error _ -> true

let from_option err = function
  | Some x -> Ok x
  | None -> Error err

let to_option = function
  | Ok x -> Some x
  | Error _ -> None

let catch f handler =
  try Ok (f ())
  with exn -> Error (handler exn)

let or_else r f =
  match r with
  | Ok _ -> r
  | Error _ -> f ()

let unless cond f =
  if cond then Ok () else f ()

let when_ cond f =
  if cond then f () else Ok ()

(* Bimap and Swap *)

let bimap f g r =
  match r with
  | Ok x -> Ok (f x)
  | Error e -> Error (g e)

let swap = function
  | Ok x -> Error x
  | Error e -> Ok e

(* Pair Operations *)

let both = (and+)

let fst r = map fst r

let snd r = map snd r
