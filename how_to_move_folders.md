How to move subfolder(s) from one git repo to another git repo preserving its commit history
---------------------------------------------------------------------------------------------
I have been working on restructuring some of our codebase, I had to move few folders from one repo to another repo and had to preserve its history, so while doing that I thought of documenting the process.
It turned out that you can’t move more than one folder at a time (or at least I don’t know how) so I had to repeat the same process for each folder I wanted to get out from the source repo to destination repo.

Assuming you have two repos like this

repoA

|-> src

	|-> sub1
	
		|-> sub1.1
		
	|-> sub2

repoB

|-> src

	|-> sub3
	
	|-> sub4

And you want to move “sub1” from RepoA to RepoB under folder src.

Process:
-------
Clone the source and destination repos on your machine
> mkdir c:\repos

> cd c:\repos

> git clone https://repoA.git repoA

> git clone https://repoB.git repoB

create a temp clone of repoA as temp source repo to make folder manipulations in it

> mkdir C:\Repos\tmp-move

> git clone --no-hardlinks C:\Repos\repoA C:\Repos\tmp-move

> cd C:\Repos\tmp-move

now delete all history except the subfolder you want to move by running command below:

> git filter-branch --subdirectory-filter src/sub1 HEAD -- --all

compress and reclaim all the empty space in the repo after you filtered all history.

> git reset --hard

> git gc --aggressive

> git prune

Now go to repoB and pull/merge sub1 from tmp-move

> cd ..\repoB

> git remote add origin-tmp-move ..\tmp-move

> git pull origin-tmp-move master

After this you will have all contents of “sub1” moved to repoB with history. The problem is the contents will be moved to the root of repoB, so now you will have to use git mv commands to move contents of sub1 to appropriate location you want in repoB
So in this case we will have to create a folder src\sub1 in repoB and move all these files to that folder.
One you have moved all the files from sub1 to appropriate place in repoB,

> git commit -m "moved sub1 from repoA to repoB"

> git remote rm origin-tmp-move

> git push origin master


Now follow this process for each subfolder you want to do this for each folder. delete the "tmp-move" folder/local repo each time to move new folder.

