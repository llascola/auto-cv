# Implementation Plan — auto-cv refactor

> Multi-session refactor tracker. Each phase is self-contained and resumable in a
> fresh context window. Read "Context" first, then do the next unchecked phase.
> Check boxes as you go and commit after each phase.

## Context (read this first)

- **What this repo is:** a LaTeX CV (`cv.tex` + `citations.bib`) that GitHub
  Actions compiles to `cv.pdf` and publishes to GitHub Pages.
- **Current pipeline** (`.github/workflows/build.yml`): 3 chained jobs —
  `build` (dante-ev/latex-action@latest → upload artifact) →
  `deploy` (peaceiris/actions-gh-pages → orphan `build` branch) →
  `copy-index-to-build` (planetoftheweb/copy-to-branches → copies index.html + CNAME).
- **Goal:** faster, reproducible, simpler CI. Keep the core idea (LaTeX source →
  CI build → published PDF). No webapp, no Docker, no over-engineering.
- **Local build:** `Makefile` calls `latexmk -pdf cv.tex`.
- **Decisions already made:** doing phases 1–4 below (clear wins). Phases 5–6
  (data/template split, releases/multi-output) are deferred — do NOT build them
  unless explicitly asked.

## Conventions

- Branch off `main`. One commit per phase, message `refactor(ci): <phase>`.
- After CI changes, push and confirm the Actions run is green before next phase.
- Don't touch `cv.tex` content. This refactor is build/CI only.

---

## Phase 1 — Switch build engine to Tectonic ✅

**Why:** `dante-ev/latex-action@latest` is unpinned (non-reproducible),
unmaintained, slow (huge TeXLive image), and needs a separate biber pass for
`citations.bib`. Tectonic is a single static binary, auto-fetches+caches only
needed packages, handles bib itself, reproducible, ~30s cold build.

**Steps:**
- [x] Update `Makefile` so local build uses Tectonic (keep a `latexmk` fallback
      target if desired). Target: `tectonic cv.tex`.
- [x] In `build.yml`, replace the `dante-ev/latex-action` step with Tectonic.
      Use `wtfjoke/setup-tectonic@v3` (or install binary directly) then run
      `tectonic cv.tex`.
- [x] Add Tectonic package cache (`~/.cache/Tectonic`) via `actions/cache`.
- [x] Verify `cv.pdf` is produced and citations render (no `[?]` markers).
      → CI run 27235648159, `build: success`, `cv.pdf` compiled. No citations
        in cv.tex so no markers. Only cosmetic FontAwesome ToUnicode warnings.

**Notes for future sessions:**
- `cv.tex` has **no** `\bibliography`/`\addbibresource`; `citations.bib` is
  currently unused, so no biber pass needed. Tectonic single-pass is enough.
- Engine is XeTeX (Tectonic default). `cv.tex` uses `[T1]{fontenc}` + babel
  spanish + fontawesome5 + hyperref — all compile under XeTeX. Watch the first
  CI run for font/encoding warnings.
- `Makefile`: `make` = tectonic, `make latexmk` = old fallback.

**Done when:** CI builds `cv.pdf` with Tectonic, citations resolve, local `make`
uses same engine (CI == local parity).

---

## Phase 2 — Native GitHub Pages, drop orphan branch + 3rd job ✅

**Why:** `peaceiris` + `copy-to-branches` + the `build` orphan branch +
`copy-index-to-build` job are fragile, use unmaintained 3rd-party actions, and
run on every push. Official Pages deploy replaces all of it with one job.

