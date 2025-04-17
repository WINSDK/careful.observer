---
title: "Running over the road"
date: "Nov 16, 2021"
---

My experience jaywalking in the Netherlands.

## Introduction

> Viola! Here we see the two different secret values on the attacking thread. Viola! Here we see the two different secret values on the attacking thread. Viola! Here we see the two different secret values on the attacking thread.
>
> at a pretty much comparable frequency.
```asm
mov  rax, 0x12345678f00dfeed
mov [0x1000], rax

mov  rax, 0x1337133713371337
mov [0x1008], rax

label0:
    mov rax, [0x1000]
    mov rax, [0x1008]
    jmp label0
```


![example-image](https://static.vecteezy.com/system/resources/previews/011/063/921/non_2x/example-button-speech-bubble-example-colorful-web-banner-illustration-vector.jpg)
_<sub>subtitle goes here</sub>_

Cool… so now we have a technique that will allow us to see the contents of all
loads on load ports, but randomly sampled only. Let’s take a look at the weird
behaviors during accessed bit updates by clearing the accessed bit on the final
level page tables every loop in the same `IA32_DEBUGCTL` above.

```rust
impl Match {
    /// Iterate through all items that match.
    pub fn iter<'s, Metadata>(
        &self,
        tree: &'s PrefixMatch<Metadata>,
    ) -> impl Iterator<Item = (&'s str, &'s Metadata)> {
        tree.items[self.range.clone()].iter().map(|item| (item.0.as_str(), &item.1))
    }
}
```

what is this thing?

```css
Using css as a language makes this render correctly...
```

> Line one of a paragraph.<br>Line two of a paragraph.<br>Line three of a paragraph.

```ocaml
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
        let%map () = send_response writer ~uri ~path kind header version
        and () = Writer.flushed writer in
        (match Map.find header "connection" with
         | Some "close" -> `Stop reader
         | Some _ | None ->
           let bytes_read = req_terminator_idx + Bigstring.length terminator - pos in
           `Consumed (bytes_read, `Need_unknown))
      | Unsupported { issue } -> raise_s [%message "Unsupported request" (issue : string)]
      | Invalid -> raise_s [%message "(Invalid request)"])
    else return `Continue)
;;
```
