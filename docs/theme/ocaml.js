(function(){
  function ocaml(hljs) {
    const KEYWORDS = {
      keyword: 'and as asr begin class constraint do done downto else end exception external for fun function functor if in include inherit initializer land let lor lsl lsr lxor match method mod module mutable new nonrec object of open or private rec sig struct then to try type val virtual when while with',
      literal: 'true false',
      built_in: 'print_endline print_string print_int ignore ref fst snd Some None Ok Error'
    };

    const COMMENT = hljs.COMMENT('\\(\\*', '\\*\\)', { contains: ['self'] });

    const NUMBER = {
      className: 'number',
      variants: [
        { begin: '\\b0[xX][0-9a-fA-F_]+[lL]?\\b' },
        { begin: '\\b0[oO][0-7_]+[lL]?\\b' },
        { begin: '\\b0[bB][01_]+[lL]?\\b' },
        { begin: '\\b[0-9][0-9_]*([uUlL]|\\.[0-9_]+([eE][-+]?[0-9_]+)?)?\\b' }
      ],
      relevance: 0
    };

    const CHAR = {
      className: 'string',
      begin: "'",
      end: "'",
      illegal: '.',
      contains: [
        { begin: "\\\\[\\\"'nrtbf]" },
        { begin: "\\\\[0-9]{3}" }
      ]
    };

    const STRING = {
      className: 'string',
      variants: [
        { begin: '"', end: '"', contains: [hljs.BACKSLASH_ESCAPE] }
      ]
    };

    const CONSTRUCTOR = { className: 'title.class', begin: '\\b[A-Z][A-Za-z0-9_\']*' };

    return {
      name: 'OCaml',
      aliases: ['ml', 'ocaml'],
      keywords: KEYWORDS,
      contains: [COMMENT, STRING, CHAR, NUMBER, CONSTRUCTOR]
    };
  }

  // Register the language and highlight all OCaml blocks
  function initOcaml() {
    if (typeof window !== 'undefined' && window.hljs) {
      window.hljs.registerLanguage('ocaml', ocaml);
      // Re-highlight all OCaml code blocks
      document.querySelectorAll('pre code.language-ocaml, pre code.lang-ocaml').forEach(function(block) {
        window.hljs.highlightElement(block);
      });
    } else if (typeof hljs !== 'undefined') {
      hljs.registerLanguage('ocaml', ocaml);
    }
  }

  // Execute when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initOcaml);
  } else {
    initOcaml();
  }
})();

