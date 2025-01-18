open! Core
open! Stdio
open Async
module Time = Time_float_unix

let public_dir = ref "UNSET_PATH"

let extract_uri_path uri_path =
  let effective_path =
    if String.(uri_path = "/")
    then "/about.html"
    else (
      let normalized_path = String.chop_prefix_if_exists uri_path ~prefix:"/" in
      match Filename_base.split_extension normalized_path with
      | _, Some _ -> normalized_path
      | base, None -> base ^ ".html")
  in
  Filename.concat !public_dir effective_path
;;

let is_safe_path ~normalized_path =
  try
    let resolved_path = Filename_unix.realpath normalized_path in
    String.is_prefix resolved_path ~prefix:!public_dir
  with
  | _exn -> false
;;

let cache = ref (Map.empty (module String))

let read_cached path =
  match Map.find !cache path with
  | Some data ->
    print_s [%message "Hit the cache" (path : string)];
    data
  | None ->
    let data = In_channel.read_all path in
    cache := Map.set !cache ~key:path ~data;
    data
;;

let read_and_subs path header =
  if String.is_prefix path ~prefix:"css/" || String.is_prefix path ~prefix:"assets/"
  then read_cached path
  else (
    let body = read_cached path in
    if Map.mem header "hx-request"
    then body
    else (
      let template = read_cached (extract_uri_path "/index") in
      String.substr_replace_first template ~pattern:"{{ content-body }}" ~with_:body))
;;

module RequestKind = struct
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

let parse_request request =
  let parse_request_top line =
    match String.split_on_chars ~on:[ ' '; '\r' ] line with
    | [ "GET"; uri; (("HTTP/0.9" | "HTTP/1.0" | "HTTP/1.1" | "HTTP/1.2") as version) ] ->
      Valid { kind = RequestKind.GET; uri; version }
    | [ "HEAD"; uri; (("HTTP/0.9" | "HTTP/1.0" | "HTTP/1.1" | "HTTP/1.2") as version) ] ->
      Valid { kind = RequestKind.HEAD; uri; version }
    | [ kind; _uri; ("HTTP/0.9" | "HTTP/1.0" | "HTTP/1.1" | "HTTP/1.2") ] ->
      Unsupported { issue = kind }
    | [ _kind; _uri; (("HTTP/2" | "HTTP/3") as version) ] ->
      Unsupported { issue = version }
    | _ -> Invalid
  in
  match String.split_lines request with
  | [] -> Invalid, Map.empty (module String)
  | head :: lines ->
    let kind = parse_request_top head in
    let header =
      lines
      |> List.filter_map ~f:(String.lsplit2 ~on:':')
      |> List.map ~f:(fun (k, v) -> String.strip k, String.strip v)
      |> List.map ~f:(fun (k, v) -> String.lowercase k, String.lowercase v)
      |> Map.of_alist_exn (module String)
    in
    kind, header
;;

let content_type_of_ext path =
  match String.rsplit2 path ~on:'.' with
  | Some (_, "html") -> "text/html"
  | Some (_, "css") -> "text/css"
  | Some (_, "js") -> "application/javascript"
  | Some (_, "json") -> "application/json"
  | Some (_, ("jpg" | "jpeg")) -> "image/jpeg"
  | Some (_, "png") -> "image/png"
  | Some (_, "gif") -> "image/gif"
  | Some (_, "svg") -> "image/svg+xml"
  | Some (_, "woff") -> "font/woff"
  | Some (_, "woff2") -> "font/woff2"
  | Some _ | None -> "application/octet-stream"
;;

let http_date () =
  let now = Time.now () in
  Time.format ~zone:Time.Zone.utc now "%a, %d %b %Y %H:%M:%S GMT"
;;

let html_header_and_body uri version body include_body =
  sprintf
    "%s 200 OK\r\n\
     Date: %s\r\n\
     Connection: Closed\r\n\
     Server: HelloFromOcaml/1.0\r\n\
     Content-Length: %d\r\n\
     Content-Type: %s; charset=UTF-8\r\n\
     \r\n\
     %s"
    version
    (http_date ())
    (String.length body)
    (content_type_of_ext uri)
    (if include_body then body else "")
;;

let handle_client reader writer =
  let terminator = Bigstring.of_string "\r\n\r\n" in
  Reader.read_one_chunk_at_a_time reader ~handle_chunk:(fun buffer ~pos ~len ->
    let req_terminator_idx =
      Bigstring.unsafe_memmem
        ~haystack:buffer
        ~needle:terminator
        ~haystack_pos:pos
        ~haystack_len:len
        ~needle_pos:0
        ~needle_len:4
    in
    (* Since we've found the terminator, we know the complete request has been read *)
    if req_terminator_idx >= 0
    then (
      let buffer = Bigstring.unsafe_get_string buffer ~pos:0 ~len:(pos + len) in
      let req, header = parse_request buffer in
      match req with
      | Valid { kind; uri; version } ->
        print_s
          [%message
            "Received a complete request"
              (kind : RequestKind.t)
              (uri : string)
              (version : string)];
        let path = extract_uri_path uri in
        if not (is_safe_path ~normalized_path:path)
        then raise_s [%message "Not a path within our defined public_dir" (path : string)];
        let body = read_and_subs path header in
        let include_body = RequestKind.equal kind RequestKind.GET in
        Writer.write writer (html_header_and_body path version body include_body);
        let%map () = Writer.flushed writer in
        `Stop reader
      | Unsupported { issue } -> raise_s [%message "Unsupported request" (issue : string)]
      | Invalid -> raise_s [%message "(Invalid request)"])
    else Deferred.return `Continue)
;;

let start_server ~base_dir ~port =
  public_dir := base_dir;
  let where_to_listen = Tcp.Where_to_listen.of_port port in
  let%bind _server =
    Tcp.Server.create
      ~on_handler_error:
        (`Call
          (fun _addr exn -> eprintf "%s\n%!" (Monitor.extract_exn exn |> Exn.to_string)))
      where_to_listen
      (fun _addr reader writer ->
        let%bind _result = handle_client reader writer in
        Deferred.unit)
  in
  print_s [%message "Server is listening" (port : int)];
  Deferred.never ()
;;
