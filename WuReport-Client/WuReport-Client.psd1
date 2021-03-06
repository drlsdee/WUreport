@{
    RootModule = 'WuReport-Client.psm1'
    ModuleVersion = '0.0.0.0'
    GUID = 'c66f9ff5-d55e-4def-a4a6-1692067a4a2a'
    Author = 'drlsdee '
    CompanyName = 'Unknown'
    Copyright = '(c) 2020 drlsdee  <tracert0@gmail.com>. All rights reserved.'
    Description = 'Description should be here.'
    PowerShellVersion = '5.1'
    RequiredAssemblies = 'System.Core.dll'
    FunctionsToExport = 'Export-WuReport', 'Get-WuReport', 'Import-WuReport', 'New-WuReport'
    CmdletsToExport = '*'
    VariablesToExport = '*'
    AliasesToExport = '*'
    PrivateData = @{
        PSData = @{
            ProjectUri = 'https://github.com/drlsdee/WUreport'
            ReleaseNotes = 'Function "Get-WuReport" - help added, closing #23'
        }
    }
}
