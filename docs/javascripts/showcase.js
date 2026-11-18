// Showcase demo picker: swaps the ?demo= query of the embedded Flutter runtime.
(function () {
  function init() {
    var root = document.querySelector(".zv-live-demo");
    if (!root || root.dataset.ready) return;
    root.dataset.ready = "1";
    var frame = root.querySelector("iframe");
    var open = root.querySelector("[data-open]");
    var spin = root.querySelector(".zv-spin"), tm;
    function busy(on) { spin.classList.toggle("off", !on); clearTimeout(tm); if (on) tm = setTimeout(function () { busy(false); }, 30000); }
    window.addEventListener("message", function (e) { if (e.data === "zarvan-ready" && e.source === frame.contentWindow) busy(false); });
    busy(true);
    var hint = root.querySelector(".zv-live-hint");
    root.querySelectorAll("button[data-demo], button[data-query]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        root.querySelectorAll("button[data-demo], button[data-query]").forEach(function (b) { b.classList.toggle("is-active", b === btn); });
        var src = (root.dataset.app || "app/") + "?" + (btn.dataset.query || "demo=" + btn.dataset.demo);
        busy(true);
        frame.src = src;
        if (open) open.href = src;
        if (hint && btn.dataset.hint) hint.textContent = btn.dataset.hint;
      });
    });
  }
  if (window.document$) window.document$.subscribe(init);
  else document.addEventListener("DOMContentLoaded", init);
})();

// Keep the light/dark choice in step with the landing page (same origin, key `zv-theme`).
(function () {
  var KEY = "zv-theme";
  function read() { try { return localStorage.getItem(KEY); } catch (e) { return null; } }
  function write(v) { try { localStorage.setItem(KEY, v); } catch (e) {} }
  function scheme() { return document.body.getAttribute("data-md-color-scheme") === "slate" ? "dark" : "light"; }
  function sync() {
    var want = read();
    if (want && want !== scheme()) {
      var input = document.querySelector('input[name="__palette"][data-md-color-scheme="' + (want === "dark" ? "slate" : "default") + '"]');
      if (input) input.click();
    }
    new MutationObserver(function () { write(scheme()); })
      .observe(document.body, { attributes: true, attributeFilter: ["data-md-color-scheme"] });
  }
  document.addEventListener("DOMContentLoaded", sync);
})();
