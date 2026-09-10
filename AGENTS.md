# KalaVistar — Agent Rules
## Product

Official product name: **KalaVistar**

Never introduce "ShilpSetu" as new user-facing branding.

Existing technical identifiers containing ShilpSetu may remain when changing
them could break working infrastructure.

KalaVistar is a Smart India Hackathon 2026 prototype focused on an
AI-enabled marketplace for artisans.

---

## Product model

KalaVistar is primarily an artisan-focused commerce marketplace.

Think:

"Amazon for artisan niches"

There are two experiences inside ONE Flutter application:

1. Artisan / Seller
2. Buyer

The user selects the role during onboarding/account creation.

Do NOT split these into separate apps.

---

## Buyer philosophy

The Buyer application experience should primarily behave like a polished
commerce marketplace.

Primary concepts include:

- discovery
- categories
- search
- product feeds
- artisan storefronts
- product detail pages
- recommendations
- RFQs
- supplier discovery
- orders
- rich media
- trust/provenance
- clusters where useful

AI should enhance this experience but should NOT dominate every screen.

The AI assistant should be a secondary/supporting feature rather than the
main product interface.

---

## Artisan philosophy

The Artisan side must prioritize simplicity.

Core journey:

Photo
→ voice/details
→ AI-assisted listing
→ price
→ review
→ publish

The experience should be accessible and usable by people with relatively
low digital literacy.

Avoid unnecessary forms and complexity.

---

## Engineering philosophy

THIS IS A WORKING STUDENT HACKATHON PROTOTYPE.

Optimize for:

1. working demo
2. visible impact
3. beautiful UX
4. reliability
5. development speed
6. understandable judge-facing functionality

Do NOT optimize for enterprise-scale production architecture.

---

## Preserve working architecture

The repository currently works.

Do NOT perform major migrations, rewrites, framework replacements, database
redesigns, authentication architecture rewrites, or large infrastructure
changes unless explicitly instructed.

Prefer:

- incremental improvements
- additive changes
- localized refactors
- low-risk fixes
- backward-compatible API changes

over rewrites.

---

## High-cost backend work

Do NOT independently implement things such as:

- complete production authorization infrastructure
- payment gateways
- enterprise security systems
- major Firestore schema migrations
- microservices
- Kubernetes
- new backend frameworks
- large-scale event systems

unless explicitly requested.

If an existing issue directly breaks the demo or an important user journey,
fix it with the smallest reliable solution.

---

## Branding

User-facing product name:

KalaVistar

Change visible legacy ShilpSetu branding when encountered.

However DO NOT automatically rename:

- Firebase project IDs
- Firebase app IDs
- package identifiers
- Firestore collections
- environment variable names
- repository remote
- internal technical identifiers

if doing so creates migration or breakage risk.

---

## AI features

AI is a major differentiator but it must support commerce rather than replace
the marketplace.

Examples:

- voice-to-catalog
- photo enhancement
- listing generation
- multilingual assistance
- pricing assistance
- product discovery
- supplier matching
- RFQ parsing
- business assistant

---

## Voice-to-Catalog

Treat this as an important workflow.

Improvements should prioritize:

- clearer recording UX
- language awareness
- retry/redo
- transcript review
- transcript correction
- useful processing feedback
- manual fallback
- clear failure states
- editable generated listing
- minimal artisan effort

Do not silently turn failed recordings into unrelated successful listings in
the main user flow.

---

## UI work

Preserve functional behavior unless the task explicitly changes it.

When redesigning:

- reuse a coherent design system
- prioritize responsive mobile UI
- preserve navigation
- preserve API contracts
- maintain loading/error/empty states
- avoid giant rewrites

---

## Testing

Agents should perform source-level validation, automated tests, analysis and
build checks where practical.

Do not depend on physical-device testing as an acceptance criterion.

Physical-device testing will be handled separately by the project owner.

---

## Git safety

Before editing:

git status --short

Do not overwrite unrelated existing work.

Do not reset, clean, rebase or delete work unless explicitly instructed.

Make scoped commits when requested.

Never push unless explicitly instructed.

---

## Agent behavior

Before implementing a task:

1. inspect relevant existing files
2. understand existing architecture
3. reuse existing services/components when possible
4. make the smallest coherent change
5. test it
6. report files changed
7. report remaining limitations

Do not rebuild functionality that already exists.
