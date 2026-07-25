# CLAUDE.md

Static site for **bhagwadgita.info** — all 700 verses of the Bhagavad Gita with the
original Sanskrit plus Hindi and English translations/commentary. Built with Hugo,
hosted on GitHub Pages.

## Stack

| Piece | Choice |
| --- | --- |
| Generator | Hugo (extended), currently building on v0.164.0 |
| Theme | `themes/book` — local, hand-written, **not** a git submodule |
| Content source | Scraped from gitasupersite.iitk.ac.in by `main.py` |
| Hosting | GitHub Pages, serving the `docs/` folder on `master` |
| Domain | `bhagwadgita.info` via `CNAME` |

## Layout

```
config.toml            site config; note publishDir = "docs"
content/
  chapter-1..18/       sutra-N.md — one file per verse, 700 total
data/
  chapters.toml        chapter names (Sanskrit + English), keyed "1".."18"
static/
  CNAME                custom domain, copied into docs/ on every build
docs/                  BUILD OUTPUT — committed to git, this is what Pages serves
themes/book/
  layouts/
    index.html         homepage: chapter/verse directory
    _default/
      baseof.html      shell for every page, including the homepage
      single.html      one verse
      list.html        chapter index (/chapter-N/)
    partials/          head, header, footer, sideNav, burger, pagination, analytics
  assets/              css/main.css, js/main.js — piped through minify+fingerprint
  static/              krishna.png (og:image), krishna-300.png (footer), favicon.ico
main.py                scraper + content generator (see below)
srimad.csv             scraped raw data, the intermediate the generator reads
publish.sh             build + commit + push in one shot
```

### Content model

Every verse file carries the front matter the templates group on:

```yaml
title: "Verse: 1,1"
chapter: 1     # int — templates select on this with `where`
sutra: 1       # int — ordering within a chapter, `sort ... "Params.sutra"`
position: 1    # global running counter
```

`chapter` and `sutra` must stay integers. The nav, homepage directory, and chapter
lists all sort and group on them; a stringified value silently sorts wrong.

The body is fixed-shape Markdown: four `###` sections (मूल श्लोक, Hindi translation
by Swami Ramsukhdas, Hindi commentary by Swami Chinmayananda, English translation by
Swami Sivananda), each wrapped in a fenced code block to preserve the source line
breaks. Keep that shape — `css/main.css` styles the site around it.

### Regenerating content

`main.py` has two entry points:

- `crawl()` — hits the IIT Kanpur Gita Supersite, scrapes each verse, appends rows to
  `srimad.csv`. Slow and network-dependent; only rerun if the source data changes.
- `main()` — the default when you run the script. Reads `srimad.csv` and rewrites
  every `content/chapter-N/sutra-M.md`. This is the safe, offline path.

`main()` **overwrites** the whole `content/` tree, so hand edits to verse files are
not durable — fix `srimad.csv` (or the template inside `main.py`) instead.

