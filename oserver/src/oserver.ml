open !Core
open !Stdio
open Async

module Time = Time_float_unix

let public_dir =
  let dir = "/Users/nicolas/Projects/personal_v2" in
  lazy (Filename_unix.realpath dir)
;;

let normalize_path path =
  let public_dir = Lazy.force public_dir in
  let effective_path =
    match path with
    | "/" -> "/about.html"
    | _ -> (
      let path = String.chop_prefix_if_exists path ~prefix:"/" in
      match Filename_base.split_extension path with
      | _, (Some _) -> path
      | base, None -> base ^ ".html"
    )
  in
  Filename.concat public_dir effective_path
;;

let is_safe_path ~normalized_path =
  let public_dir = Lazy.force public_dir in
  try
    let resolved_path = Filename_unix.realpath normalized_path in
    String.is_prefix resolved_path ~prefix:public_dir
  with
    | _ -> false
;;

let sanitize_uri uri =
  let path = normalize_path uri in
  if is_safe_path ~normalized_path:path then
    path
  else
    raise_s [%message "Not a path within our defined public_dir" (path : string)]
;;

let cache = ref (Map.empty (module String));;

let read_cached path =
  match Map.find !cache path with
  | Some data ->
      print_s [%message "Hit the cache" (path : string)];
      data
  | None ->
    let data = In_channel.read_all path in
    cache := Map.set !cache ~key:path ~data:data;
    data
;;

let read_and_subs path header =
  if String.is_prefix path ~prefix:"css/" || String.is_prefix path ~prefix:"assets/" then
    read_cached path
  else
    let body = read_cached path in
    if Option.is_some (List.Assoc.find header ~equal:String.equal "hx-request") then
      body
    else
      let template = read_cached (normalize_path "/index") in
      String.substr_replace_first template ~pattern:"{{ content-body }}" ~with_:body
;;

type request_kind =
  | Get of { uri : string ; version : string }
  | Unsupported of { issue : string }
  | Invalid
[@@deriving sexp]

let parse_request request =
  let parse_request_top line =
    let split = String.split_on_chars ~on:[' '; '\r'] line in
    let split = List.take split 3 in
    match split with
    | [kind; uri; version] -> (
        match kind with
        | "GET" -> (
            match version with
            | "HTTP/0.9"
            | "HTTP/1.1"
            | "HTTP/1.2"
            | "HTTP/2" -> Get { uri; version }
            | "HTTP/3" -> Unsupported { issue = "HTTP/3" }
            | _ -> Invalid
          )
        | ("PUT" | "DELETE" | "POST") as issue -> Unsupported { issue }
        | _ -> Invalid
      )
    | _ -> Invalid
  in
  match String.split_lines request with
    | [] -> (Invalid, [])
    | line :: lines ->
      let kind = parse_request_top line in
      let header = lines
      |> List.filter_map ~f:(String.lsplit2 ~on:':')
      |> List.map ~f:(fun (k, v) -> (String.strip k, String.strip v)) in
      (kind, header)
;;

let content_type_of_ext path =
  let extension = match String.rindex path '.' with
    | Some idx -> String.sub path ~pos:(idx + 1) ~len:(String.length path - idx - 1)
    | None -> ""
  in
  match extension with
  | "html" -> "text/html"
  | "css" -> "text/css"
  | "js" -> "application/javascript"
  | "json" -> "application/json"
  | "jpg" | "jpeg" -> "image/jpeg"
  | "png" -> "image/png"
  | "gif" -> "image/gif"
  | "svg" -> "image/svg+xml"
  | "woff" -> "font/woff"
  | "woff2" -> "font/woff2"
  | _ -> "application/octet-stream"
;;

let http_date () =
  let now = Time.now () in
  Time.format ~zone:Time.Zone.utc now "%a, %d %b %Y %H:%M:%S GMT"
;;

let html_header_and_body uri version body =
  sprintf
    "%s 200 OK\r
Date: %s\r
Connection: Keep-Alive\r
Server: HelloFromOcaml/1.0\r
Content-Length: %d\r
Content-Type: %s; charset=UTF-8\r
\r
%s"
  version
  (http_date ())
  (String.length body)
  (content_type_of_ext uri)
  body
;;

let handle_client reader writer =
  let buffer = Bytes.create 8192 in (* 8kb is the size of the largest GET request. *)
  let buf_len = Bytes.length buffer in
  let terminator = Bytes.unsafe_of_string_promise_no_mutation "\r\n\r\n" in
  (* Right to left scanning *)
  let whole_request_read buffer start =
    let rec aux pos =
      if pos < start then
        false
      else if pos + 4 <= buf_len && Bytes.equal (Bytes.sub buffer ~pos ~len:4) terminator then
        true
      else
        aux (pos - 1)
    in
    aux (buf_len - 4)
  in
  let rec read_and_parse pos =
    match%bind Reader.read reader buffer ~pos with
    | `Eof -> Deferred.never ()
    | `Ok bytes_read -> (
      if whole_request_read buffer pos then
        let buffer = Bytes.unsafe_to_string ~no_mutation_while_string_reachable:buffer in
        let (kind, header) = parse_request buffer in
        (* print_s ([%sexp_of : (string * string) list] header); *)
        match kind with
        | Get { uri; version } -> (
            print_s [%message "Received a complete request" (uri : string)(version : string)];

            let path = sanitize_uri uri in
            let body = read_and_subs path header in
            Writer.write writer (html_header_and_body path version body);
            Writer.flushed writer;
        )
        | Unsupported { issue } -> raise_s [%message "Unsupported request" (issue : string)]
        | Invalid -> raise_s [%message "Invalid request"]
      else
        read_and_parse (pos + bytes_read)
    )
  in
  read_and_parse 0
;;


let start_server port =
  (* Disable backtraces on exceptions. *)
  Unix.putenv ~key:"OCAMLRUNPARAM" ~data:"b=0";
  let exception_handler _addr exn =
    let exn = Monitor.extract_exn exn in
    print_endline (Exn.to_string exn);
  in
  let where_to_listen = Tcp.Where_to_listen.of_port port in
  let%bind _server = Tcp.Server.create
    ~on_handler_error:(`Call exception_handler)
    where_to_listen
    (fun _addr reader writer -> handle_client reader writer)
  in
  print_s [%message "Server is listening" (port : int)];
  Deferred.never ()
;;

let () =
  Command.async
    ~summary:"Simple HTML server"
    (Command.Param.return (fun () -> start_server 3000))
  |> Command_unix.run
