open! Core
open Stdio
open Saba

let%expect_test "parse_request_tests" =
  let print_parse input =
    let result = parse_request input in
    print_s [%sexp (result : request_kind * string String.Map.t)]
  in
  print_parse "GET /index.html HTTP/1.1\r\nHost: example.com\r\n\r\n";
  [%expect {| ((Get (uri /index.html) (version HTTP/1.1)) ((Host example.com))) |}];
  print_parse "POST /submit HTTP/1.1\r\n";
  [%expect {| ((Unsupported (issue POST)) ()) |}];
  print_parse "POST /submitHTTP/1.1\r\n";
  [%expect {| (Invalid ()) |}];
  print_parse "POST /submit?a=100 HTTP/1.1\r\n";
  [%expect {| ((Unsupported (issue POST)) ()) |}];
  print_parse "GET /submit?a=100 HTTP/1.1\r\n";
  [%expect {| ((Get (uri /submit?a=100) (version HTTP/1.1)) ()) |}];
  print_parse "GET /submit?a=100 HTTP/3\r\n";
  [%expect {| ((Unsupported (issue HTTP/3)) ()) |}]
;;

let%test_unit "content_type_tests" =
  let test_cases =
    [ ".html", "text/html"
    ; ".jpg", "image/jpeg"
    ; ".asdwef.jpeg", "image/jpeg"
    ; ".unknown", "application/octet-stream"
    ; "no_ext", "application/octet-stream"
    ; "", "application/octet-stream"
    ]
  in
  List.iter test_cases ~f:(fun (ext, expected) ->
    [%test_eq: string] (content_type_of_ext ext) expected)
;;
