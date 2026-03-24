# Happy API — Klack Test Fixture

A minimal PHP API that returns Chuck Norris jokes + cat images. Used as the standard test project for klack pipeline validation.

## What This Is

This is NOT a real project. It's a test fixture that klack copies into a temp directory, initializes as a git repo, and runs its full pipeline against. The goal is to have a reproducible, always-identical test scenario.

## The Task

`/api/happy/{id}` — returns a JSON response with a Chuck Norris joke and a cat image. Same ID always returns the same joke and image (deterministic mapping).

## How Klack Uses This

```bash
klack test              # copies fixture to /tmp, runs default ticket
klack test --conflict   # runs conflict scenario tickets
```
