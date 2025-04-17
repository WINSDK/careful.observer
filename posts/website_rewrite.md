---
title: "Rewriting my website"
date: "Feb 13, 2025"
---

## Requirements

* Minimal dependencies if possible
* Have syntax highlighting without making me cry
* Render correctly on mobile
* Not require a PhD in cs to maintain (failed this one)
* Fast enough to handle the crushing weight of my zero regular visitors

Previously, the website had basically no dependencies.
No htmx, no pandoc, just static HTML with some self-contained JavaScript.
It was basic and did the job. Yet it had no features for rendering any form of blog.
This was all fine since there were no blog posts. But fortunately
this rabbit hole seemed interesting, so I decided to write about it.

My first thought was to just write the blog posts in HTML. At first, this seemed
reasonable as all the basic components of markdown can be trivially represented
using plain HTML. As I started to try and embed some code,\
I ran into the first problem: syntax highlighting.

There are JavaScript libraries out there that, at runtime,
transform your code blocks to have highlighting. That would be a simple solution,
and the one I looked at was [highlightjs](https://highlightjs.org/). This was great
and all, except that every time I wanted to change the formatting in the site, I also
had to change a lot of raw HTML, which was painful. So I opted to just use
markdown.

## The Pandoc experience

I remembered that I used pandoc before to convert random documents between types.
Pdf's to docx, docx to raw text and markdown to html. The command is as
simple as running:
```bash
pandoc input.md -o output.html
```
With the limitation that there's no styling and no syntax highlighting.
So I wrote up a little html template that looks a bit like this:
```html
<style>
code {
  background: #8e5a1d;
  font-family: "Berkeley", monospace;
}

...

$highlighting-css$

div.sourceCode {
  border: 2px solid #444444;
}

pre.sourceCode {
  margin: 0.85rem;
}

...
</style>
<div class="wrapper">
  <h1 class="title">$title$</h1>
  <div class="date-note">$date$</div>
  $body$
</div>
```
That applies a bit of styling around code blocks and takes the fields: `title`
and `date` from every post's [meta block](https://pandoc.org/chunkedhtml-demo/8.10-metadata-blocks.html)
and displays it neatly.
This worked well and allowed me to produce well formatted blog posts from
just a simple markdown file.

Unfortunately this doesn't work nearly as well when you try to syntax highlight
rust code. While the [syntax definitions](https://github.com/KDE/syntax-highlighting/blob/master/data/syntax/rust.xml)
appear to be well maintained, function and method's don't have
their styling applied:

<img src="/assets/website_rewrite/syntaxv1.png">

I got around this in a slightly hacky manner. Pandoc was not happy with me
providing a modified **rust.xml** that labelled the function/method identifiers
as *function*'s. So I just wrote a regex to mark them as errors!

```diff
409c409,410
<  <DetectIdentifier/>
---
>  <RegExpr String="&rustIdent;\s*(?=\()" attribute="Error" context="#stay"/>
>  <DetectIdentifier/>
```

And with a bit more hackery. One where we adjust gruvbox to color error's
just like identifier's and we finally have some pretty colors:

<img src="/assets/website_rewrite/syntaxv2.png">
_<sub>I've chosen to omit the theme here to keep this section more concise.</sub>_

---

## Simple dynamism

If you've never heard of [htmx](https://htmx.org/), I think you're missing out.
React might be much more powerful, have more features and likely be the correct
option for anything requiring lots of dynamism. However, it is not at all a small runtime and there are
costs to having a [virtual DOM](https://legacy.reactjs.org/docs/faq-internals.html#:~:text=The%20virtual%20DOM%20(VDOM)%20is,This%20process%20is%20called%20reconciliation.). For this reason, I chose tryout htmx.

For my use cases, I only really needed its AJAX capabilities, and I could've
properly also done this using just AJAX. The library is remarkably
simple: you include a single script: `<script src="https://unpkg.com/htmx.org"></script>`
and that's all [[1]](#1).

Now you can attach **hx-get**, **hx-target** and **hx-trigger** tags to any
of your &lt;a&gt; tags and transform your boring static website into one that loads
your DOM dynamically, replacing elements specified in your **hx-target** tags.
If you apply this approach to every bit of page navigation, then
you've just created your very own [SPA](https://en.wikipedia.org/wiki/Single-page_application)!

Now if you try hosting your little htmx webpage using **nginx**, you might
be disappointed. Try reloading the page and it totally misrenders...
Yes this is intended and not the result of some misconfiguration. Nginx just doesn't
know how to differentiate htmx (AJAX) requests and a *whole* page loads.

### What is and isn't an htmx request?

If you browser the [htmx docs](https://htmx.org/docs/#progressive_enhancement), 
you will find that every request sent, adds a field to the html request header.
This field is called `HX-Request`. When present, you send your component
(some plain html to insert), and otherwise you render the full page.
But for this to work you also need a form of templating, otherwise
you won't know how to render the full page.

### Templating

The simple idea of templating is remarkably simple. It comes down to just some
text replace. In our case it's used like this:

1. Request is sent to `/posts/website_rewrite`
2. Header is parsed into fields and uri, where we either:
   * Find the Uri is prefixed by `/css` or `/assets` and read the relevant file or
   * Notice the `hx-request` field is present and so we read our template
3. If the file is templated: we read the `index.html` for it's header, footer and styling
4. We merge with template with the requested page and sent it back

So great we have an idea, now how do we actually implement this. When I first
made a server application to host this, it was in rust. It worked well and all
but I thought: why not write a web server with essentially no dependencies??
This is obviously a bad idea though who cares! You get to learn about about
how HTTP works and I get to learn some OCaml. Oh and we get to remove most
of our dependencies in the process.

---

## The web server

This was my first experience with OCaml. It's a relatively niche language and if it
wasn't for Jane Street and their great technical [blog](https://blog.janestreet.com),
I doubt I would've tried it. So for this project I restricted myself to the `core` and `async`
libraries respectively. Btw if you're interested in learning more about OCaml, I highly
recommend reading **Real World Ocaml** [[2]](#2).

To start we need a way of doing networking.
The `async` library has support for low-level networking primitives. This
includes for the creation of sockets and also higher level functionality:

```ocaml
let start_server ~port =
  let descrip = Tcp.Where_to_listen.of_port port in
  let* host_and_port = Tcp.Server.create descrip (fun _addr -> handle_client) in
  print_s [%message "Server is listening" (port : int)];
  Deferred.never ()
```

You might be curious what the `let+` expression does here, it's what's
called a *monadic bind*. It essentially translates the program to this:

```ocaml
let server =
  Deferred.bind
    Tcp.Server.create
    descrip
    (fun _addr -> handle_client)
    ~f:(fun host_and_port ->
      print_s [%message "Server is listening" (port : int)]
      Deferred.never ())
```

What this lets us do is `yield`. When the async executer calls
`start_server`, the function is run and returns a closure. The executor can either invoke
this closure right away or first run other functions (that were `waiting` on maybe I/O or timers).
This is also known as [non-preemptive scheduling](https://en.wikipedia.org/wiki/Cooperative_multitasking)
unlike the preemptive scheduling used in kernel threads/processes.

We're slightly oversimplifying `async` here as it does apply some optimizations
like merging deferred statements when performing tail-call recursion.

Anyway this is all to say that we can perform async operations in idiomatic
way whilst still being explicit about the control flow.

### A HTTP Client

I decided (since this was mostly educational) to implement the
[HTTP 1.1 spec](https://datatracker.ietf.org/doc/html/rfc7230)
with the extra support for `keep-alive`. HTTP 1.1 messages consist of UTF8 characters
delimited by &#x22;&#x5c;&#x72;&#x5c;&#x6e;&#x5c;&#x72;&#x5c;&#x6e;&#x22;.
So to efficiently handle a client, we read data from the network in chunks
and buffer them until we reach the message terminator

```ocaml
let handle_client reader writer =
  let terminator = Bigstring.of_string "\r\n\r\n" in
  Reader.read_one_chunk_at_a_time reader ~handle_chunk:(fun buffer ~pos ~len ->
    let terminator_idx =
      Bigstring.memmem
        ~haystack:buffer
        ~needle:terminator
        ~haystack_pos:pos
        ~haystack_len:len
        ~needle_pos:0
        ~needle_len:4
    in
    (* Since we've found the terminator, we know the complete request has been read *)
    if terminator_idx >= 0
    then (
      let buffer = Bigstring.get_string buffer ~pos:0 ~len:(pos + len) in
      ...
      let bytes_read = terminator_idx + Bigstring.length terminator - pos in
      `Consumed (bytes_read, `Need_unknown))
    else return `Continue)
```

If you read the implementation closely, you'll notice we aren't storing buffers anywhere.
Well we are using `Reader.read_one_chunk_at_a_time`, and the callback we pass
does give us a buffer... So maybe it's handled internally? Yep, That's
one of the benefits of using `async`. Implementing buffering efficiently would
exponentially increase the complexity of what is a simple HTTP server and there's
some interesting details here. When you compile to linux and your kernel has support.
All reads are actually done using
[`IO_uring`](https://github.com/janestreet/async_unix/blob/9434adba86fb5a9ec7aeeecc6b1d4a16d0357e25/src/reader0.ml#L481)!
And even though everything is single-threaded, you'll see later this increased
performance drastically on linux.

Great so now let's parse some requests:
```ocaml
module Request = struct
  type kind = GET | HEAD
  [@@deriving sexp, equal]

  type t =
    | Valid of { kind : kind ; uri : string ; version : string }
    | Invalid
    | Unsupported of { issue : string }
  [@@deriving sexp, equal]

  let of_head str =
    match String.split_on_chars ~on:[ ' '; '\r' ] str with
    | [ kind; uri; version ] ->
      if is_supported_version version
      then
        if String.(=) kind "GET"
        then Valid { kind = GET; uri; version }
        else if String.(=) kind "HEAD"
        then Valid { kind = HEAD; uri; version }
        else Unsupported { issue = kind }
      else Unsupported { issue = version }
    | _ -> Invalid
  ;;

  let parse str =
    match String.split_lines str with
    | [] -> Invalid, String.Map.empty
    | head :: lines ->
      let header =
        lines
        |> List.filter_map ~f:(String.lsplit2 ~on:':')
        |> List.map ~f:(Tuple2.map ~f:(String.strip >> String.lowercase))
        |> String.Map.of_alist_exn
      in
      of_head head, header
  ;;
end
```
_<sub>is_supported_version just checks that these are HTTP 0.9 to 1.2 requests</sub>_

One thing that's a bit strange about OCaml is the lack of polymorphic operators.
This is just a fancy way of saying that you must explicitly provide the type of the 
operator you're using. You can't just call `1.0 + 2.0`, you must call
`Float.(+) 1.0 2.0` or `Float.(1.0 + 2.0)`. This may one day change when
we get modular implicits introduced to the language [[3]](#3).

If you read/know the HTTP specification you'll realize the `parse` function
is actually incorrect. Header lines are NOT supposed to have any whitespace
before the ':'. Unfortunately a lot of clients aren't very HTTP complaint.
And so it's easier to just allow some lenience here.

Also did you know people were writing HTTP clients/server's for 6 years (1991-1996) 
without any formal specification?? I can imagine this probably has something
to do with the non-compliance...

Now all we need is a way of sending responses and we've got a HTTP server!
I will admit this code is excluding a bunch safety checks / sanitizing. You don't
want a client requesting `/../.env` and using all your OpenAI credits.

```ocaml
let http_date () =
  let now = Time.now () in
  Time.format ~zone:Time.Zone.utc now "%a, %d %b %Y %H:%M:%S GMT"
;;

let html_header uri version body =
  sprintf
    "%s 200 OK\r\n\
     Date: %s\r\n\
     Connection: Keep-Alive\r\n\
     Server: HelloFromOcaml/1.0\r\n\
     Content-Length: %d\r\n\
     Content-Type: %s; charset=UTF-8\r\n\
     \r\n"
    version
    (http_date ())
    (String.length body)
    (content_type_of_ext uri)
;;

let handle_client reader writer =
  ...
  if terminator_idx >= 0
  then (
    let buffer = Bigstring.get_string buffer ~pos:0 ~len:(pos + len) in
    let req, header = Request.parse buffer in
    match req with
    | Valid { kind; uri; version } ->
      let path = extract_uri_path uri in
      let+ body = Reader.file_contents path in
      let+ () = send_response writer uri version body
      and () = Writer.flushed writer in
      let bytes_read = terminator_idx + Bigstring.length terminator - pos in
      `Consumed (bytes_read, `Need_unknown))
  else return `Continue
```

I mean this is great and all but wasn't the reason the reason for rolling
our own server to support htmx templating?

## Back to htmx templating

Between writing support for templating and making this section I added
support for live-reloading too. If you want to have a look it's
hosted [here](https://github.com/WINSDK/careful.observer/blob/main/saba/lib/saba.ml).

What it basically all comes down to is this:
```ocaml
let read_and_subs ~path ~uri header =
  let is_ajax_req = Map.mem header "hx-request" in
  let data_dirs = [ "/css"; "/assets" ] in
  let is_not_html = List.exists data_dirs ~f:(fun p -> String.is_prefix uri ~prefix:p) in
  if is_not_html || is_ajax_req
  then CachedFiles.read path
  else (
    let template_path = Lazy.force CachedTemplates.index in
    CachedTemplates.read ~data_path:path ~template_path)
```

Every file is cached, and on every access we read the file's metadata for its
corresponding "Date modified" field. More efficiency is to be had here but the
`stat` syscall didn't appear to add too much of an overhead.

What's most important here is the call to `CachedTemplates.read`. What we do is
read both `index.html` (the template in this example) and the requested *document*.
The neat thing is that when we *merge* these, we create a new cached document
indexed by (`template_path`, `data_path`). So when a request comes in, we only do a
single read on file changes and zero on cache hits. We don't even have to *merge*
documents on cache hits because those are also cached.

---

## Performance

Honestly, it doesn't really matter—who’s ever going to push 80 000 req/s through a personal blog, anyway?
Still, I can’t deny how much fun it is pulling up flamegraph, hunting
down all the little *bits* of allocations and tracking those unnecessary `memcpy`'s.
I also find it's just an important, useful skill to have. Deep understanding
of networking, the TCP stack, when to use TCP, when to use UDP, it's all
contributes when you want to run things at scale.


I must mention some details about specific to OCaml here:

* The `-O3` compiler flag doesn't matter much, the compiler by default is
  already running most optimizing passes.

* What *does* make a difference is the [Flambda](https://github.com/ocaml-flambda/flambda-backend)
  compiler backend. It's considered an experimental backend however (maybe contradictory)
  everyone also calls it production ready.
  From my understanding, Jane Street uses it internally for all their builds
  and it makes a massive performance difference here. I was seeing 8x increases
  in throughput. Though I must preface that my code leans heavily on
  `core` and `async` throughout, both of which include a lot of explicit
  intrinsics that flambda uses during it's code generation.

To evaluate the performance, I ran [ApacheBench](https://httpd.apache.org/docs/2.4/programs/ab.html)
on a now relatively old server 
that me and a couple friends rent. And well, it turns out the performance is very
solid. I did leave out a few string copying optimizations to keep this article concise
as it was too much to include here.

<img src="/assets/website_rewrite/perf.png">

Well there you have it. 78K req/s, I did rerun this for templated requests too
(not just `index.html`) and performance seemed similar. Here is the hardware details:

```html
==== CPU ====
CPU(s):                               8
Model name:                           Intel(R) Core(TM) i7-7700 CPU @ 3.60GHz
Thread(s) per core:                   2
Core(s) per socket:                   4
Socket(s):                            1

==== Memory ====
Total installed RAM: 62Gi
Type: DDR4 2133 MT/s

==== Drives ====
NAME TYPE   SIZE ROTA MODEL
- sda  disk 238.5G    0 Micron_1100_MTFDDAK256TBN -- SATA SSD
- sdb  disk 238.5G    0 Micron_1100_MTFDDAK256TBN -- SATA SSD
```

<br />

#### References

<a id="1">[1]</a>: If you're preloading content, this requires an extra header
and is less well supported by htmx.

<a id="2">[2]</a>: The book got a second edition in 2022, so
it's relevant up-to-date. It's honestly one of the best 0 to 100 programming
books I've read, and it's even hosted for free at <https://dev.realworldocaml.org>!
If you're interested about learning about functional programming, it's a
great introduction whilst not being [super theoretical](https://en.wikipedia.org/wiki/Haskell).

<a id="3">[3]</a>: Modular implicits—now being called *dependent modules*
were a concept introduced and implemented back in [2015](https://www.cl.cam.ac.uk/~jdy22/papers/modular-implicits.pdf).
The basic gist is that they let you define what in Haskell are called *Type classes*.
Think of them as rust *traits* where type parameters can themselves be constrained by a trait.
