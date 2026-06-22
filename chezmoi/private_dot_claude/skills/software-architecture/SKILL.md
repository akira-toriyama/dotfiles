---
name: software-architecture
description: Use when designing or structuring the architecture of a macOS app (Swift/AppKit/SwiftUI) — Clean Architecture, DDD, ports & adapters, layering, dependency rule, domain events, concurrency-as-design. Distilled house methodology (macOS apps only).
---

# macOS app architecture — house methodology

A reusable methodology for structuring a native macOS app (Swift/AppKit or SwiftUI) as a pure-logic core driving multiple UI surfaces over swappable OS backends. Distilled from a production window-manager codebase; type names generalized, principles preserved. **Scope = macOS apps** (not generic cross-language).

## Layering & dependency rule

Split the app into three layers so the *same pure core drives multiple UI surfaces* and the *same UI runs against multiple backends*:

- **Core** — pure logic only: domain state, rules, engines, the **port protocols**, and event types. Value-level OS primitives (geometry types like `CGRect`) are fine; **no UI framework, no backend, no OS interaction**.
- **Adapter** — wraps exactly one OS/framework backend and is the **only** place backend-specific types may appear. Multiple adapters allowed; backend types never escape their module.
- **View** — GUI-only, kept thin, no business logic. Talks to the **port protocol**, never to a concrete adapter.

The dependency rule (Clean Architecture / Hexagonal): **source-code dependencies always point inward** at Core's protocols. Adapters and views depend on Core; Core depends on nothing outward.

- **"Crossing a layer always means a missing protocol."** The test: if a type needs to reach across a boundary, introduce a port — do not leak the type.
- **Convert to backend-neutral model types at the seam.** Views and the controller must never see adapter-internal types.

### Why three layers, not two

The value is realized at three distinct moments — if none is plausible you may not need the third layer; if any is, keep it:

1. **Test surface** — Core is exercised fully without the UI framework; adapters get contract tests fed canned event streams; views stay thin.
2. **Backend swap** — a new adapter starts as a stub and grows in phases without breaking any view; retiring the old one is a one-module swap *because views only know the port*.
3. **Multiple views over one state** — each view is a facet of the same model; new views plug in without touching Core or Adapter.

## Ports & Adapters

A **port** is a protocol in Core expressing one *axis* of external capability (e.g. a backend port = state queries + mutating commands + an event stream; a separate capture/secondary-resource port).

- **Keep a port even with one implementation.** A single production adapter still earns the seam: it is the **test seam** that lets you substitute a stub/fake feeding canned data so the pure core is testable in isolation.
- **Split ports along backend axes, not arbitrarily.** A capability deserves its own port + module when it differs by *backend axis* — a different OS framework, a different permission/entitlement, or optional/version-gated availability. Same axis → same adapter.
- **Keep ports framework-neutral.** Return/accept the *most neutral* representation that still carries the data (a neutral image type, not a UI-framework image); push UI-framework wrapping into the view so the view module imports no OS backend.
- **Treat any changeable external contract as a port.** Input grammar (CLI/args), wire format, on-disk snapshots: put a *pure translator* in Core mapping raw external input → stable internal representations, and keep the impure shell (exit codes, stderr, I/O) in an outer client. "The parser is to the grammar what the backend port is to the backend: a seam that keeps the hexagon's interior stable while the outside world changes." Payloads stay byte-identical across a syntax migration.

## DDD building blocks

The patterns apply even when the code never names them. Keep a short **mapping table** (Clean-Arch / DDD ↔ your modules) so the two vocabularies don't drift and intent survives a cold reopen.

- **Entity** — mutable domain object with identity.
- **Value Object** — immutable identity/style/geometry values.
- **Aggregate Root** — the entity that *owns* its children (a container owning its members); mutate children through the root.
- **Repository** — the port protocols.
- **Domain Service** — stateless operations belonging to no single entity (reconciliation, geometry queries, focus assertion, scaling).
- **Domain Event** — a backend event type *consumed via an async stream* (see Domain events).
- **Bounded Context** — one binary = one context; no inter-context translation needed.
- **Ubiquitous language** — govern terms with a glossary; a rename lands in the *same change* as the code.

## What to defer (YAGNI) & why

Layers that orthodox Clean Architecture / MVVM prescribe can be consciously skipped — **but record the exact structural trigger that flips the decision, and don't relitigate until it fires.**

- **No separate Use Case / Interactor layer** while use-case shapes are 1-line wrappers around backend calls (plus retry) — a layer would be 100% boilerplate. Collapse them into the Controller. **Trigger to extract:** a new view lands **and** the same operation appears in ≥2 view code paths.
- **No ViewModels** in AppKit: a well-shaped **view ↔ controller callback protocol** — immutable snapshot down, intent callbacks up — already does the ViewModel's job without the boilerplate. **Trigger:** a view must be reused across multiple windows/hosts. (SwiftUI's calculus differs, but the trigger-based reasoning still applies.)
- **General pattern:** defer a layer when its current instances would be pure boilerplate; name the precise trigger (usually "same logic now in ≥2 places"); freeze the decision ("do not relitigate without an explicit review round").

## Seams & testability

- **Decide layer placement partly by testability.** A pure-math / pure-data helper belongs in Core *even if its only caller is in an adapter* — the move converts an untestable OS-coupled unit into a fully covered pure one.
- **Ports are the substitution seam** — conform a stub to the port and swap it for the real adapter to drive the core with canned data.
- **Ship a pure value type together with its first consumer in one change** — no orphan-consumer split — so every merge is independently testable and meaningful.
- **Test against behavior, not internal structure** — use result / render-idempotence equality, not source-position-sensitive comparisons (e.g. AST equality) that break on cosmetic changes.

