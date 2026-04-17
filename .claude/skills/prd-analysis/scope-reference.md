# PRD vs. System Design Scope Reference

PRD captures **product-level decisions**: what to build, for whom, why, and at what priority. It does NOT specify implementation-level details — those belong to system-design:

| Belongs in PRD | Belongs in System Design |
|----------------|------------------------|
| "Admin can manage users, Viewer can only read" (permission rules) | Permission middleware implementation, RBAC table schema |
| "User data must comply with GDPR" (compliance requirement) | PII field annotations, data retention cron design |
| "Support English and Chinese" (frontend i18n requirement) | i18n library config, translation lazy loading, fallback strategy |
| "API errors and emails in user's locale" (backend i18n requirement) | Accept-Language middleware, message catalog implementation, locale resolution chain |
| "Notify user when task fails" (notification requirement) | Notification queue architecture, delivery retry logic |
| Design token definitions (colors, typography, spacing, motion, breakpoints) | Token-to-code implementation (CSS custom properties, Tailwind config) |
| Component contracts (props, events, slots) | Component file structure, composition patterns |
| Interaction state machines (states, transitions, user feedback) | State store implementation, async patterns, caching |
| Navigation architecture (site map, routes, breadcrumbs) | Route guards, lazy loading, code splitting |
| Form specifications (fields, validation rules, i18n keys) | Form library config, validation execution, server integration |
| Accessibility requirements (WCAG level, ARIA, keyboard, focus management) | a11y testing tools (axe-core), implementation patterns |
| Responsive layout changes per breakpoint | CSS grid implementation, breakpoint utilities |
| Interactive prototypes (seed-quality code for validation) | Prototype-to-Production mapping, refactoring plan |
| Coding conventions — error propagation policy, logging level rules, global state prohibition, naming rules | Concrete patterns (specific error types, logger library config, DI container setup) |
| Test isolation policy — tests must use temporary resources, no shared mutable state, parallel-safe | Test helper implementations, fixture libraries, CI runner configuration |
| Development workflow requirements — prerequisite versions, CI gate policies, release versioning scheme | CI pipeline YAML, Makefile/Taskfile, release automation scripts |
| Security coding policy — input validation at boundaries, secret handling rules, dependency vulnerability scanning | WAF rules, secret manager integration, SAST tool config |
| Backward compatibility policy — API versioning rules, breaking change process, data migration strategy | Version negotiation middleware, migration script framework |
| Git & Branch Strategy — branch naming, merge strategy, protection rules, PR conventions, commit message format | Branch protection API config, git hooks, PR template files |
| Code review policy — review dimensions, approval requirements, automated vs human review split | Review bot config, CODEOWNERS file, CI reviewer assignment |
| Observability requirements (policy) — which events must be logged, health check requirements, SLO definitions, alerting rules | Log pipeline config, health check endpoint, Grafana dashboards, PagerDuty rules |
| Performance testing policy — regression detection thresholds, performance budgets, load testing requirements | Benchmark harness config, CI perf gate scripts, load test scenarios |
| AI agent configuration — instruction file strategy, structure policy (index vs monolithic), convention references, maintenance policy | Concrete instruction file content (CLAUDE.md body text), file scaffolding scripts |
| Deployment & environment policy — environments, local dev setup, environment parity, config management, data migration strategy, CD pipeline triggers/rollback, environment isolation, IaC requirements | Concrete deployment tooling (Dockerfile, docker-compose, Terraform, K8s manifests, CD workflow files, migration scripts) |