It needs `requests` and `beautifulsoup4`. Use a venv:

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install requests beautifulsoup4
python main.py
```

### Social share cards

`tools/make_og_images.py` renders one 1200×630 JPEG per verse into
`themes/book/static/og/<chapter>-<sutra>.jpg`, plus `og/default.jpg` for the
homepage. `head.html` points `og:image` / `twitter:image` at the matching card, so
pasting a verse link into WhatsApp, Twitter/X or Telegram previews that verse
specifically — chapter name, verse number, the shloka, the English translation and
the domain.

```bash
.venv/bin/pip install Pillow
.venv/bin/python tools/make_og_images.py     # ~700 cards, about 40 MB
```

Only rerun it when verse text or the card design changes; the output is committed
like any other static asset. Two constraints:

- Pillow **must** be built with Raqm (`PIL.features.check("raqm")`), otherwise
  Devanagari conjuncts render as broken glyph sequences. The script refuses to run
  without it.
- It reads Devanagari and serif faces from macOS system font paths. On another OS,
  repoint `DEVA` / `LATIN` / `LATIN_BOLD` at the top of the script.

`krishna.png` is gold line art on an **opaque black** field with no alpha channel —
the watermark mask is built from luminance, not from alpha or an inverted mask.
Both of those stamp a visible rectangle.

## SEO

Handled in `partials/head.html` and `partials/schema.html`:

- Per-page `<title>` and `<meta description>`; verse descriptions are built from
  that verse's English translation, so no two of the 700 pages are duplicates.
- `rel=canonical`, plus `rel=prev` / `rel=next` across the verse sequence.
- JSON-LD: `WebSite` + `Book` on the homepage, `Chapter` + `BreadcrumbList` on
  every verse.
- Per-page Open Graph / Twitter card images with explicit width and height.
- `robots.txt` (`themes/book/layouts/robots.txt`) pointing at the sitemap, and
  `disableKinds = ["taxonomy", "term"]` so empty tag/category pages are not built.
- The site name is the `<h1>` only on the homepage; verse and chapter pages use
  their own heading, which is what a crawler expects.

## Build and release

The output directory `docs/` is **committed to the repository** — GitHub Pages is
configured to serve `master` / `docs`, so a build artifact landing in a commit *is*
the deploy. There is no CI; nothing else publishes this site.

Normal release:

```bash
./publish.sh                 # or: ./publish.sh "custom commit message"
```

which is exactly:

1. `hugo --minify` → writes into `docs/`
2. `git add .` → stages content **and** the regenerated `docs/`
3. `git commit -m "rebuilding site <date>"`
4. `git push origin master` → GitHub Pages picks it up within a minute or two

Consequences worth knowing:

- **Every content change needs a rebuild in the same commit.** Editing `content/`
  without running Hugo changes nothing on the live site.
- Diffs are large and noisy — one verse edit can touch hundreds of files in `docs/`
  because the side nav is baked into every page. That's expected, not a mistake.
- Hugo does not delete unknown files from `docs/`. Stale output from older builds
  lingers (e.g. `docs/page/`, left over from a pagination scheme no longer used).
  Remove such directories by hand when you notice them.
- `publish.sh` ends with a stray `cd ..` — harmless, but it means the script assumes
  it is run from the project root.

Local preview:

```bash
hugo server -D          # http://localhost:1313
```

## Gotchas

- **The theme is vendored, not a submodule.** There is no `.gitmodules`; edit
  `themes/book/` directly and commit it like any other source.
- **Never group verses with `GroupByParam`.** It only groups *string* params, and
  `chapter` / `sutra` are written as ints by `main.py`. It returns zero groups
  silently — which is exactly how the side nav and the homepage directory came to
  render completely empty after Hugo was upgraded. Select with
  `where site.RegularPages "Params.chapter" $n` instead.
- `sideNav.html` is rendered through `partialCached` with **no variant**, so it is
  built once and shared by all 742 pages. It must therefore never reference the
  current page — the "you are here" highlight is applied at runtime in `main.js`
  from `location.pathname`.
- `css/main.css` and `js/main.js` live in `themes/book/assets/`, not `static/`, so
  they go through `minify | fingerprint`. Their published filenames contain a
  content hash; do not link to `/css/main.css` directly.
- The drawer animates `transform`, never `width`. Animating width relayouts ~700
  links per frame, which is what made the original slide-in stutter.
- Google Analytics is a hardcoded UA property (`UA-16978408-5`) in
  `partials/analytics.html`. Universal Analytics stopped collecting data in 2023;
  this tag does nothing until it's replaced with a GA4 measurement ID.
- `docs/page/`, `docs/tags/` and `docs/categories/` are stale output from earlier
  builds. Hugo will not remove them; delete by hand.
- `.DS_Store` files are committed despite being in `.gitignore` (added before the
  ignore rule). Safe to `git rm --cached` them.
