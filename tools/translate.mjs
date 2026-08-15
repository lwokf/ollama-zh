#!/usr/bin/env node
/**
 * Apply the zh-CN translation dictionary to a pristine Ollama source tree.
 *
 * Usage:
 *   node tools/translate.mjs <source-dir> <output-dir>
 *
 * Matching is exact-literal based so it is safe against substring corruption:
 *   - "KEY" (double-quoted string literal, JS/TS/Go)
 *   - 'KEY' (single-quoted string literal)
 *   - `KEY` (template literal)
 *   - >KEY< (JSX text node)
 */
import fs from "node:fs";
import path from "node:path";

const dictPath = path.join(import.meta.dirname, "..", "translations", "zh-CN.json");
const dict = JSON.parse(fs.readFileSync(dictPath, "utf8"));

const [src, dst] = process.argv.slice(2);
if (!src || !dst) {
  console.error("usage: node tools/translate.mjs <source-dir> <output-dir>");
  process.exit(1);
}

function esc(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Build replacement patterns per key: full-literal matches only.
const rules = [];
for (const [en, zh] of Object.entries(dict)) {
  const e = esc(en);
  rules.push([new RegExp(`"${e}"`, "g"), `"${zh}"`]);
  rules.push([new RegExp(`'${e}'`, "g"), `'${zh}'`]);
  rules.push([new RegExp("`" + e + "`", "g"), "`" + zh + "`"]);
  rules.push([new RegExp(`>\\s*${e}\\s*<`, "g"), `>${zh}<`]);
}

// Special-case rules that cannot be expressed as exact literals in the dictionary
// (multi-line JSX text, template literals with interpolation, JSX fragments).
const specialRules = [
  // Settings -> Context length description (JSX text spans multiple source lines)
  // 注意:> 与文本之间可能跨行,必须用 \s* 连接,否则 v0.32.13 起的多行写法匹配不到
  [
    />\s*Context\s+length\s+determines\s+how\s+much\s+of\s+your\s+conversation[\s\S]*?local\s+LLMs\s+can\s+remember\s+and\s+use\s+to\s+generate\s+responses\.\s*</g,
    ">上下文长度决定了本地大模型能记住并使用多少对话内容来生成回复。</",
  ],
  // Thinking.tsx -> interpolated "Thought for X seconds" template literal
  [/`Thought for \$\{thinkingTime\.toFixed\(1\)\} seconds`/g, "`思考了 ${thinkingTime.toFixed(1)} 秒`"],
  // Message.tsx -> "Search results for <InlineSearchTerm .../>" JSX fragment
  [/Search results for /g, "搜索结果: "],
  // Message.tsx -> "Searching for <InlineSearchTerm .../>" JSX fragment
  [/Searching for /g, "正在搜索: "],
  // Message.tsx -> "Fetching for <InlineSearchTerm .../>" JSX fragment
  [/Fetching for /g, "正在抓取: "],
  // Message.tsx -> "Fetch results for {url}" JSX fragment
  [/Fetch results for/g, "网页抓取结果: "],
  // Message.tsx -> "Calling <span>{toolCall.function.name}</span>" JSX fragment
  // 注意:必须带 <span 限定,否则会误伤其他文件里的英文注释(如 app.go 的 "Calling UpdateAvailable")
  [/Calling <span/g, "正在调用 <span"],
  // Message.tsx -> "Opening link #{id} from {page}" JSX fragment
  [
    /Opening link #\{id\} from \{cursorToPage\(cursor, browserToolResult\)\}/g,
    "正在打开链接 #{id}:{cursorToPage(cursor, browserToolResult)}",
  ],
  // FileUpload.tsx -> 拖拽上传提示(JSX 文本跨两行)
  [
    /Drop\s+files\s+here\s+or\s+paste\s+from\s+clipboard\s+to\s+add\s+them\s+to\s+your\s+message/g,
    "将文件拖到此处,或从剪贴板粘贴以添加到消息中",
  ],
  // Settings.tsx 标题 "Settings":前面有 {isWindows && ...} 代码块,词典的 >\s*Settings\s*< 规则匹配不到
  [/\)\}\s*Settings\s*<\/h1>/, ")}\n          设置\n        </h1>"],
  // main.tsx -> 引入路由级错误兜底组件(中文版,替换 @tanstack/react-router 默认英文错误组件
  // "Something went wrong!" / "Show Error" / "Hide Error",该组件位于库内部,词典替换够不着)
  [
    /import \{ RouterProvider, createRouter \} from "@tanstack\/react-router";/,
    'import { RouterProvider, createRouter } from "@tanstack/react-router";\nimport { ErrorFallback } from "./components/ErrorFallback";',
  ],
  // main.tsx -> 注册为全局默认错误组件(defaultErrorComponent)
  [
    /const router = createRouter\(\{\r?\n\s*routeTree,\r?\n\s*context: \{ queryClient \},\r?\n\}\);/,
    "const router = createRouter({\n  routeTree,\n  context: { queryClient },\n  defaultErrorComponent: ErrorFallback,\n});",
  ],
];

