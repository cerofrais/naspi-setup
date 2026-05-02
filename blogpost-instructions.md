# Blog Post Writing Instructions

These are the conventions I follow for my technical blog posts. Reference this file when writing or reviewing any new post.

---

## Voice and Tone

- Write in first person ("I wanted", "I chose", "I ran into").
- Be direct and factual. No hype, no filler phrases like "In today's world" or "It's important to note".
- Address the reader occasionally as "you" when giving instructions.
- Assume the reader is technically capable but unfamiliar with the specific tools being discussed.

---

## Structure

Every post follows this skeleton (adapt sections as needed, but keep the order):

1. **One-paragraph introduction** — what you built and why, no backstory.
2. **Hardware** (if applicable) — bulleted list with short explanation of each choice.
3. **Why Not [the obvious choice]** (if applicable) — explain constraints or trade-offs that led to a non-obvious decision.
4. **Software Stack** — a table or bulleted list of tools and their roles, then a paragraph on each.
5. **Setup / How It Works** — numbered steps or per-script/component breakdowns.
6. **Running It** — minimal code block showing how to actually run the thing.
7. **Result** — short bulleted list of what the finished system does.

---

## Formatting Rules

- Use `##` for top-level sections, `###` for subsections. No `#` (reserved for the title).
- Use a table for a stack/comparison summary when there are 3+ tools.
- Use fenced code blocks (triple backtick) for all commands, file contents, and config snippets. Always include the language tag (`bash`, `ini`, etc.).
- Use `inline code` for file paths, command names, package names, flags, and port numbers.
- Use `**bold**` for proper nouns being introduced for the first time in a section (tool names, OS names).
- Use `> blockquote` for warnings or things that can cause data loss.
- Use a horizontal rule (`---`) to separate major sections.

---

## What to Include

- Exact commands the reader needs to run.
- Why a non-obvious choice was made (constraint, incompatibility, trade-off).
- Brief description of what each script/component does — one to two sentences is enough.
- Any manual steps that scripts cannot automate (reboots, browser auth flows).

## What to Omit

- Long backstory or motivation before the intro paragraph.
- Exhaustive command output or config file dumps — link to the repo instead.
- Comparisons to every alternative — only mention alternatives you actually evaluated.
- Future work / "in a future post" sections.

---

## File and Publishing Conventions

- Filename: `blogpost.md` at the root of the project repo.
- Title: sentence case, no subtitle unless genuinely needed.
- No date in the filename — the git commit history is the record.
- Images (if any): store in `assets/` at the repo root, reference with relative paths.

---

## Checklist Before Publishing

- [ ] Introduction is one paragraph and explains what was built and why.
- [ ] Every tool/package name is in `inline code` on first reference.
- [ ] Every command block has a language tag.
- [ ] Warnings about destructive operations use `>` blockquote.
- [ ] No filler phrases or hype language.
- [ ] "Running It" section has a minimal, copy-pasteable example.
- [ ] Result section is a short bullet list, not prose.
