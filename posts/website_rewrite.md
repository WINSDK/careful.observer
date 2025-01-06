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

So htmx something about preload, something about different kinds of preload.

Something about styling, pandoc (custom template, rust.xml and filter).

Something about trying to keep using nginx. Writing single-page application (SPA)
and reloading being broken.

```css
server {
    listen 80;
    server_name careful.observer careful.observer;

    root /var/www/nicolas/public;
    index index.html;

    # Serve static files directly.
    location /static/ {
        alias /var/www/nicolas/public/static/;
        expires 30d;
        add_header Cache-Control "public";
    }

    # Handle all other routes by serving index.html.
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Optional: Handle error pages
    error_page 404 /index.html;
    location = /index.html {
        internal;
    }
}
```


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