## Domain events

Model OS notifications as **domain events crossing the adapter→core seam**:

- The backend port exposes an **event stream** (an async stream of a neutral domain-event type) — the DDD Domain Event, consumed reactively rather than via raw callbacks.
- **Flow:** the adapter observes the OS (accessibility / window-system notifications, workspace launch/terminate, …), translates those noisy framework-specific signals into clean neutral events, and emits them on the stream; the Controller consumes them and reconciles Core state. The core/controller never sees the raw OS notification.
- **Isolate the observer lifecycle** behind a small reusable contract (a consistent `init(onChange:)` / `start()` / `stop()` shape) so each observer type plugs in uniformly.

## Concurrency as an architectural concern

Threading is a first-class design dimension, not an afterthought:

- **One serialization authority per mutable subsystem.** Confine all mutable adapter state to a single serial queue; route *every* mutate **and read** through it (reads tear against writers too). This is what makes an `@unchecked Sendable` adapter sound — enforce confinement at runtime with a precondition on every state entry point.
- **Keep cross-actor edges acyclic.** Make `main → workQueue` *always async*; allow `workQueue → main` *sync* only for framework-pinned reads that must run on main (e.g. screen geometry). Since main never blocks on the work queue the edges form no cycle — a `main → workQueue` sync anywhere would close the cycle and deadlock.
- **Cross domains by passing immutable value snapshots, never shared mutable state.** Commit state on the work queue, then hand a *value plan* (elements + frames) to the main-confined driver in a single hop; the two clocks never share state.
- **Make the non-`Sendable` UI boundary explicit.** Keep preset/style data as pure `Sendable` values (e.g. hex `UInt32`); constrain only the *resolved* side that produces non-`Sendable` framework objects (e.g. colors) to `@MainActor`. Don't resolve framework objects off the main actor.

## Alternative projections stay pure

When adding a second, orthogonal way to *project* the same domain state (a different grouping/lens over the same entities), hold the line:

- **Put the whole projection + mutation-planning surface in pure Core** — a `project(...)` function and a `resolve(...) → Plan` function — so it is exhaustively unit-tested and views stay rendering-only.
- **Keep config-vs-result as distinct types** — the *declared* config (what the user asked for) vs. the *computed* renderable (what we rendered). Don't conflate them.
- **Make the new mode degrade exactly** — collapse byte-identical to the old default when unconfigured, gated behind an explicit `isActive` predicate.
- **Route mutations through a pure resolver** that turns an intent into an executable `Plan`, validates the core invariant, and returns an **inert plan** (no-op / snap-back) when the invariant can't hold; the impure controller dispatches only non-inert plans.
- **Compute once, render N times** — all views consume one ordered, already-computed list, so multi-view highlight/selection logic is identical across surfaces.

## Scope discipline: non-goals as architecture

Architecture is also what you refuse to build:

- **Name and defend a hard capability boundary up front** (sandbox, entitlements, SIP-on, public-API-only, no injection). Make "would this feature force us across the boundary?" a gating question — features that cross it become a separate fork, not a bolt-on. This keeps the core small and the trust model intact.
- **Compose with external tools rather than absorb their concerns** (shortcuts, rules engines, persistence delegated outward).
- **No persistence of runtime state unless explicitly designed in** — config is a read-only template; runtime overrides are session-only.

## Cross-cutting conventions that protect the architecture

- **Diagnostics respect the dependency rule** — put the logging utility in Core so every layer can call it without crossing layer boundaries.
- **Symmetric, pattern-based surfaces** — adding a UI surface should need only one new entry + matching dispatch case; don't reintroduce bespoke per-view flags. The "add a view without touching Core/Adapter" promise should be mirrored in the CLI.
- **A single normalization seam** — clamp/normalize unknown or out-of-range inputs to defaults rather than rejecting, behind `effective*` accessors that are the *only* sanctioned read path. Never read raw optional fields directly.
- **Keep rationale in-repo** — a mapping table, a glossary, and a references list (ordered broad→narrow, language-neutral→language-specific) so intent and ubiquitous language survive a contributor reopening the repo cold.

## Condensed checklist

1. Three layers — Core (pure) / Adapter (one backend axis each) / View (GUI-only). Crossing a layer ⇒ a missing port.
2. Everything points inward at Core's protocols; backend types never leave their adapter; convert at the seam.
3. Keep a port even with one impl — it's the test seam.
4. Split ports by backend axis; keep them framework-neutral (wrap in the view).
5. Treat changeable external contracts (grammar, wire format, snapshots) as ports with a pure translator.
6. Defer use-case and view-model layers via YAGNI; record the exact trigger; freeze until it fires.
7. Place code by testability; ship a value type with its first consumer.
8. Model OS notifications as a neutral domain-event stream crossing adapter→core.
9. One serialization authority per mutable subsystem, all access through it, runtime-enforced, acyclic cross-actor edges; cross domains by value snapshots.
10. Alternative projections stay pure (`project`, `resolve→Plan`), degrade exactly, gate behind a predicate; views render the computed result only.
11. Name and defend a hard capability boundary; out-of-bounds features are forks, not options.
12. Keep a Clean-Arch/DDD mapping table + glossary so intent and language survive a cold reopen.

## Canonical references

- *Hexagonal Architecture (Ports & Adapters)* — Alistair Cockburn
- *Clean Architecture* — Robert C. Martin
- *Domain-Driven Design* — Eric Evans
- *Implementing Domain-Driven Design* — Vaughn Vernon
