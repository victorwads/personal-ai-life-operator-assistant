import fs from "node:fs/promises";
import path from "node:path";

const webRoot = path.resolve(new URL("..", import.meta.url).pathname);
const projectRoot = path.resolve(webRoot, "..");
const docsRoot = path.join(projectRoot, "Docs");
const distRoot = path.join(webRoot, "dist");
const logoSource = path.join(webRoot, "logo.png");

const githubUrl = "https://github.com/victorwads/local-ai-personal-assistant-apps";

const pages = [
  {
    id: "home",
    source: path.join(docsRoot, "History.md"),
    output: "index.html",
    title: "AssistantMCPServer",
    description:
      "A história de um assistente pessoal experimental com IA, WhatsApp, memória e cuidado com a vida real.",
  },
  {
    id: "privacy",
    source: path.join(docsRoot, "PrivacyPolicy.md"),
    output: "privacy.html",
    title: "Política de Privacidade",
    description:
      "Como o AssistantMCPServer trata dados, memórias, dados sensíveis e solicitações de exclusão.",
  },
  {
    id: "terms",
    source: path.join(docsRoot, "TermsOfUse.md"),
    output: "terms.html",
    title: "Termos de Uso",
    description:
      "Condições para participar e testar o AssistantMCPServer como projeto experimental.",
  },
];

const navigation = [
  ["home", "Home", "index.html"],
  ["privacy", "Privacidade", "privacy.html"],
  ["terms", "Termos", "terms.html"],
];

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function escapeAttribute(value) {
  return escapeHtml(value).replaceAll("'", "&#39;");
}

function mapDocumentHref(href) {
  const normalized = href.replace(/^(\.\/)?(Docs\/)?/, "");
  const mappings = new Map([
    ["History.md", "index.html"],
    ["PrivacyPolicy.md", "privacy.html"],
    ["TermsOfUse.md", "terms.html"],
  ]);

  return mappings.get(normalized) ?? href;
}

function renderInline(markdown) {
  const codeSpans = [];
  let html = escapeHtml(markdown).replace(/`([^`]+)`/g, (_, code) => {
    const marker = `@@CODE${codeSpans.length}@@`;
    codeSpans.push(`<code>${code}</code>`);
    return marker;
  });

  html = html
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, href) => {
      return `<a href="${escapeAttribute(mapDocumentHref(href))}">${label}</a>`;
    })
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*]+)\*/g, "<em>$1</em>")
    .replace(/_([^_]+)_/g, "<em>$1</em>");

  codeSpans.forEach((code, index) => {
    html = html.replaceAll(`@@CODE${index}@@`, code);
  });

  return html;
}

function markdownToHtml(markdown) {
  const lines = markdown.replace(/\r\n?/g, "\n").split("\n");
  const html = [];
  let paragraph = [];
  let list = null;
  let blockquote = [];
  let codeFence = null;

  const flushParagraph = () => {
    if (!paragraph.length) return;
    html.push(`<p>${renderInline(paragraph.join(" "))}</p>`);
    paragraph = [];
  };

  const flushList = () => {
    if (!list) return;
    html.push(`<${list.type}>${list.items.map((item) => `<li>${renderInline(item)}</li>`).join("")}</${list.type}>`);
    list = null;
  };

  const flushBlockquote = () => {
    if (!blockquote.length) return;
    html.push(`<blockquote>${blockquote.map((line) => `<p>${renderInline(line)}</p>`).join("")}</blockquote>`);
    blockquote = [];
  };

  const flushOpenBlocks = () => {
    flushParagraph();
    flushList();
    flushBlockquote();
  };

  for (const line of lines) {
    const fenceMatch = line.match(/^```([A-Za-z0-9_-]+)?\s*$/);
    if (fenceMatch) {
      if (codeFence) {
        html.push(
          `<pre><code${codeFence.language ? ` class="language-${escapeAttribute(codeFence.language)}"` : ""}>${escapeHtml(
            codeFence.lines.join("\n"),
          )}</code></pre>`,
        );
        codeFence = null;
      } else {
        flushOpenBlocks();
        codeFence = { language: fenceMatch[1] ?? "", lines: [] };
      }
      continue;
    }

    if (codeFence) {
      codeFence.lines.push(line);
      continue;
    }

    if (!line.trim()) {
      flushOpenBlocks();
      continue;
    }

    const headingMatch = line.match(/^(#{1,6})\s+(.+)$/);
    if (headingMatch) {
      flushOpenBlocks();
      const level = headingMatch[1].length;
      html.push(`<h${level}>${renderInline(headingMatch[2])}</h${level}>`);
      continue;
    }

    const quoteMatch = line.match(/^>\s?(.*)$/);
    if (quoteMatch) {
      flushParagraph();
      flushList();
      blockquote.push(quoteMatch[1]);
      continue;
    }

    const bulletMatch = line.match(/^\s*[-*]\s+(.+)$/);
    if (bulletMatch) {
      flushParagraph();
      flushBlockquote();
      if (!list || list.type !== "ul") list = { type: "ul", items: [] };
      list.items.push(bulletMatch[1]);
      continue;
    }

    const orderedMatch = line.match(/^\s*\d+\.\s+(.+)$/);
    if (orderedMatch) {
      flushParagraph();
      flushBlockquote();
      if (!list || list.type !== "ol") list = { type: "ol", items: [] };
      list.items.push(orderedMatch[1]);
      continue;
    }

    flushList();
    flushBlockquote();
    paragraph.push(line.trim());
  }

  flushOpenBlocks();

  if (codeFence) {
    html.push(`<pre><code>${escapeHtml(codeFence.lines.join("\n"))}</code></pre>`);
  }

  return html.join("\n");
}

