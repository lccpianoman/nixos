# Builds the themed start page as a standalone document, written to the store
# and used as both the homepage and the new tab page.
{
  lib,
  css,
  host,
  links,
  search,
}:

let
  link = l: ''
    <a href="${l.url}"><span style="color: ${l.accent}"></span>${l.name}</a>'';

  body = ''
    <main>
      <p class="host">${host}</p>
      <form action="${search.action}" method="get">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <line x1="16.2" y1="16.2" x2="21" y2="21" />
        </svg>
        <input type="text" name="${search.param}" autofocus
               autocomplete="off" spellcheck="false"
               placeholder="search the web…" aria-label="Search the web" />
      </form>
      <nav>
    ${lib.concatMapStringsSep "\n" link links}
      </nav>
    </main>'';
in
{
  document = ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="dark" />
        <title>${host}</title>
        <style>
    ${css}
        </style>
      </head>
      <body>
    ${body}
      </body>
    </html>'';
}
