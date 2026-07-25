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
})();