function renderNavigation(activeId) {
  return navigation
    .map(([id, label, href]) => {
      const current = id === activeId ? ' aria-current="page"' : "";
      return `<a href="${href}"${current}>${label}</a>`;
    })
    .join("");
}

function renderHomeIntro() {
  return `
    <section class="hero">
      <div class="hero-copy">
        <p class="eyebrow">Assistente pessoal experimental</p>
        <h1>Um runtime de IA para organizar conversas, memórias e vida real.</h1>
        <p>O projeto nasceu de uma necessidade humana: transformar WhatsApp, voz, memórias e tarefas em um assistente pessoal que ajuda de verdade, com cuidado e transparência sobre dados.</p>
      </div>
      <a class="github-card" href="${githubUrl}" target="_blank" rel="noreferrer">
        <img src="logo.png" alt="Logo do AssistantMCPServer">
        <span>Ver projeto no GitHub</span>
      </a>
    </section>`;
}

function pageTemplate(page, content) {
  const isHome = page.id === "home";
  const canonical = page.output === "index.html" ? "./" : page.output;

  return `<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="${escapeAttribute(page.description)}">
  <title>${escapeHtml(page.title)} | AssistantMCPServer</title>
  <style>${styles}</style>
</head>
<body>
  <header class="site-header">
    <a class="brand" href="./" aria-label="AssistantMCPServer">AssistantMCPServer</a>
    <nav aria-label="Navegação principal">${renderNavigation(page.id)}</nav>
  </header>
  <main>
    ${isHome ? renderHomeIntro() : ""}
    <article class="${isHome ? "document document-home" : "document"}">
      ${content}
    </article>
  </main>
  <footer>
    <span>Projeto experimental sem fins lucrativos.</span>
    <a href="${canonical}">${escapeHtml(page.title)}</a>
  </footer>
</body>
</html>
`;
}

