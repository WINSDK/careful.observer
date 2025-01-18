open! Core

let command =
  Async.Command.async
    ~summary:"HTTP server"
    (let%map_open.Command port =
       flag
         "-port"
         (optional_with_default 3000 int)
         ~doc:"PORT Port to listen on (default: 3000)"
     and base_dir =
       flag "-base-dir" (required string) ~doc:"DIR Base directory for serving files"
     in
     fun () -> Saba.start_server ~base_dir ~port)
;;

let () =
  (* Disable backtraces on exceptions. *)
  Async.Unix.putenv ~key:"OCAMLRUNPARAM" ~data:"b=0";
  let result = Result.try_with (fun () -> Command_unix.run command) in
  match result with
  | Ok () -> ()
  | Error exn ->
    eprintf "%s\n%!" (Exn.to_string exn);
    exit 1
;;
