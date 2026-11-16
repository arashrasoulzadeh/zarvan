// Showcase demo picker: swaps the ?demo= query of the embedded Flutter runtime.
(function () {
  function init() {
    var root = document.querySelector(".zv-live-demo");
    if (!root || root.dataset.ready) return;
    root.dataset.ready = "1";
    var frame = root.querySelector("iframe");
    var open = root.querySelector("[data-open]");
    var hint = root.querySelector(".zv-live-hint");
    root.querySelectorAll("button[data-demo]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        root.querySelectorAll("button[data-demo]").forEach(function (b) { b.classList.toggle("is-active", b === btn); });
        var src = "app/?demo=" + btn.dataset.demo;
        frame.src = src;
        if (open) open.href = src;
        if (hint && btn.dataset.hint) hint.textContent = btn.dataset.hint;
      });
    });
  }
  if (window.document$) window.document$.subscribe(init);
  else document.addEventListener("DOMContentLoaded", init);
})();
