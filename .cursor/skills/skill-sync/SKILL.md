---
name: skill-sync
description: Sync skill metadata to AGENTS.md. Use after adding or modifying skills to keep the orchestrator updated.
---

# fichAR Skill Sync

## When to Use

- After creating a new skill
- After modifying skill name or description
- Periodically to ensure AGENTS.md reflects all skills

## Process

1. List all skills in `.cursor/skills/*/SKILL.md`
2. Extract `name` and `description` from frontmatter
3. Update the Skill Decision Table in AGENTS.md if needed
4. Ensure all skills are listed with correct trigger criteria
