---
title: "Rewriting my website"
date: "Jan 1, 2025"
---

## Requirements

* Want content to be served statically with *nginx*
* Minimal dependencies
* Work on mobile

Previously the website had basically no dependencies.\
No htmx, no pandoc, just static html with some self-contained javascript.

Boooooooring, I've wanted to start writing some kind of blog and 
writing that all in plain html sounds like a pain. So the minimum I wanted
to add was the ability to convert markdown to a readable blog post.
The most obvious way of doing this was to just parse markdown and assign
the appropriate html tag to each component. Unfortunately this becomes annoying
when trying to syntax highlight any kind of code block as it requires you parse
every language you might want to quote. So I decided to comprise by using pandoc, 
writing a gruvbox-esque theme and a simple template to wrap the markdown with.

```json
{
  "text-color": "#ebdbb2",
  "background-color": "#282828",
  "line-number-color": "#a89984",
  "line-number-background-color": "#282828",
  "text-styles": {
    "Normal": {
        "text-color": "#ebdbb2",
        "background-color": "#282828",
        "bold": false,
        "italic": false,
        "underline": false
    },
    ...
}
```
