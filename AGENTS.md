# Agent Handbook

## Mission Overview
- **Repository scope:** Bicep automation for Container Services. Provides the deployment artefacts (Bicep, variables, tests) that run through `pipeline-common` via the dispatcher.
- **Primary pipeline files:** `pipeline/containerservices.pipeline.yml` (user-facing pipeline definition) and `pipeline/containerservices.settings.yml` (dispatcher handshake).
- **What runs:** `bicep_actions` deploys the resource group and Container Services templates; `bicep_tests_resource_group` and `bicep_tests_container_services` execute their Pester regression/smoke suites through Azure CLI with `kind: pester`, so the shared templates publish `TestResults/<actionGroup>_<action>.xml` automatically.
- **Dependencies:** The settings template references `wesley-trust/pipeline-dispatcher` -> which in turn locks `wesley-trust/pipeline-common`. Review those repos when behaviour changes.

## Directory Map
- `pipeline/` – Azure DevOps pipeline + settings pair. Update parameters here when exposing new toggles or action groups.
- `platform/` – Bicep templates and parameter files (`resourcegroup` bootstrap + `containerservices`). Keep names matched with the paths wired in the pipeline action definitions.
- `vars/` – YAML variable layers (`common`, `regions/*`). Loaded by `pipeline-common` according to include flags/defaults.
- `scripts/` – PowerShell helpers invoked from action groups (Pester runner, review metadata, sample pre/post hooks). Execution happens inside the pipeline snapshot.
- `tests/` – Pester suites split by concern (`smoke`, `regression`, etc.). Align folder names with action definitions and keep shared data in `tests/design/` for cross-suite reuse.
- `AGENTS.md` – this handbook. Update alongside structural changes.

## Pipeline Flow
1. `containerservices.pipeline.yml` surfaces pipeline parameters (enable production, skip environments, action toggles, test delay). It extends `containerservices.settings.yml`.
2. The settings template declares repository resource `PipelineDispatcher` (main branch by default) and re-extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. Dispatcher merges defaults (including optional fields such as `pipelineType` when you need an environment suffix) and forwards the composed `configuration` into `pipeline-common/templates/main.yml`.
4. `pipeline-common` ensures initialise/validation/review/deploy stages run with the supplied `actionGroups` and environment map. Token replacement and snapshot behaviour come from that repo – see its `AGENTS.md` + `docs/CONFIGURE.md` for details. When `pipelineType` is set, Azure DevOps environment names inherit the suffix so automated lanes can bypass manual approvals.

## Customising Deployments
- Add/edit actions by updating the arrays in `containerservices.pipeline.yml`. Keep the `type`, `scriptTask`, and paths aligned with `pipeline-common` expectations.
- To change default environments (regions, pools, approvals) adjust overrides in `containerservices.settings.yml` or add entries in the commented `environments` example.
- Variables: add files under `vars/` and toggle include flags through dispatcher configuration (`configuration.variables.include*`).
- Additional repositories or key vault usage should be defined through the `configuration` object in the settings file.

## Testing & Validation
- Pester execution is controlled by the `bicep_tests_resource_group` and `bicep_tests_container_services` action groups. `scripts/pester_run.ps1` handles module installation and Az login using Azure CLI-provided tokens, and accepts optional `-TestData` input when you need to supply fixtures manually. Both action groups set `kind: pester`, so `pipeline-common` publishes results to `TestResults/<actionGroup>_<action>.xml` unless overridden.
- Review stage relies on pipeline-common’s Bicep what-if output. `scripts/pester_review.ps1` is available for future review tasks if we decide to add dedicated PowerShell review actions.
- When updating Bicep, run `az bicep build` locally or rely on the validation stage from `pipeline-common` to catch template issues.

## When Behaviour Changes
- Record any new parameters or behaviour in `README.md` and component folders (e.g., inline comments near action definitions).
- If dispatcher defaults need an update (pool/service connection, validation flags), coordinate the change in the dispatcher repo so the contract stays consistent.
- For breaking Bicep changes, produce migration notes in pull requests and ensure regression tests cover the new surface.

## Further Reading
- `pipeline-common/AGENTS.md` – complete overview of pipeline stages, configuration schema, and preview tooling.
- `pipeline-common/docs/CONFIGURE.md` – exhaustive parameter reference.
- `pipeline-dispatcher/AGENTS.md` – default-merging logic between consumers and the shared templates.
