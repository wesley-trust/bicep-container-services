# bicep-container-services

Infrastructure-as-code for Wesley Trust container services. The repository packages Bicep templates, configuration, and automated tests that run through the shared pipeline stack (`pipeline-dispatcher` -> `pipeline-common`).

## Quick Links
- `AGENTS.md` – AI-focused handbook covering action groups, tests, and dependency repos.
- `pipeline/containerservices.deploy.pipeline.yml` – Azure DevOps pipeline definition with runtime parameters.
- `pipeline/containerservices.tests.pipeline.yml` – CI/scheduled tests pipeline built on the same dispatcher handshake.
- `pipeline/containerservices.release.pipeline.yml` – semantic-release pipeline that tags the repo and publishes GitHub releases.
- `pipeline/containerservices.settings.yml` – dispatcher handshake that forwards configuration into `pipeline-common`.
- `pipeline-common/docs/CONFIGURE.md` – canonical schema reference for configuration payloads.

## Repository Layout
- `platform/` – Bicep artefacts. `resourcegroup.bicep` prepares prerequisite RGs; `containerservices.bicep` deploys the Azure Container Apps environment. Matching `.bicepparam` files capture tokenised defaults.
- `pipeline/` – Pipeline definition and dispatcher settings. Update these files when exposing new toggles, action groups, or test pipelines.
- `vars/` – YAML variable layers (`common.yml`, `regions/*.yml`, `environments/*`) that `pipeline-common` loads according to include flags.
- `scripts/` – PowerShell helpers invoked from pipeline action groups (Pester runner/review, release automation, plus sample pre/post hooks).
- `tests/` – Pester suites grouped into `unit`, `integration`, `smoke`, and `regression`. Design fixtures now live under `tests/design/resource_group/**` and `tests/design/container_services/**`, with per-region JSON describing expected resources, tags, and health.

## Pipeline Overview
1. `containerservices.deploy.pipeline.yml` introduces parameters for production enablement, DR invocation, environment skips, and action-group toggles before extending the settings template.
2. `containerservices.settings.yml` declares repository resource `PipelineDispatcher` and extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults, declares `PipelineCommon`, and calls `templates/main.yml@PipelineCommon` with the composed `configuration` object.
4. Action groups:
   - `bicep_actions` – deploys the resource group followed by the container services Bicep module, with optional cleanup and delete-on-unmanage switches.
   - `bicep_tests_resource_group` and `bicep_tests_container_services` – execute Pester suites through Azure CLI. Each action passes a scoped fixture via `-TestData` so the runner can resolve paths like `tests/<type>/<service>`, and both groups rely on `kind: pester`, which triggers `pipeline-common` to publish NUnit results to `TestResults/<actionGroup>_<action>.xml`.

The dedicated tests pipeline (`containerservices.tests.pipeline.yml`) passes `pipelineType: auto` and sets `globalDependsOn: validation`, ensuring CI and scheduled jobs wait for template validation. CI-facing action groups (`bicep_tests_*_ci`) enable `variableOverridesEnabled` with `dynamicDeploymentVersionEnabled: true`, allowing `templates/variables/include-overrides.yml` to append a unique suffix to `deploymentVersion` per run so parallel test executions stay isolated.

The release pipeline (`containerservices.release.pipeline.yml`) also runs with `pipelineType: auto`. It executes `scripts/release_semver.ps1` after every successful `main` build to derive the semantic version from the squash-merge commit message, create/push the tag, and surface release metadata. A PowerShell action with `kind: release` then wraps the shared GitHub release helper to publish the release entry using the exported variables.

## Test Fixtures and Health Checks
- Design files under `tests/design/container_services/**` expose a top-level `health` object (currently `provisioningState`) alongside resource properties. Smoke tests assert these health keys directly against live Container Apps environments to provide a fast readiness signal without expanding property skip matrices.
- Regression and integration suites consume the same design data, filtering properties as required while still validating tags and baseline metadata.
- Resource-group fixtures live under `tests/design/resource_group/**` and are passed into the runner the same way.
- Sample Azure CLI What-If payloads live in `tests/design/*/bicep.whatif.json` to illustrate expected review-stage output.

## Local Development
- Install PowerShell 7, Azure CLI (with Bicep CLI support), and the Az PowerShell module to mirror pipeline execution.
- Exercise tests locally using `pwsh -File scripts/pester_run.ps1 -PathRoot tests -Type smoke -TestData @{ Name = 'container_services' } -ResultsFile ./TestResults/local.smoke.xml`, authenticating with Azure beforehand. Swap `smoke` with `regression`, `unit`, or `integration` (and adjust `Name`) to target other suites.
- Run `az bicep build platform/containerservices.bicep` for syntax validation while authoring templates.

## Configuration Tips
- Tune environment metadata (pools, regions, approvals) by editing the configuration payload in `containerservices.settings.yml`.
- Manage variable layers under `vars/` and control their inclusion with `configuration.variables.include*` flags.
- Additional repositories, key vault integration, and advanced validation options follow the schema defined in `pipeline-common/docs/CONFIGURE.md`.

## Releasing Changes
- Document new parameters or action groups in both `README.md` and `AGENTS.md` to keep operators informed.
- Coordinate dispatcher default updates with the `pipeline-dispatcher` team to avoid schema drift.
- Cover breaking infrastructure changes with regression tests and clear migration notes in pull requests.

## Support
Use the platform DevOps channel or this repository’s issue tracker for support. Include pipeline run details, branch, and relevant configuration overrides when reporting problems.
