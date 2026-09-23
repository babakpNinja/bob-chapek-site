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
           '<path d="M4.2 3.2l.8 2.5H7.6L5.6 7.2l.7 2.5-2.2-1.6-2.2 1.6.7-2.5L.6 5.7h2.7z" fill="#ffde00"/></svg>'}
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
