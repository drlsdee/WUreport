# WUreport

## Delivery
###  You may publish your module to a PowerShell repository:

1.  Getting a list of registered PS repos
    
    `Get-PSRepository`
    
    Register a repo on the file share
    
    `[string]$repoPath = '\\fileserver\hiddenShare$\PSModules'`
    
    `[string]$repoName = 'TemporaryLocalRepo'`
    
    `Register-PSRepository -Name $repoName -SourceLocation $repoPath -PublishLocation $repoPath -ScriptSourceLocation $repoPath -ScriptPublishLocation $repoPath -InstallationPolicy Trusted -PackageManagementProvider NuGet`

2.  Publish your module
    
    It would be better if this repository was also registered on the developer's computer. But you may just specify the share path.
    Like here: https://docs.microsoft.com/ru-ru/powershell/scripting/gallery/how-to/working-with-local-psrepositories
    You need to have NuGet on the developer or publisher machine, or on a node of your CI system (e.g. Jenkins).
    Run:
    
    `Publish-Module -Path <path to the root directory of your module> -Repository $repoName  -NuGetApiKey 'none'`

3.  Find and install the module on client computers:
    
    `Find-Module -Repository $repoName`

4.  You can write a PS script, that checks if your repository is registered, and assign this script as startup script via GPO. Do not forget about PowerShell execution policy!

### Or you may deliver the module as MSI package with GPO
### Or, maybe, just deliver the files with GPO preferences


## Preamble
Необходимо решить задачу контроля и мониторинга обновления пользовательских рабочих станций (PC) и терминальных машин. Предполагается, что учётная запись, под которой будет решаться задача, имеет права администратора на целевых PC и WSUS, а также возможно создание групповой политики AD.
Задача разбита на 3 части которые можно решать по отдельности или вместе.

## Tasklist
1.  Сбор информации
    1. получить из ветки AD список PC;
    2. сформировать отчёт, который будет включать в себя:
        1. имя PC;
        2. имена пользователей;
        3. дату последнего установленного обновления;
        4. кол-во доступных для установки обновлений;
        5. статус "Pending for reboot" если обновления установлены и ожидается перезагрузка;
        6. адрес WSUS сервера;
        7. дата последней синхронизации с WSUS.

2. Уведомление пользователей и контроль:
    1. если на PC доступны обновления для установки, необходимо, в рабочее время, вывести пользователю всплывающее окно с сообщением вида «Необходимо выполнить установку критических обновлений и обновлений безопасности»;
    2. если на PC установлены обновления в состоянии "Pending for reboot" , необходимо, в рабочее время, вывести пользователю всплывающее окно с сообщением вида "для завершения установки обновлений";
    3. если пользователь в течении 3-х рабочих дней не выполнил установку и перезагрузку, то должно появиться сообщение с указанием даты установки обновлений и перезагрузки в автоматическом режиме;
    4. количество таких сообщений желательно добавить в отчёт.

3. Автоматический ребут:
    1. выполнить перезагрузку PC в состоянии "Pending for reboot" при просрочке перезагрузки более 3-х дней;
    2. необходимо выполнить автоматическую установку при просрочке более 3-х дней.

## Conclusion
На выходе хотелось бы видеть один или несколько PowerShell скриптов/модулей которые позволяют решить задачу полностью или частично. Групповую политику можно описать отдельно. Комментарии будут плюсом.
