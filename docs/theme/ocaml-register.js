// Register OCaml language and re-highlight code blocks
(function() {
  // Register the language using the definition from head
  if (window.hljs && window.OCAML_LANGUAGE) {
    window.hljs.registerLanguage('ocaml', window.OCAML_LANGUAGE);

    // Re-highlight all OCaml code blocks using highlightBlock (not highlightElement)
    var blocks = document.querySelectorAll('pre code.language-ocaml, pre code.lang-ocaml');
    blocks.forEach(function(block) {
      window.hljs.highlightBlock(block);
    });
  }
})();
