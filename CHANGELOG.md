## [1.0.2](https://github.com/Hackbard/klack-agentic-coding/compare/v1.0.1...v1.0.2) (2026-03-26)


### Bug Fixes

* **cli:** start Hauptturm after init wizard, even without tickets ([f70f882](https://github.com/Hackbard/klack-agentic-coding/commit/f70f8820f7568532d2d1a9c4da34a814a2509f38))

## [1.0.1](https://github.com/Hackbard/klack-agentic-coding/compare/v1.0.0...v1.0.1) (2026-03-25)


### Bug Fixes

* **packaging:** remove rebase artifact from package.json ([669b113](https://github.com/Hackbard/klack-agentic-coding/commit/669b113223c1b0f6974ce8518faa280e3afd3822))
* **packaging:** rename to @webkult/klack (npm name collision with klaw) ([fc3f5ad](https://github.com/Hackbard/klack-agentic-coding/commit/fc3f5ad2f41fb6c50a05ff47cd02fc989af0717b))

# 1.0.0 (2026-03-25)


### Bug Fixes

* **ci:** add registry-url and NODE_AUTH_TOKEN for npm publish ([1c94da5](https://github.com/Hackbard/klack-agentic-coding/commit/1c94da5c2facdf5c994dd0eaf574c59a5fafa3b4))
* **ci:** upgrade Node to 22, fix shellcheck warnings ([0986a80](https://github.com/Hackbard/klack-agentic-coding/commit/0986a8023d4a85800555f814019dc6774512a7b6))
* **cli:** run composer install in test setup, lower PHPStan to level 5 ([52596e6](https://github.com/Hackbard/klack-agentic-coding/commit/52596e6135b851db7c691b5ebd44c65f0a8562c2))
* **hauptturm:** add ticket status cards back to layout ([7de5b7b](https://github.com/Hackbard/klack-agentic-coding/commit/7de5b7bdb45b9d2a2ce5d2523f99c3e241d21678))
* **hauptturm:** always focus Claude pane, default to worktree layout ([5f6db92](https://github.com/Hackbard/klack-agentic-coding/commit/5f6db9289a34b2512c518c24be5b9197edbf3c3d))
* **hauptturm:** eliminate flicker in sidebar and livelog panels ([b1e5f0b](https://github.com/Hackbard/klack-agentic-coding/commit/b1e5f0b070b01060f8ea7a85b94ec07ffdf7dca5))
* **hauptturm:** grid sizing — header 1 line, claude 7/12, sidebar 5/12 ([b6d530d](https://github.com/Hackbard/klack-agentic-coding/commit/b6d530ddf95b76f4c25e754f0d0001501e8ec90f))
* **hauptturm:** livelog uses full pane height for capture ([fcb0286](https://github.com/Hackbard/klack-agentic-coding/commit/fcb0286159aac9f23e5dec1acaafd58096d7a0df))
* **hauptturm:** worktree layout keeps status/log panes, adds sidebar ([1e4f731](https://github.com/Hackbard/klack-agentic-coding/commit/1e4f731031c64c55c2f2e633c716a1f40de36d62))
* **packaging:** correct repository URL to Hackbard/klack-agentic-coding ([119e489](https://github.com/Hackbard/klack-agentic-coding/commit/119e48949d9f995ed61e655a74fdff3db09b7199))


### Features

* add klack agentic coding framework ([c0214b8](https://github.com/Hackbard/klack-agentic-coding/commit/c0214b85f74d91c33da04c376850e14489e54e82))
* **cli:** add /klack skill for chat-based control commands ([afecb2d](https://github.com/Hackbard/klack-agentic-coding/commit/afecb2d29036d6fe2d5468425dd95379ada4e625))
* **cli:** add attention signals — terminal bell and macOS notifications ([7dce481](https://github.com/Hackbard/klack-agentic-coding/commit/7dce481bc3dec7c0124c9aec7edc18d8f5f3e434))
* **cli:** add smart initialization wizard and fix skill sync ([4b953f2](https://github.com/Hackbard/klack-agentic-coding/commit/4b953f2487cafde796a380a19685e7133ef79d88))
* **cli:** add test fixture and 'klack test' command ([2747417](https://github.com/Hackbard/klack-agentic-coding/commit/2747417bff728026ee00221a06368ead7e439af6))
* **docs:** add v2 redesign epics — smart init, worktree sidebar, workflow launcher ([7a5f9d4](https://github.com/Hackbard/klack-agentic-coding/commit/7a5f9d4f46ee132274dd032f9454a22c2050e5c5))
* **hauptturm:** add live log panel for active ticket ([a515019](https://github.com/Hackbard/klack-agentic-coding/commit/a51501924b934a0c129c97fa1c18a9ee21f0ec6a))
* **hauptturm:** add workflow launcher popup with phase-aware orchestration ([536d7fa](https://github.com/Hackbard/klack-agentic-coding/commit/536d7fa696595aa750f8dbcea35d3edf5ffef965))
* **hauptturm:** add worktree sidebar layout with BMAD status ([9f2ea5a](https://github.com/Hackbard/klack-agentic-coding/commit/9f2ea5a3310023601ae8991cf84cb0f45e01a7eb))
* **hauptturm:** live pane capture in livelog panel ([91cedf9](https://github.com/Hackbard/klack-agentic-coding/commit/91cedf935e4c9f251c27806eb7622a0f7bfd6b68))
* **hauptturm:** pipe agent output to log file for live panel ([30842d2](https://github.com/Hackbard/klack-agentic-coding/commit/30842d2b821db059c4a6233177cda9d55ec93071))
* **packaging:** add npm packaging, CI/CD pipeline, and semantic versioning ([c4f3dd6](https://github.com/Hackbard/klack-agentic-coding/commit/c4f3dd643d077fbb4249a179ed7fa87022fc2eda))
