open! Core
open Async

module RequestKind : sig
  type t =
    | GET
    | HEAD
  [@@deriving equal, compare, sexp]
end

type request =
  | Valid of
      { kind : RequestKind.t
      ; uri : string
      ; version : string
      }
  | Invalid
  | Unsupported of { issue : string }
[@@deriving sexp]

val parse_request : string -> request * string String.Map.t
val content_type_of_ext : string -> string
val start_server : base_dir:string -> port:int -> 'a Deferred.t
