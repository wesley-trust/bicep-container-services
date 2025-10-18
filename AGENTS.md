# Agent Handbook

## Mission Overview
- **Repository scope:** Bicep automation for Container Services. Contains the infrastructure templates, configuration, and tests executed through the shared pipeline stack (dispatcher -> pipeline-common).
- **Primary pipeline files:** `pipeline/containerservices.deploy.pipeline.yml` exposes Azure DevOps parameters; `pipeline/containerservices.settings.yml` links to the dispatcher and forwards configuration. The CI-focused `pipeline/containerservices.tests.pipeline.yml` runs the same suites without deployments.
- **Action groups:** `bicep_actions` deploys the resource group then the container services Bicep module. `bicep_tests_resource_group` and `bicep_tests_container_services` execute Pester suites via Azure CLI with `kind: pester`, so the shared templates publish `TestResults/<actionGroup>_<action>.xml` automatically. The release pipeline adds a `github_release` PowerShell action with `kind: release`; it calls `scripts/release_semver.ps1` to tag the repository and publish a GitHub release.
- **Dependencies:** The settings template references `wesley-trust/pipeline-dispatcher`, which locks `wesley-trust/pipeline-common`. Review those repos when diagnosing pipeline behaviour.

## Directory Map
- `pipeline/` – Pipeline definition + settings (deployment and CI variants). Edit these when introducing new parameters, toggles, or action groups.
- `platform/` – Bicep templates (`resourcegroup`, `containerservices`) and parameter files referenced by the pipeline actions.
- `vars/` – Layered YAML variables (`common`, `regions/*`, `environments/*`). Loaded by `pipeline-common` based on include flags supplied via configuration.
- `scripts/` – PowerShell helpers invoked from pipeline actions (Pester run/review, release automation, example hooks). Executed within the locked pipeline snapshot.
- `tests/` – Pester suites grouped into `unit`, `integration`, `smoke`, and `regression`. Shared design fixtures under `tests/design/` expose `tags`, `health`, and per-resource property sets consumed by the suites. Sample what-if payloads live in `tests/design/*/bicep.whatif.json` for review-stage context.

## Pipeline Execution Flow
1. `containerservices.deploy.pipeline.yml` defines runtime parameters (production enablement, DR toggle, environment skips, action/test switches) and extends the matching settings file.
2. `containerservices.settings.yml` declares the `PipelineDispatcher` repository resource and re-extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults with consumer overrides (including the optional `pipelineType` suffix) and forwards the resulting `configuration` into `pipeline-common/templates/main.yml`.
4. `pipeline-common` orchestrates initialise, validation, optional review, and deploy stages, loading variables and executing the action groups defined here. Refer to `pipeline-common/AGENTS.md` and `docs/CONFIGURE.md` for the full contract. When `pipelineType` is set (tests pipeline uses `auto`), Azure DevOps environments receive the same suffix so automated lanes can bypass manual approvals; the tests pipeline also sets `globalDependsOn: validation` to gate every action group on template validation.

## Customisation Points
- Adjust action wiring in `containerservices.deploy.pipeline.yml` to add new Bicep modules, split deployments, or change scripts. Respect the schema expected by `pipeline-common` (`type`, `scope`, `templatePath`, etc.).
- Override environment metadata (pools, regions, approvals) through the configuration object in the settings file (`environments`, `skipEnvironments`, additional repositories, key vault options).
- Manage variables by editing YAML files under `vars/` and toggling include flags via dispatcher configuration.
- Introduce review artefacts or notifications by composing additional action groups (e.g., PowerShell review tasks) in the pipeline definition or its CI variant.

## Testing & Validation
- `scripts/pester_run.ps1` installs required modules, authenticates with the federated token passed from Azure CLI, and executes Pester with NUnit output. It expects `-PathRoot`, `-Type`, and `-TestData.Name` so the runner can locate suites like `tests/<type>/<service>`. Ensure new tests live under `tests/` and are referenced by the action group.
- Smoke suites validate the `health` object emitted by each design file (for example, `provisioningState`) to give a quick readiness signal without broad property asserts. Expand the health payload when additional status checks are needed.
- Review stage relies on pipeline-common’s Bicep what-if output for approval context. `scripts/pester_review.ps1` ships for future opt-in review tasks but is not wired into the current pipeline definitions.
- CI action groups in `containerservices.tests.pipeline.yml` enable `variableOverridesEnabled` and pass `dynamicDeploymentVersionEnabled: true`. The helper template `PipelineCommon/templates/variables/include-overrides.yml` uses this to generate unique deployment versions per run, keeping parallel tests isolated.
- Bicep syntax/what-if validation runs through `pipeline-common` validation/review stages; run `az bicep build` locally for quick feedback before pushing.

## Operational Notes
- Document any behavioural change (new parameters, action groups, dependency updates) in `README.md` or inline comments so future agents understand the contract.
- When dispatcher defaults need adjustment (e.g., service connections, pool names), coordinate updates in the dispatcher repo to maintain compatibility.
- Use the preview tooling in `pipeline-common/tests` to validate changes against Azure DevOps definitions before merging.

## Further Reading
- `pipeline-common/AGENTS.md` – complete overview of pipeline stages, configuration schema, and preview tooling.
- `pipeline-common/docs/CONFIGURE.md` – exhaustive parameter reference.
- `pipeline-dispatcher/AGENTS.md` – default-merging logic between consumers and the shared templates.
