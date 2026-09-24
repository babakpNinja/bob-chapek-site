/* Language selector behaviour (issue #52).
   One script for every page: it fills the dropdown that the page ships empty and
   marks the current language. The menu itself is a <details> in the HTML, so it
   opens without this file; this only decorates it.

   Flags are inline SVG, not emoji: Windows Chrome has no colour flag glyphs and
   renders the emoji as the bare letters "US", which is not a flag. Three rects
   and a star draw everywhere. */
(function () {
  var LANGS = [
    {code: "en", name: "English", href: "/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#fff"/>' +
           '<g fill="#b22234"><rect width="22" height="1.23"/><rect y="2.46" width="22" height="1.23"/>' +
           '<rect y="4.92" width="22" height="1.23"/><rect y="7.38" width="22" height="1.23"/>' +
           '<rect y="9.84" width="22" height="1.23"/><rect y="12.3" width="22" height="1.23"/>' +
           '<rect y="14.76" width="22" height="1.24"/></g>' +
           '<rect width="9.5" height="8.62" fill="#3c3b6e"/></svg>'},
    {code: "es", name: "Español", href: "/es/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#aa151b"/>' +
           '<rect y="4" width="22" height="8" fill="#f1bf00"/></svg>'},
    {code: "zh", name: "中文", href: "/zh/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#de2910"/>' +
           '<path d="M4.2 3.2l.8 2.5H7.6L5.6 7.2l.7 2.5-2.2-1.6-2.2 1.6.7-2.5L.6 5.7h2.7z" fill="#ffde00"/></svg>'},
    {code: "ja", name: "日本語", href: "/ja/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#fff"/>' +
           '<circle cx="11" cy="8" r="4.4" fill="#bc002d"/></svg>'},
    {code: "ko", name: "한국어", href: "/ko/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#fff"/>' +
           '<path d="M11 4.4a3.6 3.6 0 010 7.2 1.8 1.8 0 010-3.6 1.8 1.8 0 000-3.6z" fill="#cd2e3a"/>' +
           '<path d="M11 4.4a3.6 3.6 0 000 7.2 1.8 1.8 0 000-3.6 1.8 1.8 0 010-3.6z" fill="#0047a0"/></svg>'},
    {code: "fr", name: "Français", href: "/fr/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#fff"/>' +
           '<rect width="7.33" height="16" fill="#0055a4"/>' +
           '<rect x="14.66" width="7.34" height="16" fill="#ef4135"/></svg>'},
    {code: "de", name: "Deutsch", href: "/de/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="5.34" fill="#000"/>' +
           '<rect y="5.34" width="22" height="5.33" fill="#dd0000"/>' +
           '<rect y="10.67" width="22" height="5.33" fill="#ffce00"/></svg>'},
    {code: "ar", name: "العربية", href: "/ar/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#006c35"/>' +
           '<path d="M4 9.4c1.4.8 3 .8 4.4 0M8.4 9.4c1.4.8 3 .8 4.4 0M12.8 9.4c1.4.8 3 .8 4.4 0" ' +
           'stroke="#fff" stroke-width="1" fill="none" stroke-linecap="round"/></svg>'},
    {code: "fa", name: "فارسی", href: "/fa/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="5.34" fill="#239f40"/>' +
           '<rect y="5.34" width="22" height="5.33" fill="#fff"/>' +
           '<rect y="10.67" width="22" height="5.33" fill="#da0000"/>' +
           '<circle cx="11" cy="8" r="1.7" fill="#da0000"/></svg>'},
    {code: "hi", name: "हिन्दी", href: "/hi/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="5.34" fill="#ff9933"/>' +
           '<rect y="5.34" width="22" height="5.33" fill="#fff"/>' +
           '<rect y="10.67" width="22" height="5.33" fill="#138808"/>' +
           '<circle cx="11" cy="8" r="1.8" fill="none" stroke="#000080" stroke-width="0.8"/></svg>'},
    {code: "ru", name: "Русский", href: "/ru/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="5.34" fill="#fff"/>' +
           '<rect y="5.34" width="22" height="5.33" fill="#0039a6"/>' +
           '<rect y="10.67" width="22" height="5.33" fill="#d52b1e"/></svg>'},
    {code: "pt", name: "Português", href: "/pt/",
     flag: '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
           '<rect width="22" height="16" fill="#da291c"/>' +
           '<rect width="8.8" height="16" fill="#046a38"/>' +
           '<circle cx="8.8" cy="8" r="3.3" fill="#ffcc00"/>' +
           '<circle cx="8.8" cy="8" r="1.9" fill="#da291c"/>' +
           '<circle cx="8.8" cy="8" r="1.0" fill="#fff"/></svg>'}
  ];
  var cur = window.BC_LANG || document.documentElement.getAttribute("lang") || "en";
  var box = document.getElementById("langPick");
  var menu = document.getElementById("langMenu");
  var label = document.getElementById("langLabel");
  var curLang = LANGS.filter(function (L) { return L.code === cur; })[0] || LANGS[0];

  if (menu) {
    LANGS.forEach(function (L) {
      var li = document.createElement("li");
      var a = document.createElement("a");
      a.href = L.href;
      a.setAttribute("lang", L.code);
      a.setAttribute("hreflang", L.code);
      if (L.code === cur) a.setAttribute("aria-current", "true");
      var f = document.createElement("span");
      f.className = "flag";
      f.innerHTML = L.flag;
      var n = document.createElement("span");
      n.textContent = L.name;
      a.appendChild(f); a.appendChild(n);
      li.appendChild(a); menu.appendChild(li);
    });
  }
  if (label) label.textContent = curLang.name;

  if (box) {
    // Close on a click anywhere else and on Escape, the way a menu is expected
    // to behave; otherwise it stays open over the page until the marker is hit.
    document.addEventListener("click", function (e) {
      if (box.open && !box.contains(e.target)) box.open = false;
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && box.open) {
        box.open = false;
        var s = box.querySelector("summary");
        if (s) s.focus();
      }
    });
  }
})();