const styles = `
:root {
  color-scheme: light;
  --bg: #f3f7f6;
  --paper: #ffffff;
  --ink: #1d1d1f;
  --muted: #63615c;
  --line: #d7e2df;
  --accent: #0d6b67;
  --accent-strong: #093f3d;
  --warm: #b15b32;
  --shadow: 0 20px 70px rgba(29, 29, 31, 0.12);
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  background:
    linear-gradient(180deg, rgba(13, 107, 103, 0.12), transparent 360px),
    var(--bg);
  color: var(--ink);
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  line-height: 1.65;
}

a {
  color: var(--accent);
  text-decoration-thickness: 1px;
  text-underline-offset: 0.18em;
}

.site-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
  max-width: 1120px;
  margin: 0 auto;
  padding: 24px;
}

.brand {
  color: var(--ink);
  font-weight: 800;
  text-decoration: none;
}

nav {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: flex-end;
}

nav a {
  border: 1px solid transparent;
  border-radius: 999px;
  color: var(--muted);
  padding: 8px 13px;
  text-decoration: none;
}

nav a[aria-current="page"] {
  background: var(--ink);
  color: var(--paper);
}

main {
  max-width: 1120px;
  margin: 0 auto;
  padding: 0 24px 56px;
}

.hero {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(280px, 0.9fr);
  gap: 32px;
  align-items: center;
  min-height: 520px;
  padding: 56px 0 40px;
}

.hero-copy {
  max-width: 720px;
}

.eyebrow {
  color: var(--warm);
  font-size: 0.82rem;
  font-weight: 800;
  letter-spacing: 0;
  margin: 0 0 12px;
  text-transform: uppercase;
}

.hero h1 {
  font-size: 5.6rem;
  line-height: 0.95;
  margin: 0;
  max-width: 900px;
}

.hero p:not(.eyebrow) {
  color: var(--muted);
  font-size: 1.2rem;
  max-width: 680px;
}

.github-card {
  background: var(--paper);
  border: 1px solid var(--line);
  border-radius: 8px;
  box-shadow: var(--shadow);
  color: var(--ink);
  display: block;
  overflow: hidden;
  text-decoration: none;
}

.github-card img {
  aspect-ratio: 1200 / 630;
  display: block;
  object-fit: cover;
  width: 100%;
}

.github-card span {
  display: block;
  font-weight: 800;
  padding: 16px 18px;
}

.document {
  background: rgba(255, 253, 248, 0.82);
  border: 1px solid var(--line);
  border-radius: 8px;
  box-shadow: 0 12px 45px rgba(29, 29, 31, 0.08);
  margin: 24px auto 0;
  max-width: 840px;
  padding: 48px;
}

.document-home {
  margin-top: 0;
}

.document h1,
.document h2,
.document h3 {
  line-height: 1.16;
}

.document h1 {
  font-size: 2.4rem;
  margin: 0 0 24px;
}

.document h2 {
  border-top: 1px solid var(--line);
  font-size: 1.45rem;
  margin: 38px 0 12px;
  padding-top: 28px;
}

.document h3 {
  font-size: 1.15rem;
  margin-top: 28px;
}

.document p,
.document li {
  color: #34322e;
}

.document blockquote {
  border-left: 4px solid var(--accent);
  color: var(--muted);
  margin: 24px 0;
  padding: 1px 0 1px 18px;
}

.document ul,
.document ol {
  padding-left: 1.35rem;
}

.document code {
  background: #e8f0ef;
  border-radius: 5px;
  font-size: 0.92em;
  padding: 0.1em 0.32em;
}

.document pre {
  background: #1f2525;
  border-radius: 8px;
  color: #f6f0e6;
  overflow: auto;
  padding: 18px;
}

.document pre code {
  background: transparent;
  color: inherit;
  padding: 0;
}

footer {
  align-items: center;
  color: var(--muted);
  display: flex;
  gap: 12px;
  justify-content: center;
  padding: 0 24px 36px;
}

@media (max-width: 760px) {
  .site-header,
  footer {
    align-items: flex-start;
    flex-direction: column;
  }

  .site-header {
    padding: 18px;
  }

  main {
    padding: 0 18px 42px;
  }

  .hero {
    grid-template-columns: 1fr;
    min-height: auto;
    padding: 34px 0 28px;
  }

  .hero h1 {
    font-size: 3rem;
  }

  .document {
    padding: 28px 22px;
  }
}

@media (min-width: 761px) and (max-width: 980px) {
  .hero h1 {
    font-size: 4.2rem;
  }
}
`;

await fs.rm(distRoot, { force: true, recursive: true });
await fs.mkdir(distRoot, { recursive: true });
await fs.copyFile(logoSource, path.join(distRoot, "logo.png"));

for (const page of pages) {
  const markdown = await fs.readFile(page.source, "utf8");
  const html = pageTemplate(page, markdownToHtml(markdown));
  await fs.writeFile(path.join(distRoot, page.output), html);
}

console.log(`Generated ${pages.length} pages in ${path.relative(projectRoot, distRoot)}`);
