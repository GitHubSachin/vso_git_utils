<#
.Synopsis
   Gets the last commit details in a git repo. The details will include AuthorName, AuthorEmail, CommitNotes, CommitDate, CommitHash, CommitId values.

.DESCRIPTION
   Gets the last commit details in a git repo. The details will include AuthorName, AuthorEmail, CommitNotes, CommitDate, CommitHash, CommitId values.

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

.LINK
    https://github.com/GitHubSachin/vso_git_utils

#>

function Get-GitCommitDetails
{
[CmdletBinding()]
          Param()
          Process
{
    $gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
    Write-Verbose $gitExe
    $gitcommitHash = & $gitExe rev-list HEAD --tags --max-count=1
    $authorName = & $gitExe log --pretty=format:"%an" $gitcommitHash
    $authorEmail = & $gitExe log --pretty=format:"%ae" $gitcommitHash
    $commitNotes = & $gitExe log --pretty=format:"%s" $gitcommitHash
    $commitdate = & $gitExe log --date=iso --pretty=format:"%ad" $gitcommitHash
    $CommitId = & $gitExe log --pretty=format:"%h" $gitcommitHash

    $data = @{"AuthorName"=$authorName[0];
    "AuthorEmail"=$authorEmail[0];
    "CommitNotes" = $commitNotes[0];
    "CommitDate" = $commitdate[0];
    "CommitHash" = $gitcommitHash;
    "CommitId" = $CommitId[0]
    }
    Write-Output $data
}
}

<#
.Synopsis
   Gets the version number from the commit tags in current repo.

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
    Version           [System.Version] 1.0.0.3                                
    Tag               [String] v1.0                                   
    TagCommitHash     [String] $null

.LINK
    https://github.com/GitHubSachin/vso_git_utils

#>
function Get-VersionFromGitTag
{
[CmdletBinding()]
          Param()
Process
{
$gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
Write-Verbose $gitExe
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
}

#Parses the version number from a given tag.
function Parse-VersionStringFromTag
{
[CmdletBinding()]
Param([string]$lastTag, [string] $currentCommitHash, [string] $tagCommitHash)
Process
{
$VersionRegex1 = "\d+\.\d+\.\d+\.\d+"
$VersionRegex2 = "\d+\.\d+\.\d+"
$VersionRegex3 = "\d+\.\d+"
$VersionNumber =$null;
$VersionData1 = [regex]::matches($lastTag,$VersionRegex1)
$VersionData2 = [regex]::matches($lastTag,$VersionRegex2)
$VersionData3 = [regex]::matches($lastTag,$VersionRegex3)

if($VersionData1.Count -eq 1)
{
    $VersionNumber = $VersionData1[0].ToString()
    Write-Verbose "Full version is in the tag, checking if tagged commit is behind current commit"
    Write-Verbose $currentCommitHash
    Write-Verbose $tagCommitHash
    if($currentCommitHash -ne $tagCommitHash)
    {
        Write-Verbose "getting incremental revision form last tagged commit till $currentCommitHash"
        $incrementalRev = (Get-Revision $tagCommitHash)
        
        $parts = $VersionNumber.Split(".")
        $rev = ([System.Convert]::ToInt32($parts[3]) + [System.Convert]::ToInt32($incrementalRev))
        Write-Verbose "calculated revision number since last tagged commit is $rev"
        $VersionNumber = "{0}.{1}.{2}.{3}" -f @($parts[0],$parts[1],$parts[2],$rev)
    }
}
elseif($VersionData2.Count -eq 1)
{
    $VersionNumber = $VersionData2[0].ToString()
    #user did not specify revision so set the value.
    $VersionNumber = $VersionNumber + "." + (Get-Revision $currentCommitHash)
}
elseif($VersionData3.Count -eq 1)
{
    $VersionNumber = $VersionData3[0].ToString()
    #user did not specify revision and build so set it to zero.
    $VersionNumber = $VersionNumber + ".0." + (Get-Revision $currentCommitHash)
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
    $lastTag = "v1.0" ;
    $gitExe = Join-Path ${env:ProgramFiles(x86)} "Git\bin\git.exe"
    $allTags = & $gitExe for-each-ref --sort=-taggerdate --format '%(tag)' refs/tags
    $VersionRegex3 = "[v](?:(\d+)\.)?(?:(\d+)\.)?(\d+)?(\.\d+)$"
    if($allTags.Length -eq 0)
    {
        Write-Verbose "There are no tags in this repo"
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

#Test
#Get-GitCommitDetails | Format-Table -AutoSize
#Get-VersionFromGitTag -Verbose
#Get-LatestVersionTag -Verbose
#Parse-VersionStringFromTag "v1.0.3.14" "9c28139bdea6c1b2163febf47c67aa8df020bf7d" "4839f863d8c5065b049cd4aa4cd680774b63ea8a" -Verbose
#Get-Revision "25e42623711d435951f48775969ec3011a5f10f0"