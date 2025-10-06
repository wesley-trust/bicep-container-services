[CmdletBinding()]
Param(
  [string]$DesignPath = "./tests/unit/resource_group/resourcegroup.tests.json"
)

BeforeDiscovery {
  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Version Latest

  # Import Design
  $script:Design = Get-Content -Path $DesignPath -Raw | ConvertFrom-Json

  # Get unique Resource Types
  $script:ResourceTypes = $Design.resourceType | Sort-Object -Unique
}

Describe 'Integrity Check' {
  It 'should have at least one Resource Type' {
    $ResourceTypes.Count | Should -BeGreaterThan 0
  }
}

Describe 'Resource Type <_>' -ForEach $ResourceTypes {
  param($ResourceType)

  BeforeDiscovery {
    $script:Resources = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).resources
    $Tags = ($Design | Where-Object { $_.resourceType -eq $ResourceType }).tags

    $TagHashTable = @{}
    $Tags.PSObject.Properties | ForEach-Object { $TagHashTable[$_.Name] = $_.Value }
  }

  It 'should have at least one Resource' {
    $script:Resources.Count | Should -BeGreaterThan 0
  }

  Context 'Resource Name <_.name>' -ForEach $Resources {
    param($Resource)

    BeforeDiscovery {
      $script:Properties = $Resource.PSObject.Properties.Name
    }

    It 'should have at least one Property' {
      $Properties.Count | Should -BeGreaterThan 0
    }

    It 'has property <_>' -ForEach $Properties {
      param(
        [string]$Property
      )
      $Property | Should -Not -BeNullOrEmpty
    }
  }

  It 'Resources have tag <_.Key> with value <_.Value>' -ForEach $TagHashTable.GetEnumerator() {
    param($Tag)
    
    $Tag.Value | Should -Not -BeNullOrEmpty
  }
}