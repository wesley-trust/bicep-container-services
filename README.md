# bicep-container-services

Infrastructure-as-code for the Wesley Trust container services platform. The repository packages Bicep templates, configuration, and automated tests that run through the shared pipeline stack (`pipeline-dispatcher` -> `pipeline-common`).

## Quick Links
- `AGENTS.md` – AI-facing handbook covering action groups, tests, and dependency repos.
- `pipeline/containerservices.pipeline.yml` – user-facing Azure DevOps pipeline definition.
- `pipeline/containerservices.settings.yml` – dispatcher handshake that forwards configuration.
- `pipeline-common/docs/CONFIGURE.md` – canonical description of the configuration schema consumed by shared templates.

## Repository Layout
- `platform/` – Bicep artefacts. `resourcegroup.bicep` bootstraps prerequisite RGs; `containerservices.bicep` delivers the workload. Matching `.bicepparam` files capture defaults.
- `pipeline/` – Pipeline definition (`*.pipeline.yml`) and dispatcher settings (`*.settings.yml`). Edit these to expose new toggles or action groups.
- `vars/` – YAML variable layers (`common.yml`, `regions/*.yml`) automatically imported by `pipeline-common` when include flags are enabled.
- `scripts/` – PowerShell helpers invoked from the pipeline (Pester runners plus sample pre/post hooks).
- `tests/` – Pester suites (`regression`, `smoke`, optional `unit`/`integration`) executed through the `bicep_tests` action group.

## Pipeline Overview
1. `containerservices.pipeline.yml` exposes runtime parameters (environment skips, review toggles, DR invocation, test controls) and extends the settings template.
2. `containerservices.settings.yml` declares repository resource `PipelineDispatcher` and extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults, declares `PipelineCommon`, and calls `templates/main.yml@PipelineCommon` with the composed `configuration` object.
4. Action groups:
   - `bicep_actions` – deploys the resource group and workload Bicep files, including optional cleanup and delete-on-unmanage switches.
   - `bicep_tests` – runs the regression and smoke Pester suites via Azure CLI. The group sets `kind: pester`, so `pipeline-common` publishes NUnit results from `TestResults/bicep_tests_<action>.xml` automatically after each run.

## Local Development
- Install PowerShell 7, Azure CLI (with Bicep CLI support), and the Az PowerShell module for parity with pipeline execution.
- Run `pwsh -File scripts/pester_run.ps1 -TestsPath tests/smoke -ResultsFile ./TestResults/local.smoke.xml` to exercise tests locally. Provide Azure credentials via `Connect-AzAccount` (service principal or interactive) before execution.
- Use `az bicep build platform/containerservices.bicep` for quick syntax validation during development.

## Configuration Tips
- Modify environment metadata (pools, regions, approvals) by extending the `configuration` object within `containerservices.settings.yml`.
- Additional repositories, key vault integration, or variable include behaviour are controlled through the same configuration payload; see `pipeline-common/docs/CONFIGURE.md` for available fields.
- Keep variable definitions under `vars/` small and environment-specific. Enable or disable layers via `configuration.variables.include*` flags.

## Releasing Changes
- Update `README.md` and `AGENTS.md` when introducing new parameters, action groups, or major behavioural tweaks.
- Coordinate dispatcher default changes with the `pipeline-dispatcher` repo to ensure consumers stay compatible.
- When breaking infrastructure changes are required, document migration guidance in pull requests and ensure regression tests cover the new path.

## Support
Raise questions in the platform DevOps channel or the repository issue tracker. Include the pipeline run ID, branch, and any custom configuration overrides when reporting deployment issues.
