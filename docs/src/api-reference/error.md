# Error Module Reference

Unified error type and helpers (see ocaml/src/error.mli).

Type
- `type t = Io of string | Protocol of string | Auth of string | Database of {code:string; message:string} | Transient of {code:string; message:string} | ClientError of {code:string; message:string}`

Functions
- `to_string : t -> string`
- `from_failure_map : Value.value Value.StringMap.t -> t` — map server FAILURE metadata to typed error
