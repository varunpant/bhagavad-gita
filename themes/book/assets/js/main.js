/*
 * Side navigation + reading-position memory.
 *
 * Design notes:
 *  - The drawer is animated purely in CSS by toggling `nav-open` on <html>.
 *    The old version animated `width` from JS, which relayouts the entire
 *    700-link nav on every frame; the current CSS animates `transform`, which
 *    the compositor handles off the main thread.
 *  - The nav markup is identical on all 700 pages (it is partialCached), so the
 *    "current verse" highlight has to be applied here from the URL.
 */
(function () {
  "use strict";

  var STORAGE_KEY = "VERSE";
  var root = document.documentElement;

  /* ---------- current location ------------------------------------- */

  function parseVerse(path) {
    var m = /\/chapter-(\d+)\/sutra-(\d+)/.exec(path || "");
    return m ? { chapter: m[1], sutra: m[2] } : null;
  }

  /* ---------- drawer ------------------------------------------------ */

  var toggles = document.querySelectorAll("[data-nav-toggle]");
  var closers = document.querySelectorAll("[data-nav-close]");
  var backdrop = document.querySelector(".nav-backdrop");
  var nav = document.getElementById("sidenav");

  function setNav(open) {
    root.classList.toggle("nav-open", open);
    if (backdrop) backdrop.hidden = !open;
    for (var i = 0; i < toggles.length; i++) {
      toggles[i].setAttribute("aria-expanded", open ? "true" : "false");
      toggles[i].setAttribute("aria-label", open ? "Close navigation" : "Open navigation");
    }
    if (open && nav) {
      var current = nav.querySelector(".verse.is-current");
      if (current) current.scrollIntoView({ block: "center" });
    }
  }

  for (var t = 0; t < toggles.length; t++) {
    toggles[t].addEventListener("click", function () {
      setNav(!root.classList.contains("nav-open"));
    });
  }
  for (var c = 0; c < closers.length; c++) {
    closers[c].addEventListener("click", function () {
      setNav(false);
    });
  }
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && root.classList.contains("nav-open")) setNav(false);
  });

  /* ---------- highlight + open the current chapter ------------------ */

  var here = parseVerse(location.pathname);
  if (nav && here) {
    var link = nav.querySelector(
      '.verse[data-chapter="' + here.chapter + '"][data-sutra="' + here.sutra + '"]'
    );
    if (link) {
      link.classList.add("is-current");
      link.setAttribute("aria-current", "page");
    }
    var chapter = nav.querySelector('.chapter[data-chapter="' + here.chapter + '"]');
    if (chapter) {
      chapter.open = true;
      chapter.classList.add("is-current-chapter");
    }
  }

  /* Only one chapter expanded at a time — keeps the drawer scannable. */
  var chapters = nav ? nav.querySelectorAll(".chapter") : [];
  for (var d = 0; d < chapters.length; d++) {
    chapters[d].addEventListener("toggle", function () {
      if (!this.open) return;
      for (var j = 0; j < chapters.length; j++) {
        if (chapters[j] !== this) chapters[j].open = false;
      }
    });
  }

  /* ---------- remember where the reader stopped --------------------- */

  if (here) {
    try {
      localStorage.setItem(STORAGE_KEY, here.chapter + "," + here.sutra);
    } catch (e) {
      /* private mode / storage disabled */
    }
  }

  /*
   * On the homepage, offer the last-read verse as a link.
   * The previous implementation redirected automatically, which meant the
   * site's front page was unreachable for returning visitors.
   */
  var resume = document.querySelector("[data-resume]");
  if (resume && !here) {
    var saved = null;
    try {
      saved = localStorage.getItem(STORAGE_KEY);
    } catch (e) {}
    if (saved && /^\d+,\d+$/.test(saved)) {
      var parts = saved.split(",");
      /* The trigger may be the element itself (hero button) or nested. */
      var a = resume.matches("[data-resume-link]")
        ? resume
        : resume.querySelector("[data-resume-link]");
      a.href = "/chapter-" + parts[0] + "/sutra-" + parts[1] + "/";
      a.textContent = "Continue reading — Verse " + parts[0] + "." + parts[1];
      resume.hidden = false;
    }
  }

  /* -----------------------------------------------------------------
     The rail's own three controls.

     Each remembers its choice in this browser and nowhere else, which is the
     same bargain the reading position already makes above: no account, no
     server, nothing that leaves the machine.

     All three read and write `<html>` attributes rather than classes on the
     body, so the choice is applied before first paint by the inline snippet in
     head.html — without it a dark reader gets a white flash on every page.
     ----------------------------------------------------------------- */

  var THEMES = ["light", "sepia", "dark"];
  var SIZES = ["1", "1.15", "1.3"];
  var THEME_KEY = "gita:theme";
  var SIZE_KEY = "gita:size";

  function stored(key, fallback) {
    try {
      return localStorage.getItem(key) || fallback;
    } catch (e) {
      return fallback;
    }
  }

  function remember(key, value) {
    try {
      localStorage.setItem(key, value);
    } catch (e) {}
  }

  function applyTheme(name) {
    document.documentElement.setAttribute("data-theme", name);
    remember(THEME_KEY, name);
  }

  function applySize(scale) {
    document.documentElement.style.setProperty("--read-scale", scale);
    remember(SIZE_KEY, scale);
  }

  function cycle(list, current) {
    var at = list.indexOf(current);
    return list[(at + 1) % list.length];
  }

  var themeButton = document.querySelector("[data-theme-cycle]");
  if (themeButton) {
    themeButton.addEventListener("click", function () {
      applyTheme(cycle(THEMES, stored(THEME_KEY, "light")));
    });
  }

  var sizeButton = document.querySelector("[data-size-cycle]");
  if (sizeButton) {
    applySize(stored(SIZE_KEY, "1"));
    sizeButton.addEventListener("click", function () {
      applySize(cycle(SIZES, stored(SIZE_KEY, "1")));
    });
  }

  /* ---------- go to a verse ----------
     The one thing a reader arrives already knowing is the number, and the
     directory is 700 links long. This takes "2.47", "2 47" or "2/47" and
     opens it — and says so when the reference is not in the book, rather than
     navigating to a 404. */

  var jump = document.getElementById("jump");
  var jumpToggle = document.querySelector("[data-jump-toggle]");
  var jumpForm = document.querySelector("[data-jump-form]");
  var jumpHint = document.querySelector("[data-jump-hint]");
  var CHAPTER_LENGTHS = [47, 72, 43, 42, 29, 47, 30, 28, 34, 42, 55, 20, 34, 27, 20, 24, 28, 78];

  function showJump(open) {
    if (!jump || !jumpToggle) return;
    jump.hidden = !open;
    jumpToggle.setAttribute("aria-expanded", open ? "true" : "false");
    if (open) jump.querySelector("input").focus();
  }

  if (jumpToggle) {
    jumpToggle.addEventListener("click", function () {
      showJump(jump.hidden);
    });
  }

  if (jumpForm) {
    jumpForm.addEventListener("submit", function (e) {
      e.preventDefault();
      var raw = jumpForm.querySelector("input").value.trim();
      var parts = raw.split(/[^0-9]+/).filter(Boolean);
      var chapter = parseInt(parts[0], 10);
      var sutra = parseInt(parts[1], 10);

      var known =
        parts.length === 2 &&
        chapter >= 1 && chapter <= 18 &&
        sutra >= 1 && sutra <= CHAPTER_LENGTHS[chapter - 1];

      if (!known) {
        jumpHint.textContent = raw
          ? "There is no verse " + raw + " in the Gita."
          : "Chapter and verse, like 2.47.";
        jumpHint.className = "jump__hint jump__hint--error";
        return;
      }

      window.location.href = "/chapter-" + chapter + "/sutra-" + sutra + "/";
    });
  }

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && jump && !jump.hidden) showJump(false);
  });

  /* -----------------------------------------------------------------
     Verse details — which parts of a verse are on the page.

     A verse page now carries the shloka, a transliteration, two translations,
     a commentary, two meanings and two word lists: complete, and for most
     readers too much at once. These are the same switches the app keeps under
     Settings, doing the same job, remembered the same way.

     The sections are found by their headings rather than marked up with
     classes, because the markdown is generated by `main.py` from the corpus
     and the headings are its only stable landmarks. Everything from one `h3`
     up to the next belongs to it.
     ----------------------------------------------------------------- */

  var PARTS = {
    "Transliteration": "translit",
    "अनुवाद": "hi-rendering",
    "Translation": "en-rendering",
    "Hindi Translation By Swami Ramsukhdas": "hi-translation",
    "Hindi Commentary By Swami Chinmayananda": "hi-commentary",
    "भावार्थ": "hi-meaning",
    "शब्दार्थ": "hi-words",
    "English Translation By Swami  Sivananda": "en-translation",
    "English Translation By Swami Sivananda": "en-translation",
    "Meaning": "en-meaning",
    "Word by word": "en-words"
  };

  /* Both word lists start off, exactly as in the app: most readers want the
     verse, not the grammar, and together they are the longest thing here. */
  var PART_DEFAULTS = {
    translit: true,
    "hi-rendering": true,
    "en-rendering": true,
    "hi-translation": true,
    "hi-commentary": true,
    "hi-meaning": true,
    "hi-words": false,
    "en-translation": true,
    "en-meaning": true,
    "en-words": false
  };

  var PART_KEY = "gita:parts";

  function readParts() {
    var chosen = {};
    for (var key in PART_DEFAULTS) chosen[key] = PART_DEFAULTS[key];
    try {
      var saved = JSON.parse(localStorage.getItem(PART_KEY) || "{}");
      for (var k in saved) {
        if (k in chosen) chosen[k] = !!saved[k];
      }
    } catch (e) {}
    return chosen;
  }

  /* Group the flat run of headings and content into sections, once. */
  function collectSections(page) {
    var sections = {};
    var headings = page.querySelectorAll("h3");

    for (var i = 0; i < headings.length; i++) {
      var heading = headings[i];
      var part = PARTS[heading.textContent.trim()];
      if (!part) continue;                   /* the shloka has no switch */

      if (!sections[part]) sections[part] = [];
      sections[part].push(heading);

      var node = heading.nextElementSibling;
      while (node && node.tagName !== "H3") {
        sections[part].push(node);
        node = node.nextElementSibling;
      }
    }
    return sections;
  }

  var page = document.querySelector(".verse-page");
  if (page) {
    var sections = collectSections(page);
    var chosen = readParts();

    function applyParts() {
      for (var part in sections) {
        for (var i = 0; i < sections[part].length; i++) {
          sections[part][i].hidden = !chosen[part];
        }
      }
    }

    applyParts();

    var boxes = document.querySelectorAll("[data-part]");
    for (var b = 0; b < boxes.length; b++) {
      (function (box) {
        box.checked = !!chosen[box.getAttribute("data-part")];
        box.addEventListener("change", function () {
          chosen[box.getAttribute("data-part")] = box.checked;
          applyParts();
          try {
            localStorage.setItem(PART_KEY, JSON.stringify(chosen));
          } catch (e) {}
        });
      })(boxes[b]);
    }
  }

  /* Every panel's cross. One handler for both, closing whatever it names and
     putting the rail button that opened it back to `aria-expanded=false`. */
  var crosses = document.querySelectorAll("[data-close-panel]");
  for (var c = 0; c < crosses.length; c++) {
    (function (cross) {
      cross.addEventListener("click", function () {
        var name = cross.getAttribute("data-close-panel");
        var panel = document.getElementById(name);
        var opener = document.querySelector("[data-" + name + "-toggle]");
        if (panel) panel.hidden = true;
        if (opener) opener.setAttribute("aria-expanded", "false");
      });
    })(crosses[c]);
  }

  /* The panel itself. */
  var settings = document.getElementById("settings");
  var settingsToggle = document.querySelector("[data-settings-toggle]");

  if (settingsToggle && settings) {
    settingsToggle.addEventListener("click", function () {
      var open = settings.hidden;
      settings.hidden = !open;
      settingsToggle.setAttribute("aria-expanded", open ? "true" : "false");
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && !settings.hidden) {
        settings.hidden = true;
        settingsToggle.setAttribute("aria-expanded", "false");
      }
    });
  }
})();
