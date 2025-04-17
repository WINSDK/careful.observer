open! Core
open Async

module Request : sig
  type kind =
    | GET
    | HEAD
  [@@deriving sexp, equal]

  type t =
    | Valid of
        { kind : kind
        ; uri : string
        ; version : string
        }
    | Invalid
    | Unsupported of { issue : string }
  [@@deriving sexp, equal]

  val parse : string -> t * string String.Map.t
end

val content_type_of_ext : string -> string
val start_server : base_dir:string -> port:int -> 'a Deferred.t
