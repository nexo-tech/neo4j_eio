(** [is_supported v] returns [true] if transactions are supported for [v].
    Equivalent to {!Protocol.is_new_version} (Bolt v3+). *)
val is_supported : Protocol.version -> bool
