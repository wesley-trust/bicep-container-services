$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
  param(
    [Parameter(Mandatory)][string]$StartPath
  )

  $current = Resolve-Path -Path $StartPath
  while ($null -ne $current) {
    $maybeRoot = Join-Path -Path $current -ChildPath '.git'
    if (Test-Path -Path $maybeRoot) {
      return (Resolve-Path -Path $current)
    }

    $parent = Split-Path -Path $current -Parent
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
      break
    }
    $current = $parent
  }

  throw "Unable to locate repository root starting from $StartPath"
}

function ConvertTo-ParameterFileContent {
  param(
    [Parameter(Mandatory)]$Parameters
  )

  $parameterContent = [ordered]@{}
  $parameterNames = Get-ObjectPropertyNames -InputObject $Parameters
  foreach ($name in $parameterNames) {
    $parameterContent[$name] = @{ value = (Get-ObjectPropertyValue -InputObject $Parameters -Name $name) }
  }

  return $parameterContent | ConvertTo-Json -Depth 20
}

function Get-ObjectPropertyNames {
  param(
    [Parameter(Mandatory)]$InputObject
  )

  switch ($InputObject) {
    { $_ -is [System.Collections.IDictionary] } { return $_.Keys }
    { $_ -is [System.Management.Automation.PSCustomObject] } { return $_.PSObject.Properties.Name }
    default { return @() }
  }
}

function Get-ObjectPropertyValue {
  param(
    [Parameter(Mandatory)]$InputObject,
    [Parameter(Mandatory)][string]$Name
  )

  switch ($InputObject) {
    { $_ -is [System.Collections.IDictionary] } { return $_[$Name] }
    { $_ -is [System.Management.Automation.PSCustomObject] } { return $_.PSObject.Properties[$Name].Value }
    default { return $null }
  }
}

function Assert-Subset {
  param(
    $Actual,
    $Expected,
    [string]$Path = ''
  )

  if ($null -eq $Expected) {
    $Actual | Should -Be $null -Because "Expected null at '$Path'"
    return
  }

  if ($Expected -is [string] -or $Expected -is [System.ValueType]) {
    $Actual | Should -Be $Expected -Because "Expected value at '$Path'"
    return
  }

  if ($Expected -is [System.Collections.IDictionary] -or $Expected -is [System.Management.Automation.PSCustomObject]) {
    $propertyNames = Get-ObjectPropertyNames -InputObject $Expected
    foreach ($propertyName in $propertyNames) {
      $expectedValue = Get-ObjectPropertyValue -InputObject $Expected -Name $propertyName
      $actualValue = Get-ObjectPropertyValue -InputObject $Actual -Name $propertyName
      $nextPath = if ([string]::IsNullOrEmpty($Path)) { $propertyName } else { "$Path.$propertyName" }

      ($null -ne $actualValue) | Should -BeTrue -Because "Missing property '$nextPath' in what-if output"
      Assert-Subset -Actual $actualValue -Expected $expectedValue -Path $nextPath
    }
    return
  }

  if ($Expected -is [System.Collections.IEnumerable] -and -not ($Expected -is [string])) {
    $expectedList = @($Expected)
    $actualList = @($Actual)

    $actualList.Count | Should -Be $expectedList.Count -Because "Array length mismatch at '$Path'"

    for ($i = 0; $i -lt $expectedList.Count; $i++) {
      $elementPath = "$Path[$i]"
      Assert-Subset -Actual $actualList[$i] -Expected $expectedList[$i] -Path $elementPath
    }
    return
  }

  $actualJson = ConvertTo-Json -InputObject $Actual -Depth 20 -Compress
  $expectedJson = ConvertTo-Json -InputObject $Expected -Depth 20 -Compress
  $actualJson | Should -Be $expectedJson -Because "Expected JSON to match at '$Path'"
}

function Invoke-SubscriptionWhatIf {
  param(
    [Parameter(Mandatory)][string]$TemplatePath,
    [Parameter(Mandatory)]$Design
  )

  $deploymentDefinition = $Design.deployment
  if ($null -eq $deploymentDefinition) {
    throw 'Design file must include a "deployment" section.'
  }

  $deploymentScope = $deploymentDefinition.scope
  if ($deploymentScope -ne 'subscription') {
    throw "Unsupported deployment scope '$deploymentScope'. Only 'subscription' is supported for this test."
  }

  $deploymentLocation = $deploymentDefinition.location
  if ([string]::IsNullOrWhiteSpace($deploymentLocation)) {
    throw 'Deployment location is required in the design file.'
  }

  $parameterJson = ConvertTo-ParameterFileContent -Parameters $deploymentDefinition.parameters
  $parameterFile = New-TemporaryFile

  try {
    Set-Content -Path $parameterFile -Value $parameterJson -Encoding Ascii

    $deploymentName = if ($deploymentDefinition.name) {
      $deploymentDefinition.name
    }
    elseif ($env:BUILD_BUILDID) {
      "rg-unit-$($env:BUILD_BUILDID)"
    }
    else {
      "rg-unit-{0}" -f ([guid]::NewGuid().ToString('N').Substring(0, 8))
    }

    $azArguments = @(
      'deployment', 'sub', 'what-if',
      '--name', $deploymentName,
      '--location', $deploymentLocation,
      '--template-file', $TemplatePath,
      '--parameters', "@$parameterFile",
      '--result-format', 'FullResourcePayloads',
      '--only-show-errors',
      '--output', 'json'
    )

    $whatIfOutput = & az @azArguments
    if ($LASTEXITCODE -ne 0) {
      $message = ($whatIfOutput | Out-String)
      throw "Azure CLI what-if failed with exit code $LASTEXITCODE. Output: $message"
    }

    $whatIfJson = $whatIfOutput | Out-String
    if ([string]::IsNullOrWhiteSpace($whatIfJson)) {
      throw 'Azure CLI what-if returned no data.'
    }

    return $whatIfJson | ConvertFrom-Json -Depth 50
  }
  finally {
    Remove-Item -Path $parameterFile -ErrorAction SilentlyContinue
  }
}

