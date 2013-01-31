# XilinxTclStore


## As a Contributor
1. Get git account "user" and download git on your machine
2. Ask for permission to XilinxTclStore repository by sending e-mail to tclstore@xilinx.com
3. Sign on to github.com
4. Switch to XilinxInc at upper left side by your account name "user"
5. Click XilinxInc/XilinxTclStore under Repositories<p>
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
#Create and cd to a working <user dir> directory, for instance ~/github/
mkdir <user dir>
cd <user dir>
git config --golbal user.name <user>
git config --global user.email <user>@company.com
```

7. Clone the repository
```bash
cd <user dir>
git clone https://github.com/<user>/XilinxTclStore.git
#This will create the repo directories under <user dir>/XilinxTclStore
cd ./XilinxTclStore
git status
```

8. Create a new branch to "user"
```bash
git branch <user>
```

9. Check out the branch "user"
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

13. Push to "user"/XilinxTclStore in Github
```bash
git push origin <user>
```

14. Now switch back to github.com in browser and navigate to your report and "user" branch.<p>
1) For instance, https://github.com/"user"/XilinxTclStore<p>
2) In the branch button pull down (upper left), switch to "user" branch<p>

15. Send Pull Request 
Make sure to choose "user" branch to send Pull Request<p>
https://help.github.com/articles/creating-a-pull-request

Done!

## Sync with master from "user" branch
If you need to work on the same "user" branch next time, you will need to sync to the fork.<p>
https://help.github.com/articles/sync-a-fork

Create upstream pointing to XilinxInc/XilinxTclStore
```bash
git remote add upstream https://github.com/XilinxInc/XilinxTclStore.git
```

Fetch and merge upstream to local master
```bash
git fetch upstream
git merge upstream/master
```

Switch back to "user" branch and merge
```bash
git checkout user
git merge master
```


## As a Gate Keeper
config proxy (see Work as a Contributor)

config "user" (see Work as a Contributor)

config "user" email (see Work as a Contributor)

config merge option
```bash
git config --global merge.defaultToUpstream true
```


1. After receiving a pull request, clone the "user" repository into a clean directory
```bash
git clone https://github.com/<user>/XilinxTclStore.git
```

2. Check out the "user" branch
```bash
git checkout <user>
```

3. Fetch the branch
```bash
git fetch
```

4. Merge in the changes
```bash
git merge --ff
```

5. Run tests and checck content

6. Go to Github.com
Pull Request from the "user".<p> 
If everything is good, merge, add comments and close the pull request.<p>
If something is not good, add comments so the requester can make changes.<p>
If something is bad, add comments, reject it and close the pull request.<p> 
https://help.github.com/articles/merging-a-pull-request

7. Delete the local repository

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

1. From Bash:
```bash
setenv XILINX_TCLAPP_REPO <path>/XilinxTclStore
vivado -mode tcl
```

When the env variable is set, Vivado automatically adds the location of the repository to the 
auto_load path in Tcl.

2. Start testing
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

Make sure you commit your "user" branch.

```bash
cd ~/XilinxTclStore
git checkout myorg-johnd
git add .
git status
git commit -m "created myapp for mycompany"
git push origin mycompany
```

