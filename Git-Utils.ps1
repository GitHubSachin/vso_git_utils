<#
.Synopsis
   Gets the commit details in a git repo. The details will include AuthorName, AuthorEmail, CommitNotes, CommitDate, CommitHash, CommitId values.

.DESCRIPTION
   Gets the commit details in a git repo. The details will include AuthorName, AuthorEmail, CommitNotes, CommitDate, CommitHash, CommitId values.

.PARAMETER LocalRepositoryPath
    (Optional) Directory path where your local git repo is at. This is optional, if value is not provided, script assumes its location as working git repo.

.PARAMETER CommitHash
    (optional) Git commit hash value for which you want to get details of. this is sha1 hash value, it can be either a full hash string or first 8 characters.
    If the value is not provided in input, script will get latest top commit on the repo to show details for.

.EXAMPLE
    PS C:\> Get-GitCommitDetails -Verbose
	
    This example will list all the details for latest commit on the repo. It will return hashtable in format below.

    Name        Value                                      
    ----        -----                                      
    CommitDate  2015-03-21 23:37:36 -0700                  
    AuthorEmail test@test.com                       
    AuthorName  First Last                                     
    CommitHash  1604e36db07bb85aa9ec8308a23427676dccacec   
    CommitId    1604e36                                    
    CommitNotes added test functions to get git commit info

.EXAMPLE
    PS C:\> Get-GitCommitDetails -LocalRepositoryPath c:\repos\MyGitProject1 -CommitHash a0b123sd
	
    This example will list all the details for commit a0b123sd on the repo cloned at c:\repos\MyGitProject1. It will return hashtable in format below.

    Name        Value                                      
    ----        -----                                      
    CommitDate  2015-03-21 23:37:36 -0700                  
    AuthorEmail test@test.com                       
    AuthorName  First Last                                     
    CommitHash  a0b123sdb07bb85aa9ec8308a23427676dccacec   
    CommitId    a0b123sd                                    
    CommitNotes added test functions to get git commit info

.LINK
    https://github.com/GitHubSachin/vso_git_utils

#>

function Get-GitCommitDetails
{
[CmdletBinding()]
          Param(
          [string] $LocalRepositoryPath = $null,
          [string] $CommitHash = $null
          )
          Process
{
    $gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
    Write-Verbose $gitExe
    if(-not [string]::IsNullOrEmpty($LocalRepositoryPath))
    {
        Push-Location $LocalRepositoryPath
    }

    #check if this is git repo
    # This way script does not throw error as it captures std error strea, using 2>&1
    $consoleError = powershell.exe -Command { & $args[0] show -v } -args @($gitExe) 2>&1
    if($consoleError.ToString().Contains("Not a git repository") -or $consoleError.ToString().Contains("bad default revision"))
    {
        Write-Warning "This is not a git repository"
        return $null;
    }

    if([string]::IsNullOrEmpty($CommitHash))
    {
        $gitcommitHash = & $gitExe rev-list HEAD --tags --max-count=1
    }
    else
    {
        $gitcommitHash = $CommitHash
        #validate if user supplied correct hash for the repo to get details of.
        $consoleError = powershell.exe -Command { & $args[0] log --pretty=format:"%h" $args[1] } -args @($gitExe,$gitcommitHash) 2>&1
        if($consoleError -ne $null)
        {
            if($consoleError.Length -gt 0)
            {
                foreach($err in $consoleError)
                {
                $err.ToString()
                    if($err.ToString().Contains("unknown revision"))
                    {
                        Write-Warning "Invalid git commit hash: $gitcommitHash"
                        Write-Warning $err.ToString()
                        return $null; 
                    }
                }
            }
        }
    }

    $authorName = & $gitExe log --pretty=format:"%an" $gitcommitHash --max-count=1
    $authorEmail = & $gitExe log --pretty=format:"%ae" $gitcommitHash --max-count=1
    $commitNotes = & $gitExe log --pretty=format:"%s" $gitcommitHash --max-count=1
    $commitdate = & $gitExe log --date=iso --pretty=format:"%ad" $gitcommitHash --max-count=1
    $CommitId = & $gitExe log --pretty=format:"%h" $gitcommitHash --max-count=1 --abbrev=8

    $data = @{"AuthorName"=$authorName;
    "AuthorEmail"=$authorEmail;
    "CommitNotes" = $commitNotes;
    "CommitDate" = $commitdate;
    "CommitHash" = $gitcommitHash;
    "CommitId" = $CommitId
    }
    Pop-Location
    Write-Output $data
}
}