function Get-ChangeForResource {
  param(
    [Parameter(Mandatory)]$WhatIfResult,
    [Parameter(Mandatory)]$ResourceSpec
  )

  $changes = $WhatIfResult.properties.changes
  if (-not $changes) {
    return $null
  }

  $resourceType = $ResourceSpec.resourceType
  $resourceName = $ResourceSpec.resourceName

  return $changes |
  Where-Object { $_.resourceType -eq $resourceType -and $_.resourceName -eq $resourceName } |
  Select-Object -First 1
}

$testRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$designPath = Join-Path -Path $testRoot -ChildPath 'design.json'
if (-not (Test-Path -Path $designPath)) {
  throw "Design JSON not found at $designPath"
}

$designData = Get-Content -Path $designPath -Raw | ConvertFrom-Json -Depth 50
if (-not $designData.resources) {
  throw 'Design file must include a non-empty resources array.'
}
$repositoryRoot = (Get-RepositoryRoot -StartPath $testRoot).Path
$templatePath = Join-Path -Path $repositoryRoot -ChildPath 'platform/resourcegroup.bicep'

Describe 'Resource group what-if alignment' {
  BeforeAll {
    $script:WhatIfResult = Invoke-SubscriptionWhatIf -TemplatePath $templatePath -Design $designData
    $script:DesignResourceKeys = @{}

    foreach ($resource in $designData.resources) {
      $key = "{0}|{1}" -f $resource.resourceType, $resource.resourceName
      $script:DesignResourceKeys[$key] = $true
    }
  }

  It 'should produce what-if results' {
    $script:WhatIfResult | Should -Not -BeNullOrEmpty
    $script:WhatIfResult.properties | Should -Not -BeNullOrEmpty
  }

  $allowUnexpected = $false
  if ($designData.PSObject.Properties.Name -contains 'allowUnexpectedChanges') {
    $allowUnexpected = [bool]$designData.allowUnexpectedChanges
  }

  if (-not $allowUnexpected) {
    It 'should not contain unexpected resource changes' {
      $changes = $script:WhatIfResult.properties.changes
      foreach ($change in $changes) {
        $changeKey = "{0}|{1}" -f $change.resourceType, $change.resourceName
        $script:DesignResourceKeys.ContainsKey($changeKey) | Should -BeTrue -Because "Unexpected resource change detected for $changeKey"
      }
    }
  }

  foreach ($resource in $designData.resources) {
    $resourceSpec = $resource
    $contextName = "{0}::{1}" -f $resourceSpec.resourceType, $resourceSpec.resourceName

    Context $contextName {
      It 'should exist in what-if output' {
        $change = Get-ChangeForResource -WhatIfResult $script:WhatIfResult -ResourceSpec $resourceSpec
        $change | Should -Not -BeNullOrEmpty -Because "Missing what-if change for $contextName"
      }

      if ($resourceSpec.PSObject.Properties.Name -contains 'changeType') {
        It 'should have the expected change type' {
          $change = Get-ChangeForResource -WhatIfResult $script:WhatIfResult -ResourceSpec $resourceSpec
          $change | Should -Not -BeNullOrEmpty
          $change.changeType | Should -Be $resourceSpec.changeType -Because "Incorrect change type for $contextName"
        }
      }

      if ($resourceSpec.PSObject.Properties.Name -contains 'properties') {
        $propertyNames = Get-ObjectPropertyNames -InputObject $resourceSpec.properties
        foreach ($propertyName in $propertyNames) {
          $propertyLabel = "property::$propertyName"
          It "should match $propertyLabel" {
            $change = Get-ChangeForResource -WhatIfResult $script:WhatIfResult -ResourceSpec $resourceSpec
            $change | Should -Not -BeNullOrEmpty

            $actualAfter = $change.after
            $actualValue = Get-ObjectPropertyValue -InputObject $actualAfter -Name $propertyName
            $expectedValue = Get-ObjectPropertyValue -InputObject $resourceSpec.properties -Name $propertyName

            $null -ne $actualValue | Should -BeTrue -Because "Property '$propertyName' missing in what-if output for $contextName"
            Assert-Subset -Actual $actualValue -Expected $expectedValue -Path $propertyName
          }
        }
      }
    }
  }
}