// 新增文件:路由级错误兜底组件(中文版)
// 替换 @tanstack/react-router 默认英文错误组件("Something went wrong!" / "Show Error" / "Hide Error"),
// 通过 main.tsx 的 createRouter defaultErrorComponent 注册生效。
const NEW_FILES = {
  "app/ui/app/src/components/ErrorFallback.tsx": `import { useState } from "react";
import type { ErrorComponentProps } from "@tanstack/react-router";

/**
 * 路由级错误兜底组件(中文版)。
 * 替换 @tanstack/react-router 默认英文错误组件("Something went wrong!" / "Show Error" / "Hide Error"),
 * 该组件位于 @tanstack/react-router 库内部,无法用词典替换,故在此提供中文实现,
 * 并在 main.tsx 的 createRouter 中通过 defaultErrorComponent 注册为全局默认错误组件。
 */
export const ErrorFallback = ({ error }: ErrorComponentProps) => {
  const [showDetails, setShowDetails] = useState(false);
  return (
    <div style={{ padding: ".5rem", maxWidth: "100%" }}>
      <div style={{ display: "flex", alignItems: "center", gap: ".5rem" }}>
        <strong style={{ fontSize: "1rem" }}>出错了!</strong>
        <button
          style={{
            appearance: "none",
            fontSize: ".6em",
            border: "1px solid currentColor",
            padding: ".1rem .2rem",
            fontWeight: "bold",
            borderRadius: ".25rem",
          }}
          onClick={() => setShowDetails((v) => !v)}
        >
          {showDetails ? "隐藏错误" : "显示错误"}
        </button>
      </div>
      <div style={{ height: ".25rem" }} />
      {showDetails && error.message && (
        <pre
          style={{
            fontSize: ".7em",
            border: "1px solid red",
            borderRadius: ".25rem",
            padding: ".3rem",
            color: "red",
            overflow: "auto",
          }}
        >
          {error.message}
        </pre>
      )}
    </div>
  );
};
`,
};

// Directories under upstream that hold user-facing UI strings.
const SCOPE = ["app/ui/app/src", "app/wintray", "app/cmd", "app/ui/ui.go", "app/ui/app.go"];

let replaced = 0;

function walk(dir, rel = "") {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const relPath = rel ? `${rel}/${entry.name}` : entry.name;
    const abs = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === ".git" || entry.name === "node_modules" || entry.name === "dist") continue;
      fs.mkdirSync(abs.replace(src, dst), { recursive: true });
      walk(abs, relPath);
    } else {
      const outAbs = abs.replace(src, dst);
      fs.mkdirSync(path.dirname(outAbs), { recursive: true });
      let content = fs.readFileSync(abs);
      const inScope = SCOPE.some((s) => relPath === s || relPath.startsWith(s + "/") || relPath.endsWith(s));
      if (inScope) {
        let text = content.toString("utf8");
        let before = text;
        for (const [re, zh] of rules) {
          text = text.replace(re, zh);
        }
        for (const [re, zh] of specialRules) {
          text = text.replace(re, zh);
        }
        if (text !== before) {
          replaced += countDiff(before, text);
        }
        content = Buffer.from(text, "utf8");
      }
      fs.writeFileSync(outAbs, content);
    }
  }
}

function countDiff(a, b) {
  const countA = (s) => (s.match(/[\u4e00-\u9fff]/g) || []).length;
  return Math.abs(countA(b) - countA(a));
}

if (!fs.existsSync(src)) {
  console.error(`source dir not found: ${src}`);
  process.exit(1);
}
const srcResolved = path.resolve(src);
const dstResolved = path.resolve(dst);
if (srcResolved !== dstResolved) {
  fs.rmSync(dst, { recursive: true, force: true });
  fs.mkdirSync(dst, { recursive: true });
}
walk(src);

// 写入新增文件(词典/替换规则无法表达的文件级新增)
for (const [rel, content] of Object.entries(NEW_FILES)) {
  const abs = path.join(dst, rel);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, content);
  replaced += countDiff("", content);
}

console.log(`translated tree written to ${dst}`);
