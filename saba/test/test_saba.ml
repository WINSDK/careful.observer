open! Core
open Stdio
open Saba

let%expect_test "parse_request_tests" =
  let print_parse input =
    let result = Request.parse input in
    print_s [%sexp (result : Request.t * string String.Map.t)]
  in
  print_parse "GET /index HTTP/1.1\r\nHost: a.com\r\n\r\n";
  [%expect {| ((Valid (kind GET) (uri /index) (version HTTP/1.1)) ((host a.com))) |}];
  print_parse "POST /submit HTTP/1.1\r\n";
  [%expect {| ((Unsupported (issue POST)) ()) |}];
  print_parse "POST /submitHTTP/1.1\r\n";
  [%expect {| (Invalid ()) |}];
  print_parse "POST /submit?a=100 HTTP/1.1\r\n";
  [%expect {| ((Unsupported (issue POST)) ()) |}];
  print_parse "GET /submit?a=100 HTTP/1.1\r\n";
  [%expect {| ((Valid (kind GET) (uri /submit?a=100) (version HTTP/1.1)) ()) |}];
  print_parse "GET /submit?a=100 HTTP/3\r\n";
  [%expect {| ((Unsupported (issue HTTP/3)) ()) |}];
  print_parse "GET /index.html HTTP/1.0";
  [%expect {| ((Valid (kind GET) (uri /index.html) (version HTTP/1.0)) ()) |}]
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
