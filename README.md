# XilinxTclStore


## As a Contributor
1. Get git account \<user\> and download git on your machine
2. Ask for permission to XilinxTclStore repository by sending e-mail to tclstore@xilinx.com
3. Sign on to github.com
4. Switch to Xilinx at upper left side by your account name \<user\>
5. Click Xilinx/XilinxTclStore under Repositories<p>
   Press "Fork"(upper right hand side) and create fork of XilinxTclStore to your account<p>
   https://help.github.com/articles/fork-a-repo
6. Switch to GitShell on your machine

### Checkout the Repository

If you have already clone the repository then skip this step. Otherwise to pull this repository from within a firewall you will need to congifure http.proxy:
```bash
git config --global http.proxy http://proxy:80
```

### Setting up a per repository User Name and Email

```bash
#Create and cd to a working directory, for instance ~/github/
mkdir working_dir
cd <working_dir>
git config --golbal user.name <user> #github user name
git config --global user.email your_email@your_company.com
```

7. Clone the repository

You have forked a repository from XilinxTclStore, called "user/XilinxTclStore.git". You need to clone it to your local area:

On Windows

```bash
cd <working_dir>
git clone https://github.com/user/XilinxTclStore.git
```

On Linux

```bash
cd <working_dir>
git clone http://user@github.com/user/XilinxTclStore.git
```

You will need to enter password to github when a password dialog box is popped up.

Now you have cloned the repo directories under "working_dir/XilinxTclStore"

cd working_dir/XilinxTclStore

```bash
git status
```

8. Create a new branch to \<user\>

The newly cloned repo has a default branch called "master".

We recommend to work on a branch. To create a user branch:

```bash
git branch <user>
```

9. Check out the branch \<user\>
```bash
git checkout <user>
```

10. Add your applications like tclapp/mycompany/myapp, including test<p>
    For more information on creating application, refer to the following section<p>
    ####My First Vivado Tcl App.

11. Mark files for adding
```bash
cd ./XilinxTclStore
git add tclapp/xilinx/<your_app>
```

12. Commit to local repository
```bash
git commit -m "your description of the commitment"
```

13. Push to \<user\>/XilinxTclStore in Github
```bash
git push origin <user>
e.g.
git push origin abeuser # abeuser is my user branch
```

14. Now switch back to github.com in browser and navigate to your repository and \<user\> branch.<p>
1) For instance, https://github.com/user/XilinxTclStore<p>
2) In the branch button pull down (upper left), switch from "branch:master" to "branch:\<user\>"<p>

15. Send Pull Request 
https://help.github.com/articles/creating-a-pull-request
Make sure to choose \<user\> branch from left upper-ish "branch" drop down<p>
Press "Pull Request" button right upper-ish <p>
Add any additiona note if you wish<p>

Done!

## Sync with master from \<user\> branch
If you need to work on the same \<user\> branch next time, you will need to sync to the fork.<p>
https://help.github.com/articles/sync-a-fork

Create upstream pointing to Xilinx/XilinxTclStore<p>

```bash
On Windows:
git remote add upstream https://github.com/Xilinx/XilinxTclStore.git
```

```bash
On Linux:
git remote add upstream https://user@github.com/Xilinx/XilinxTclStore.git
```

Fetch and merge upstream to local master
```bash
git fetch upstream
git merge upstream/master
```

Switch back to \<user\> branch and merge
```bash
git checkout user
git merge master
```


## As a Gate Keeper
config proxy (refer to As a Contributor)

config \<user\> (refer to As a Contributor)

config \<user\> email (refer to As a Contributor)

config merge option
```bash
git config --global merge.defaultToUpstream true
```

1. Create a reposiroty by clone out XilinxTclStore, skip to next step if repository already exists locally
```bash
On Windows
git clone https://github.com/XilinxInc/XilinxTclStore.git
On Linux
git clone http://user@github.com/XilinxInc/XilinxTclStore.git
```

2. Update local repo with github master
```bash
git fetch
```

3. Merge any changes
```bash
git merge --ff
```

4. Set up remote to point where the pull request is sent usually user/user if this has not been done yet
```bash
git remote add remote_name https://github.com/<user>/XilinxTclStore.git
e.g.
git remote add raj https://github.com/rajklair/XilinxTclStore.git
```

5. Update local repo with \<user\> branch
```bash
git fetch remote_name
```

6. Merge changes from \<user\> branch
```bash
git merge remote_name/remote_branch
e.g.
git merge raj/rajklair
```

7. Fix any merge conlicts

8. Add the changes and commit
```bash
git add .
git commit -m "update notes"
```

9. Run tests and checck content

10. Push to github or go to step 11
```bash
git push origin master
```
geto Step 12

11. Go to Github.com
Pull Request from the \<user\>.<p> 
If everything is good, merge, add comments and close the pull request.<p>
If something is not good, add comments so the requester can make changes.<p>
If something is bad, add comments, reject it and close the pull request.<p> 
https://help.github.com/articles/merging-a-pull-request

12. Delete the local repository
```bash
git branch -r -d remote_name/remote_branch
e.g.
git branch -r -d raj/rajklair
```
 Or in browser, delete this branch after merging when prompted.

Done

## My First Vivado Tcl App

