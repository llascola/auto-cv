# autoCV

A clean LaTeX CV template with a GitHub Actions pipeline that compiles `cv.tex`
and publishes the PDF to GitHub Pages on every push to `main`.

> **Fork note.** This is a fork maintained by **Luciano Scola**
> ([@llascola](https://github.com/llascola)), based on the original
> [autoCV](https://github.com/jitinnair1/autoCV) by **Jitin Nair**. The CV
> content is personal; the CI pipeline has been substantially rebuilt (see
> [What's different in this fork](#whats-different-in-this-fork)).

## Template Design

The template is designed to be clean with sections for
- Tabular sections for Work Experience, Education and Projects
- Support for including a list of publications read from a `*.bib` file
- Header with Font Awesome icons

## What's different in this fork

The original published via an orphan `build` branch using third-party actions.
This fork replaces that with a faster, reproducible, official pipeline
(`.github/workflows/build.yml`):

- **Build engine: [Tectonic](https://tectonic-typesetting.github.io/)** instead
  of a full TeXLive action. A single static binary that fetches and caches only
  the packages the document needs — reproducible and fast. Pinned to `0.14.1`
  on `ubuntu-22.04` (a known-good combination).
- **Native GitHub Pages deploy** via `actions/upload-pages-artifact` +
  `actions/deploy-pages`. No orphan `build` branch, no unmaintained third-party
  deploy actions. Least-privilege token + a deploy concurrency group.
- **Pull-request previews.** PRs compile the CV and attach `cv.pdf` as a
  downloadable artifact, so layout changes can be reviewed before merging. PRs
  never deploy; only pushes to `main` publish.
- **Bilingual spell-check gate.** The CV mixes Spanish prose with English tech
  terms, so a word is accepted if **either** the Spanish **or** the English
  dictionary knows it; only words unknown to *both* are flagged
  (`scripts/spellcheck.sh`, with an allow-list in `.github/spell-allow.txt`).
  `chktex` runs alongside as an informational LaTeX linter. A real typo blocks
  the deploy.
- **Path-filtered triggers** so unrelated commits don't spend CI minutes.

## Quickstart

- Generate your copy of the repo using the **Use this template** button.
- In **Settings → Pages**, set the source to **GitHub Actions**.
- Edit `cv.tex` and push to `main` (or open a PR to preview first).
- The Actions run compiles the CV and deploys it to Pages automatically.

Once published, your CV is served at `https://<username>.github.io/<repo-name>/`
(the included `index.html` redirects to `cv.pdf`). This is a stable direct link
you can use on your website, LinkedIn, etc., always pointing at the latest build.

## Compiling the CV on your local computer

- Install [Tectonic](https://tectonic-typesetting.github.io/) and run `make` in
  the project directory to produce `cv.pdf` (this matches what CI does).
- `make latexmk` is kept as a fallback for a traditional TeXLive + `latexmk`
  setup.
- `make clean` / `make distclean` remove intermediate files.

To run the spell-check locally you also need `aspell` with the English and
Spanish dictionaries, then: `bash scripts/spellcheck.sh cv.tex`.

## This template on Overleaf

<a href="https://www.overleaf.com/latex/templates/autocv/scfvqfpxncwb"><img alt="Overleaf" src="https://img.shields.io/badge/Overleaf-47A141.svg?style=for-the-badge&logo=Overleaf&logoColor=white"/></a>

If you have a premium Overleaf subscription, you can use Overleaf's GitHub
integration to push changes to your GitHub repo directly from Overleaf.

## License

Released under the **MIT License**.

Original work Copyright (c) 2021 **Jitin Nair**
([autoCV](https://github.com/jitinnair1/autoCV)). Fork modifications Copyright
(c) 2026 **Luciano Scola**. The full MIT license text is included in the header
of `cv.tex`.

## Credits

- Original template: [Jitin Nair — autoCV](https://github.com/jitinnair1/autoCV)
  ([detailed wiki](https://github.com/jitinnair1/autoCV/wiki/How-to-use-autoCV:-Detailed-Instructions)).
- Fork and CI rework: [Luciano Scola](https://github.com/llascola).
