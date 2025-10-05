# Record Module Reference

Typed decoding helpers for rows returned from Neo4j (see ocaml/src/record.mli).

Types
- `type t = Value.value Value.StringMap.t`
- `type decode_error = ... | KeyNotFound of string` (covers NotBool/NotInt/..., graph and temporal variants)
- `pp_decode_error : formatter -> decode_error -> unit`

Decoders for raw `Value.value`
- Exact: `exact_bool/int/int_as_int/float/text/bytes/list/map/node/relationship/unbound_relationship/path/point2d/point3d/duration/date/local_time/time/local_datetime/datetime_zone_id/datetime_offset/value`
- Maybe: `maybe_exact_*` return `'a option`

Record field decoders (by key)
- Exact: `at_bool/int/int_as_int/float/text/bytes/list/map/node/relationship/unbound_relationship/path/point2d/point3d/duration/date/local_time/time/local_datetime/datetime_zone_id/datetime_offset/value`
- Maybe: `maybe_at_*` return `('a option, decode_error) result` (None when key missing)

Helpers
- `empty : t`
- `of_list : (string * Value.value) list -> t`
