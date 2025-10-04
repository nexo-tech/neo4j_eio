type record = Value.value Value.StringMap.t

val empty : record
val add : string -> Value.value -> record -> record
val find_opt : string -> record -> Value.value option