<#
.Synopsis
   Get-VersionFromGitTag Gets the version number from the commit tags in current repo. The version tags must start with v and should be in format of v1.0 or v1.0.0 etc.

.DESCRIPTION
   The version numbers are tags in git repo. if there is no tag, version number will be 1.0.0
   if last commit does not have version tag, script will return version from latest last tag commit.

.EXAMPLE
    PS C:\> Get-VersionFromGitTag -Verbose
	
    This example will get version info from the tags if any (e.g. if tag was v1.2.0 return value will be 1.2.0.0)
    Example: branch for which there is no tag applied ever, will give version info like below.
    Assuming this is third commit to the repo.

    Name              Value                                   
    ----              -----                                   
    CurrentCommitHash [string] 00124663509e5b82d0dc91e5c4f492a89d74b2ae
    Version           [System.Version] 1.0.3                                
    Tag               [String] v1.0                                   
    TagCommitHash     [String] $null

.EXAMPLE
    PS C:\> Get-VersionFromGitTag -LocalRepositoryPath c:\repos\MyGitProject1
	
    This example will list all the details for commit a0b123sd on the repo cloned at c:\repos\MyGitProject1. It will return hashtable in format below.

.LINK
    https://github.com/GitHubSachin/vso_git_utils

#>
function Get-VersionFromGitTag
{
[CmdletBinding()]
          Param(
          [string] $LocalRepositoryPath = $null
          )
Process
{
$gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
Write-Verbose $gitExe
    
if(-not [string]::IsNullOrEmpty($LocalRepositoryPath))
{
    Push-Location $LocalRepositoryPath
}

try
{
    #check if this is git repo
    # This way script does not throw error as it captures std error strea, using 2>&1
    $consoleError = powershell.exe -Command { & $args[0] show -v } -args @($gitExe) 2>&1
    if($consoleError.ToString().Contains("Not a git repository") -or $consoleError.ToString().Contains("bad default revision"))
    {
        Write-Warning "This is not a git repository"
        return $null;
    }

    $gitcommitHash = & $gitExe rev-list HEAD --tags --max-count=1
    Write-Verbose "Current commit hash: $gitcommitHash"
    #gets last known tag
    $allRevisions = & $gitExe rev-list HEAD
    $lastTag = $null;
    $lastTagCommitHash= $null;
    $tagdata = Get-LatestVersionTag
    $lastTag = $tagdata.Tag
    $lastTagCommitHash = $tagdata.TagCommitHash

    #now parse the version tag in version format format major.minor.build.revision
    $VersionNumber = Parse-VersionStringFromTag $lastTag $gitcommitHash $lastTagCommitHash
    [reflection.assembly]::LoadWithPartialName("System.Version")

    $version = New-Object System.Version($VersionNumber)

    Write-Output @{ "Version" = $version;
    "TagCommitHash" = $lastTagCommitHash;
    "Tag" = $lastTag;
    "CurrentCommitHash" = $gitcommitHash
    }
}
catch
{
    Write-Error $_
}
finally
{
    Pop-Location
}

}

}

function Get-RemoteRepositoryName
{
    $gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
    $repoUrls = & $gitExe remote -v
    if(-not [string]::IsNullOrEmpty($repoUrls))
    {
        $fetchUrl = $repoUrls[0].Split("/")
        $remoteRepo = $fetchUrl[$fetchUrl.Length -1]
        $remoteRepo = $remoteRepo.Replace("(fetch)","")
        Write-Output $remoteRepo.Trim()
    }
    Write-Output ""
}

function Get-LocalGitRepositoryRoot
{
    $gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
    $repoPath = & $gitExe rev-parse --git-dir
    Write-Verbose "Local repo root: $repoPath"
    if(-not [string]::IsNullOrEmpty($repoPath))
    {
        $repoPath = Resolve-Path $repoPath
        $repoPath = [System.IO.Path]::GetDirectoryName($repoPath)
        Write-Output $repoPath.Trim()
    }
    Write-Output ""
}

