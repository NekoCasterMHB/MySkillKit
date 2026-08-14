# MySkillKit — Personal AI Skill Kit (Sources-Only)

> Give this repo's URL to an AI, and it will auto-install your commonly used skills into any project.

This repo is a **sources-only** skill kit: it stores **no skill bodies** — only a `manifest.json` listing each skill and its upstream source. Installing pulls the **latest version directly from the source**, so installing from this repo can never give you a stale copy.

## Bundled skills (11)

| Skill | Purpose | Upstream |
|---|---|---|
| `design` | Full-stack design: logo / CIP / icons / banners / posters / slides | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) |
| `ui-styling` | shadcn/ui + Tailwind styling & accessibility | same |
| `ui-ux-pro-max` | UI/UX design intelligence (79 styles / 192 palettes / 74 font pairings) | same |
| `design-system` | Three-layer design tokens + component specs | same |
| `banner-design` | Multi-platform banner / ad creative design | same |
| `brand` | Brand voice, visual identity, messaging frameworks | same |
| `slides` | Chart.js strategic HTML presentations | same |
| `nuxt-ui` | Build UIs with @nuxt/ui v4 | [nuxt/ui](https://github.com/nuxt/ui) (official) |
| `supabase` | All Supabase products (DB/Auth/Edge/Storage…) | [supabase/agent-skills](https://github.com/supabase/agent-skills) (official) |
| `web-design-engineer` | Browser-rendered visual artifacts (pages/dashboards/prototypes) | [ConardLi/garden-skills](https://github.com/ConardLi/garden-skills) |
| `find-skills` | Discover & install more skills (skills.sh ecosystem) | [vercel-labs/skills](https://github.com/vercel-labs/skills) (official) |

## Two ways to use

### A. Ask an AI (recommended)

In a new project, tell your AI:

> Initialize this project with the common skills from https://github.com/NekoCasterMHB/MySkillKit

The AI clones this repo → reads the `AGENTS.md` install protocol + `manifest.json` → fetches the latest version of each skill from its source → validates → reports. Installs to the project's `.agents/skills/` (project-scoped) or `~/.agents/skills/` (user-global).

### B. One-command script

```bash
./install.sh                      # install all into current project (.agents/skills/)
./install.sh --global             # install all into ~/.agents/skills/
./install.sh design nuxt-ui       # install selected skills
./install.sh list                 # list skills in the manifest
./install.sh check                # check installed skills for updates
./install.sh update               # force re-fetch from sources (backs up first)

# Remote one-liner (new machine)
git clone --depth 1 https://github.com/NekoCasterMHB/MySkillKit.git /tmp/MySkillKit \
  && bash /tmp/MySkillKit/install.sh --global
```

## Why you can never install a stale version

- **No bodies in this repo** — there is no copy to go stale
- **Install = fetch from source** — `git` sources always pull the latest upstream commit
- **Update detection** — `./install.sh check` compares installed commits with upstream via `git ls-remote`
- **Version records** — installs write `.agents/.skillkit-installed.json` (skill → source → commit → time)
- **Backup before overwrite** — old versions go to `.agents/skills/.backup/<name>-<timestamp>/`

## Maintenance

```bash
# Add a skill from a git source
node scripts/update-manifest.mjs add <name> --source git --url <repo>.git --path <subdir> --ref main

# Add a local-only skill (owner's machine only)
node scripts/update-manifest.mjs add <name> --source local --path ~/.agents/skills/<name>

# Refresh latest commits & descriptions for all skills
node scripts/update-manifest.mjs refresh

# Validate the manifest
node scripts/validate.mjs
```

Source types: **`git`** (public upstream, installable everywhere, always latest — recommended) · **`local`** (points to `~/.agents/skills/` on this machine; publish to GitHub to make it portable) · **`embedded`** (fallback bodies in `vendor/` for skills with no public source).

## Notes

- Skill rules: directory name must equal the skill name; `description` ≤ 1024 chars or the skill won't load
- User-global `~/.agents/skills/` takes precedence over project `.agents/skills/` for same-name skills
- Restart your session after installing/updating — skills load at session start
