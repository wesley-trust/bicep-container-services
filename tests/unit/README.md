# Unit Test Harness

Unit test suites under this directory execute `az deployment what-if` against the Bicep templates and compare the resulting payload to a declarative design JSON. Each test file:

- Loads the co-located `design.json` file that defines deployment parameters and the expected resource shape.
- Runs the relevant `what-if` operation (subscription scope for the resource group example) with those parameters.
- Automatically generates Pester assertions for each resource and property specified in the design, failing if the what-if output diverges or contains unexpected resources.

## Prerequisites

- Azure CLI installed with access to the target subscription.
- Authentication already established (for CI this is handled by the pipeline's Az login).

## Adding Tests

1. Create or update the `design.json` alongside the Pester file, adding deployment parameters and expected resources.
2. Extend the `Unit.Tests.ps1` script (or create a new one) to reference the template to test. The helper functions in the resource group suite can be reused for additional resource types.
3. Keep the design authoritative: add any new resources or properties so integrity checks remain meaningful.