**Heads-up from Phase 1 run:** repo Actions token is currently **read-only**
(old peaceiris deploy 403'd: "denied to github-actions[bot]"). Phase 2 must add a
`permissions:` block AND the human must set Settings → Actions → Workflow
permissions to "Read and write" (or rely on the scoped Pages permissions below).

**Steps:**
- [x] Add top-level `permissions:` block (`contents: read`, `pages: write`,
      `id-token: write`) and a `concurrency` group (`pages`, cancel-in-progress).
- [x] Assemble the publish dir in the build job: `cv.pdf` + `index.html`
      (CNAME was empty → dropped). Dir is `_site`.
- [x] Replace `deploy` job with `actions/upload-pages-artifact@v3` +
      `actions/deploy-pages@v4` (environment `github-pages`).
- [x] Delete the `copy-index-to-build` job entirely.
- [x] Pages source set to "GitHub Actions" — done via API
      (`gh api -X POST repos/llascola/auto-cv/pages -f build_type=workflow`).
      Site URL: https://llascola.github.io/auto-cv/
- [x] Confirm the published URL serves the new PDF — VERIFIED after merge.
      Run 27236135725 on main: build + deploy both success.
      https://llascola.github.io/auto-cv/ → 200 (redirect HTML),
      https://llascola.github.io/auto-cv/cv.pdf → 200 application/pdf (~27KB).
- [x] Old `build` orphan branch: none existed (earlier peaceiris deploys all
      403'd before creating it). Nothing to delete.

**Done when:** single build→deploy flow, no orphan branch, no 3rd-party deploy
actions, PDF live on Pages.

---

## Phase 3 — PR builds + PDF preview artifact ✅

**Why:** a CV is visual; diffing `.tex` misses layout breakage. Build on PRs to
catch broken LaTeX before merge and attach the rendered PDF for review.

**Steps:**
- [x] Add `pull_request` trigger (alongside existing `push: main`).
- [x] Add `workflow_dispatch` for manual runs (done back in Phase 1).
- [x] Add `paths` filter so only relevant changes trigger builds. Shared
      between push + pull_request via a YAML anchor (`&source-paths` /
      `*source-paths`). Covers `**.tex`, `**.bib`, `index.html`, `CNAME`,
      `.github/workflows/**`.
- [x] Gate the deploy job: `if: github.event_name != 'pull_request'` (PRs build
      but never deploy; pushes to main + manual runs deploy).
- [x] Upload `cv.pdf` via `actions/upload-artifact@v4` (path `_site/cv.pdf`) on
      every run so reviewers can download the rendered result.

**Verified:** PR #1, run 27236606733 — `build: success`, `deploy: skipped`,
artifacts `cv.pdf` (26KB) + `github-pages` present.

**Optional later:** the `github-pages` Pages artifact is still uploaded on PRs
(harmless, just unused). Could gate that step to non-PR too. Minor.

**Done when:** opening a PR compiles the CV and exposes the PDF; only merges to
`main` deploy. ✅

---

## Phase 4 — Quality gates: chktex + spellcheck ✅ (CI verify pending)

**Why:** typos and LaTeX issues in a CV look bad. Both checks are cheap and
high-value for this specific repo.

**Key constraint:** cv.tex is **bilingual** — Spanish prose + English tech terms.
A single dictionary floods false positives. Design (user's idea): a word is OK
if EITHER Spanish OR English aspell knows it; only words unknown to BOTH are
flagged. Real names/brands/acronyms that fail both live in an allow-list.

**Implementation:**
- `scripts/spellcheck.sh` — checks the document body only (skips preamble),
  runs aspell `--mode=tex` for `es` and `en`, intersects the two "unknown"
  lists (`comm -12`), subtracts `.github/spell-allow.txt` (case-insensitive),
  fails if anything remains. Verified locally: clean on current cv.tex; flags an
  injected typo (`softwaree`); passes English-only words.
- `.github/spell-allow.txt` — seeded from the 21 both-fail words on the current
  CV (all legit: APIs, DDD, DSL, EE, UU, backend, frontend, cronjobs, onboarding,
  golang, js, microservicios, fintech, llascola, memcache, scola, unr).
- `lint` job in build.yml: installs aspell + dicts + chktex; runs `chktex`
  (continue-on-error, informational) then the spellcheck (blocking).

**Gating decision:** chktex = non-blocking (style noise). Spellcheck = blocking.
`deploy` now `needs: [build, lint]`, so a real typo on main blocks the publish.

**Steps:**
- [x] `lint` job running `chktex cv.tex` (non-blocking).
- [x] Bilingual aspell es/en spellcheck with allow-list (blocking).
- [x] Gating documented above; deploy gated on lint.
- [ ] Verify the `lint` job runs green in CI (apt install of aspell dicts +
      chktex on the runner). → pending PR run.

**Done when:** PRs surface LaTeX lint + spelling issues; deploy blocked on a real
typo.

---

## Deferred — do NOT build unless asked

### Phase 5 — Data/template split (YAML + jinja → cv.tex)
Pull CV facts into `data/cv.yml`, layout into `template.tex`, render via small
`build.py`. Enables per-application tailoring + multi-output. Only worth it if
the CV is iterated often. Adds a build dependency.

### Phase 6 — Releases + multi-output
Tag → GitHub Release with dated PDF snapshot; `cv-latest.pdf` pointer; generate
HTML/JSON-LD (schema.org) alongside PDF for SEO. Nice-to-have.

---

## Progress log

- 2026-06-09 — Phase 1 (Tectonic) done. Branch `refactor/ci-tectonic`,
  commits a87a541 + version/runner pins. CI run 27235648159 `build: success`.
  Pinned Tectonic 0.14.1 on ubuntu-22.04 (latest SIGABRTs on format gen;
  0.14.1 needs libssl1.1 → 22.04). Deploy job still fails (peaceiris 403) —
  that's replaced in Phase 2.
- 2026-06-09 — Phase 2 (native Pages) done + merged to main. Merge commit
  5e8ea93. Run 27236135725 on main: build + deploy success. Live PDF served at
  https://llascola.github.io/auto-cv/cv.pdf (200, application/pdf). Pages
  build_type=workflow. Dropped peaceiris + copy-to-branches + orphan branch.
- 2026-06-09 — Phase 3 (PR builds + preview) done via PR #1. Run 27236606733:
  build success, deploy skipped on PR, cv.pdf artifact attached. Added
  pull_request trigger, paths filter (YAML anchor), deploy gate, PDF artifact.
