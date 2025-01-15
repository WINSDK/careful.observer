open! Core
open Async

type request_kind =
  | Get of
      { uri : string
      ; version : string
      }
  | Unsupported of { issue : string }
  | Invalid
[@@deriving sexp]

val parse_request : string -> request_kind * string String.Map.t
val content_type_of_ext : string -> string
val html_header_and_body : string -> string -> string -> string
val start_server : base_dir:string -> port:int -> 'a Deferred.t
