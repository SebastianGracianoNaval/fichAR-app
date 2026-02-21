---
name: skill-creator
description: Create new AI agent skills following the Agent Skills standard. Use when adding a new project-specific skill.
---

# fichAR Skill Creator

## When to Use

- Adding a new skill for the fichAR project
- Extending the skill set

## Structure

Create in `.cursor/skills/<skill-name>/SKILL.md`:

```markdown
---
name: skill-name
description: Brief description. Use when [trigger scenarios].
---

# Skill Title

## When to Use
...

## Source of Truth
Reference definiciones/ or clean_definitions/

## Critical Patterns
...
```

## Rules

- **name**: lowercase, hyphens, max 64 chars
- **description**: Include WHAT and WHEN; third person
- **Reference** definiciones/ or clean_definitions/ where relevant
- **Concise**: &lt; 500 lines preferred

## After Creating

Run skill-sync to update AGENTS.md.
