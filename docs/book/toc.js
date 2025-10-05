// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><a href="introduction.html"><strong aria-hidden="true">1.</strong> Introduction</a></li><li class="chapter-item expanded "><a href="installation.html"><strong aria-hidden="true">2.</strong> Installation</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="quickstart.html"><strong aria-hidden="true">2.1.</strong> Quick Start</a></li></ol></li><li class="chapter-item expanded "><a href="configuration.html"><strong aria-hidden="true">3.</strong> Configuration</a></li><li class="chapter-item expanded "><a href="pipelines/index.html"><strong aria-hidden="true">4.</strong> Pipelines</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="pipelines/overview.html"><strong aria-hidden="true">4.1.</strong> Overview</a></li><li class="chapter-item expanded "><a href="pipelines/transformations.html"><strong aria-hidden="true">4.2.</strong> Transformations</a></li><li class="chapter-item expanded "><a href="pipelines/chaining.html"><strong aria-hidden="true">4.3.</strong> Chaining</a></li><li class="chapter-item expanded "><a href="pipelines/examples.html"><strong aria-hidden="true">4.4.</strong> Examples</a></li></ol></li><li class="chapter-item expanded "><a href="core-concepts/index.html"><strong aria-hidden="true">5.</strong> Core Concepts</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="core-concepts/sessions.html"><strong aria-hidden="true">5.1.</strong> Sessions and Connections</a></li><li class="chapter-item expanded "><a href="core-concepts/queries.html"><strong aria-hidden="true">5.2.</strong> Query Execution</a></li><li class="chapter-item expanded "><a href="core-concepts/values.html"><strong aria-hidden="true">5.3.</strong> Values</a></li><li class="chapter-item expanded "><a href="core-concepts/records.html"><strong aria-hidden="true">5.4.</strong> Records and Extraction</a></li><li class="chapter-item expanded "><a href="core-concepts/errors.html"><strong aria-hidden="true">5.5.</strong> Errors</a></li></ol></li><li class="chapter-item expanded "><a href="query-building/index.html"><strong aria-hidden="true">6.</strong> Query Building</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="query-building/query-builder.html"><strong aria-hidden="true">6.1.</strong> Query Builder DSL</a></li><li class="chapter-item expanded "><a href="query-building/parameters.html"><strong aria-hidden="true">6.2.</strong> Parameters</a></li><li class="chapter-item expanded "><a href="query-building/programmatic.html"><strong aria-hidden="true">6.3.</strong> Programmatic Building</a></li><li class="chapter-item expanded "><a href="query-building/patterns.html"><strong aria-hidden="true">6.4.</strong> Common Patterns</a></li></ol></li><li class="chapter-item expanded "><a href="advanced/index.html"><strong aria-hidden="true">7.</strong> Advanced</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="advanced/transactions.html"><strong aria-hidden="true">7.1.</strong> Transactions</a></li><li class="chapter-item expanded "><a href="advanced/tx-dsl.html"><strong aria-hidden="true">7.2.</strong> Transaction DSL</a></li><li class="chapter-item expanded "><a href="advanced/streaming.html"><strong aria-hidden="true">7.3.</strong> Streaming</a></li><li class="chapter-item expanded "><a href="advanced/concurrency.html"><strong aria-hidden="true">7.4.</strong> Concurrency</a></li><li class="chapter-item expanded "><a href="advanced/pooling.html"><strong aria-hidden="true">7.5.</strong> Pooling</a></li></ol></li><li class="chapter-item expanded "><a href="extractors/index.html"><strong aria-hidden="true">8.</strong> Extractors</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="extractors/basics.html"><strong aria-hidden="true">8.1.</strong> Basics</a></li><li class="chapter-item expanded "><a href="extractors/applicative.html"><strong aria-hidden="true">8.2.</strong> Applicative</a></li><li class="chapter-item expanded "><a href="extractors/composite.html"><strong aria-hidden="true">8.3.</strong> Composite</a></li><li class="chapter-item expanded "><a href="extractors/graph.html"><strong aria-hidden="true">8.4.</strong> Graph Entities</a></li><li class="chapter-item expanded "><a href="extractors/custom.html"><strong aria-hidden="true">8.5.</strong> Custom Extractors</a></li></ol></li><li class="chapter-item expanded "><a href="graph-operations/index.html"><strong aria-hidden="true">9.</strong> Graph Operations</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="graph-operations/nodes.html"><strong aria-hidden="true">9.1.</strong> Nodes</a></li><li class="chapter-item expanded "><a href="graph-operations/relationships.html"><strong aria-hidden="true">9.2.</strong> Relationships</a></li><li class="chapter-item expanded "><a href="graph-operations/paths.html"><strong aria-hidden="true">9.3.</strong> Paths</a></li><li class="chapter-item expanded "><a href="graph-operations/lenses.html"><strong aria-hidden="true">9.4.</strong> Lenses</a></li></ol></li><li class="chapter-item expanded "><a href="examples/index.html"><strong aria-hidden="true">10.</strong> Examples</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="examples/user-management.html"><strong aria-hidden="true">10.1.</strong> User Management</a></li><li class="chapter-item expanded "><a href="examples/social-network.html"><strong aria-hidden="true">10.2.</strong> Social Network</a></li><li class="chapter-item expanded "><a href="examples/recommendations.html"><strong aria-hidden="true">10.3.</strong> Recommendations</a></li><li class="chapter-item expanded "><a href="examples/etl-pipeline.html"><strong aria-hidden="true">10.4.</strong> ETL Pipeline</a></li><li class="chapter-item expanded "><a href="examples/analytics.html"><strong aria-hidden="true">10.5.</strong> Graph Analytics</a></li></ol></li><li class="chapter-item expanded "><a href="api-reference/index.html"><strong aria-hidden="true">11.</strong> API Reference</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="api-reference/value.html"><strong aria-hidden="true">11.1.</strong> Value</a></li><li class="chapter-item expanded "><a href="api-reference/record.html"><strong aria-hidden="true">11.2.</strong> Record</a></li><li class="chapter-item expanded "><a href="api-reference/extract.html"><strong aria-hidden="true">11.3.</strong> Extract</a></li><li class="chapter-item expanded "><a href="api-reference/query-builder.html"><strong aria-hidden="true">11.4.</strong> Query Builder</a></li><li class="chapter-item expanded "><a href="api-reference/transaction-dsl.html"><strong aria-hidden="true">11.5.</strong> Transaction DSL</a></li><li class="chapter-item expanded "><a href="api-reference/pipeline.html"><strong aria-hidden="true">11.6.</strong> Cypher Pipeline</a></li><li class="chapter-item expanded "><a href="api-reference/session.html"><strong aria-hidden="true">11.7.</strong> Session</a></li><li class="chapter-item expanded "><a href="api-reference/error.html"><strong aria-hidden="true">11.8.</strong> Error</a></li><li class="chapter-item expanded "><a href="api-reference/config.html"><strong aria-hidden="true">11.9.</strong> Config</a></li></ol></li><li class="chapter-item expanded "><a href="migration/index.html"><strong aria-hidden="true">12.</strong> Migration</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="migration/benchmarks.html"><strong aria-hidden="true">12.1.</strong> Benchmarks</a></li></ol></li><li class="chapter-item expanded "><a href="troubleshooting/index.html"><strong aria-hidden="true">13.</strong> Troubleshooting</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="troubleshooting/common-errors.html"><strong aria-hidden="true">13.1.</strong> Common Errors</a></li><li class="chapter-item expanded "><a href="troubleshooting/debugging.html"><strong aria-hidden="true">13.2.</strong> Debugging</a></li><li class="chapter-item expanded "><a href="troubleshooting/faq.html"><strong aria-hidden="true">13.3.</strong> FAQ</a></li><li class="chapter-item expanded "><a href="troubleshooting/limitations.html"><strong aria-hidden="true">13.4.</strong> Limitations</a></li></ol></li><li class="chapter-item expanded "><a href="best-practices/index.html"><strong aria-hidden="true">14.</strong> Best Practices</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="best-practices/performance.html"><strong aria-hidden="true">14.1.</strong> Performance</a></li><li class="chapter-item expanded "><a href="best-practices/memory.html"><strong aria-hidden="true">14.2.</strong> Memory</a></li><li class="chapter-item expanded "><a href="best-practices/errors.html"><strong aria-hidden="true">14.3.</strong> Errors</a></li><li class="chapter-item expanded "><a href="best-practices/testing.html"><strong aria-hidden="true">14.4.</strong> Testing</a></li><li class="chapter-item expanded "><a href="best-practices/deployment.html"><strong aria-hidden="true">14.5.</strong> Deployment</a></li></ol></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0].split("?")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