#Parses the version number from a given tag.
function Parse-VersionStringFromTag
{
[CmdletBinding()]
Param([string]$lastTag, [string] $currentCommitHash, [string] $tagCommitHash)
Process
{
$VersionRegex2 = "\d+\.\d+\.\d+"
$VersionRegex3 = "\d+\.\d+"
$VersionNumber =$null;

$VersionData2 = [regex]::matches($lastTag,$VersionRegex2)
$VersionData3 = [regex]::matches($lastTag,$VersionRegex3)

$revision = 0;

if([string]::IsNullOrEmpty($lastTag) -or [string]::IsNullOrEmpty($tagCommitHash))
{
    # no tags exists, count till head.
    $revision = Get-Revision $null
}

if(($currentCommitHash -ne $tagCommitHash) -and -not [string]::IsNullOrEmpty($tagCommitHash))
{
    if(-not [string]::IsNullOrEmpty($tagCommitHash))
    {
        $revision = Get-Revision $tagCommitHash
    }
    else
    {
       $revision = Get-Revision $currentCommitHash 
    }
}

Write-Verbose "Calculated revision: $revision"

if($VersionData2.Count -eq 1)
{
    $VersionNumber = $VersionData2[0].ToString()
    Write-Verbose "Full version number available in the tag"
    $parts = $VersionNumber.Split(".")
    $rev = [System.Convert]::ToInt32($revision)
    Write-Verbose "calculated revision number since last tagged commit is $rev"
    $VersionNumber = "{0}.{1}.{2}.{3}" -f @($parts[0],$parts[1],$parts[2],$rev)

}
elseif($VersionData3.Count -eq 1)
{
    $VersionNumber = $VersionData3[0].ToString()
    #user did not specify revision and build so set it to zero.
    $VersionNumber = $VersionNumber + ".0." + $revision
}
else
{
    $VersionNumber ="1.0.0." + $revision # cant make out version form the tag.
}

Write-Output $VersionNumber
}
}

# returns current Revision number by counting the nummer of commits till given commit hash
function Get-Revision
{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)]
    [string] $commitHash
)
Process
{
   Write-Verbose "Calculating revision number till commit $commitHash"
   $gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
   $allCommitCount = & $gitExe rev-list HEAD --count
   Write-Verbose "Total commits till head: $allCommitCount"
   $revs=0;
   if(-not [string]::IsNullOrEmpty($commitHash))
   {
    $revs  = & $gitExe rev-list "$commitHash..HEAD" --count --ancestry-path
    Write-Verbose "Commit number: $revs for $commitHash"
    Write-Output $revs
   }
   else
   {
    Write-Output $allCommitCount
   }
}
}

#Gets all tags on a repo and returns the latest one which is in format of version number.
function Get-LatestVersionTag
{
[CmdletBinding()]
Param()
Process
{
    $lastTagCommitHash = $null;
    $lastTag = $null ;
    $gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
    $allTags = & $gitExe for-each-ref --sort=-taggerdate --format '%(tag)' refs/tags
    $VersionRegex3 = "[v](?:(\d+)\.)?(?:(\d+)\.)?(\d+)$"
    if($allTags.Length -eq 0)
    {
        Write-Verbose "There are no version tags in this repo in format of v1.0.0 ([v]major.minor.patch)"
    }

    foreach($tag in $allTags)
    {
        Write-Verbose "Checking version format for tag: $tag"
        $VersionData = [regex]::matches($tag,$VersionRegex3)
        if($VersionData.Count -eq 1)
        {
            $commitsTillTag = & $gitExe rev-list $tag
            if($commitsTillTag.GetType().Name -eq "String")
            {
                $lastTagCommitHash = $commitsTillTag
            }
            else
            {
                $lastTagCommitHash = $commitsTillTag[0]
            }
            $lastTag = $tag
            break;
        }
        else
        {
            Write-Verbose "Skipping tag $tag because it does not match version pattern."
        }
    }

    Write-Output @{
        "Tag" = $lastTag;
        "TagCommitHash" = $lastTagCommitHash
    }
}
}

