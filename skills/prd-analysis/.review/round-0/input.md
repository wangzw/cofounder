# User Prompt

I want a skill called prd-analysis that turns sparse product ideas (or brainstorm notes, or external doc references like @notes.md) into a structured Product Requirements Document. The artifact is a markdown directory at docs/raw/prd/YYYY-MM-DD-<product-slug>/ containing a README.md index, journey specs (journeys/J-NNN-<slug>.md), feature specs (features/F-NNN-<slug>.md, each self-contained with inline data models and conventions), and an architecture topic index with topic files under architecture/. Coding agents should be able to read a single feature file and implement it end-to-end without opening other files. Supports interactive mode (ask the user questions), document mode (parse @notes.md), review mode (--review), revise mode (--revise), and evolve mode (--evolve baseline) to produce incremental versions with only changed files + tombstones.

# Expanded References

## @notes.md

(file not found: notes.md)

## @notes.md

(file not found: notes.md)
