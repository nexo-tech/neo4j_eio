(function(){
  function rehighlightOcaml() {
    if (typeof window === 'undefined' || !window.hljs) return;
    var blocks = document.querySelectorAll('pre code.language-ocaml, pre code.lang-ocaml, pre code.ocaml');
    blocks.forEach(function (el) {
      try { window.hljs.highlightElement(el); } catch (e) { /* ignore */ }
    });
  }
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    rehighlightOcaml();
  } else {
    document.addEventListener('DOMContentLoaded', rehighlightOcaml);
    window.addEventListener('load', rehighlightOcaml);
  }
})();