### Let Vivado know where your cloned Tcl repository is located

Before you start Vivado set XILINX_TCLAPP_REPO to the location of your cloned repository
```bash
setenv XILINX_TCLAPP_REPO <path>/XilinxTclStore
```
Some of the Tcl app related commmands in Vivado require a Tcl repo to be present so it is important the
env variable is set before you start Vivado.

### Fetch and merge updates to your cloned repository

If you have already cloned the repository, then you may want to fetch and merge the latest updates into your clone.<p>
The lastest and greatest official apps are available in the "master" branch so this is where you want to merge into.<p>

```bash
cd XilinxTclStore
git checkout master
git fetch
git merge
```

### Create your own branch

This is necessary only if you want to add or change existing apps.  All changes you make must be made 
on a separate branch so that the repository owner (gate keeper) can pull your branch and look at your changes
before deciding if they meet the criteria for accepting into the master branch.

We recommend using a branch name that is your organization-<usernm>.
```bash
git branch myorg-johnd
git checkout myorg-johnd
```
If the branch alraedy exists in your clone, the make sure you merge the lastest "master" changes to your branch
```bash
git checkout myorg-johnd
git merge master
```

### Create the Directory Structure

The directory structure should follow _repo_/tclapp/_organization_/_appname_/...
```bash
mkdir -p ./tclapp/mycompany/myapp
cd ./tclapp/mycompany/myapp
```

More directory and testing structure can be found in tclapp/README. 

### Create the Package Provider

```bash
vi ./myapp.tcl
```

Change the version and namespace to match your app:
```tcl
# tclapp/mycompany/myapp/myapp.tcl
package require Tcl 8.5

namespace eval ::tclapp::mycompany::myapp {

    # Allow Tcl to find tclIndex
    variable home [file join [pwd] [file dirname [info script]]]
    if {[lsearch -exact $::auto_path $home] == -1} {
    lappend ::auto_path $home
    }

}
package provide ::tclapp::mycompany::myapp 1.0
```


### Customize the App

Your app scripts will not be able to have this same name, but could be placed inside of this package provider file.
If you already have the app created, then copy it into _repo_/tclapp/_organization_/_appname_/.
If you are creating the app from scratch, then:
```bash
vi ./myfile.tcl
```

You need to make sure of couple things:

1. You must have all procs in namespaces, e.g.
```tcl
# tclapp/mycompany/myapp/myfile.tcl
proc ::tclapp::mycompany::myapp::myproc1 {arg1 {optional1 ,}} {
    ...
}
```

2. Add the commands that you would like to export to the top of each file.  It is important
that your are explicit about the commands, in other words, do *not* use wildcards.
```tcl
# tclapp/mycompany/myapp/myfile.tcl
namespace eval ::tclapp::mycompany::myapp {
    # Export procs that should be allowed to import into other namespaces
    namespace export myproc1
}
proc ::tclapp::mycompany::myapp::myproc1 {arg1 {optional1 ,}} {
    ...
}
```

3. You must have 3 comments which describe your procedure interfaces - inside of the procedures, 
and each section must be seperated by new lines (without comments)
```tcl
# tclapp/mycompany/myapp/myfile.tcl
namespace eval ::tclapp::mycompany::myapp {
    # Export procs that should be allowed to import into other namespaces
    namespace export myproc1
}
proc ::tclapp::xilinx::test::myproc1 {arg1 {optional1 ,}} {
    
    # Summary : A one line summary of what this proc does

    # Argument Usage:
    # arg1 : A one line summary of this argument
    # [optional1=,] : A one line summary of this argument

    # Return Value: 
    # TCL_OK is returned with result set to a string
    
    ...
}
```


### Create the Package Index and Tcl Index

```bash
cd ~/XilinxTclStore/tclapp/mycompany/myapp
vivado -mode tcl -nolog -nojournal
```

```tcl
pkg_mkIndex .
auto_mkindex .
```


### Running the Linter

If you are not already in Vivado:
```bash
vivado -mode tcl
```

There should be a lint_files command available at this point:
```tcl
Vivado% lint_files [glob XilinxTclStore/tclapp/mycompany/myapp/*.tcl]
```

Correct anything the linter identifies as a problem.


### Check the App before you Deploy

1. Set XILINX_TCLAPP_REPO to point where the local XilinxTclStore is
```bash
setenv XILINX_TCLAPP_REPO <path>/XilinxTclStore
```
or just the path
```bash
setenv XILINX_TCLAPP_REPO <path> 
```
Run Vivado
```bash
vivado -mode tcl
```

When the env variable is set, Vivado automatically adds the location of the repository to the 
auto_load path in Tcl.

2. Start testing<p>

Require the package that was provided by the app

```tcl
vivado% package require ::tclapp::mycompany::myapp
```

Optionally import an exported proc

```tcl
namespace import ::tclapp::mycompany::myapp::*
myproc1
...
```

### Setting up a per repository User Name and Email

```bash
cd ~/XilinxTclStore
git config user.name “johnd”
git config user.email “johnd@mycompany.com”
```


### Commit Changes

Make sure you commit your \<user\> branch.

```bash
cd ~/XilinxTclStore
git checkout myorg-johnd
git add .
git status
git commit -m "created myapp for mycompany"
git push origin mycompany
```

