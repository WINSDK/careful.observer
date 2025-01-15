open! Core
open Async

type request_kind =
  | GET
  | HEAD
[@@deriving equal, sexp]

type request =
  | Valid of
      { kind : request_kind
      ; uri : string
      ; version : string
      }
  | Invalid
  | Unsupported of { issue : string }
[@@deriving equal, sexp]

val parse_request : string -> request * string String.Map.t
val content_type_of_ext : string -> string
val start_server : base_dir:string -> port:int -> 'a Deferred.t
