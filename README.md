# vso_git_utils
Versioning in VSO hosted builds using git annotated tags
========================================================

These PowerShell function will give ability to use git tags for versioning your releases. Let’s first understand how auto versioning using tags can be implemented in your VSO git repo.
-	During your development process, when you are ready to release a version of your product, tag your commit with version tag in the format of v1.2 or v1.2.3 or v1.2.0.4 (depending on what version you are planning to release)
-	Note that you can also tag past commit with an annotated tag in the format of v1.0.0.0 (v followed by major.minor.build.revision) or if you are following http://semver.org/ it will be v MAJOR.MINOR.PATCH
-	On the build controller, read the tag for commit which is getting compiled and use that to parse and create full version value to be used by other scripts in your build. If there is no tag for current commit, transverse all tags, get last version tag and count revisions till the current commit.

The powershell function will also count number of revisions since last version tag to get continuous versions for all your VSO builds till a new version tag is placed on the repo.
Example, you tagged v1.2, any commits after this, which does not have version tag will start using versions like 1.2.0.1, 1.2.0.2 etc. This gives nice way of counting your revisions since last tag.
At any point, you can always put full version tag including revision numbers and script will omit adding incremented revisions, for example if you add tag v1.2.0.3, script will use that exact as is. (i.e. script will fill all missing numbers as required)

The utility functions are described below.

Get-GitCommitDetails -Verbose
------------------------------
OUTPUT: </br>
Gets the last commit details in a git repo. The details will include AuthorName, AuthorEmail, CommitNotes, CommitDate, CommitHash, CommitId values. These can be useful if you have some custom build workflow scripts which will trigget some notifications.

Example:

| Name          |     Value       | DataType  |
|:------------- |:-------------|:-----|
| CommitDate  | 2015-03-21 23:37:36 -0700 | Date |
| AuthorEmail | someone@something.com | string  |
| CommitHash  | 1604e36db07bb85aa9ec8308a23427676dccacec   | String |
| CommitId    | 1604e36                                    | String  |
| CommitNotes | commit notes from author  | String  |

Get-VersionFromGitTag -Verbose
------------------------------
OUTPUT: </br>
Version info from the tags if any (e.g. if tag was v1.2.0 return value will be 1.2.0.0)
Example: branch for which there is no tag applied ever, will give version info like below as powershell hashtable.
Assuming this is third commit to the repo.

| Name          |     Value       | DataType  |
|:------------- |:-------------|:-----|
| CurrentCommitHash | 00124663509e5b82d0dc91e5c4f492a89d74b2ae | String |
| Version      | 1.0.0.3 | System.Version  |
| Tag | v1.0   | String |
| TagCommitHash | $null  | String  |
