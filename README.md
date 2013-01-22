# XilinxTclStore


## My First Vivado Tcl App


### Checkout the Repository

If you have already clone the repository then skip this step. Otherwise to pull this repository from within a firewall you will need to congifure http.proxy:
```bash
git config --global http.proxy http://proxy:80
```

After this is set, then the repository must be pulled using the http protocol:
```bash
cd ~
git clone https://github.com/XilinxInc/XilinxTclStore.git
cd ./XilinxTclStore
git status
```

### Let Vivado know where your cloned Tcl repository is located

Before you start Vivado set XILINX_TCLAPP_REPO to the location of your cloned repository
```bash
setenv XILINX_TCLAPP_REPO <path>/XilinxTclStore
```
Some of the Tcl app related commmands in Vivado require a Tcl repo to be present so it is important the
env variable is set before you start Vivado.

### Fetch and merge updates to your cloned repository

If you have already cloned the repository, then you may want to fetch and merge the latest updates into your clone.
The lastest and greatest official apps are available in the "master" branch so this is where you want to merge into.

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

2. Add the commands that you would like to export to the top of each file.  It's important
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
Vivado% lint_files [glob Xilinx-Tcl-Repositiry/tclapp/mycompany/myapp/*.tcl]
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

Make sure you commit your user branch.

```bash
cd ~/XilinxTclStore
git checkout myorg-johnd
git add .
git status
git commit -m "created myapp for mycompany"
git push origin mycompany
```

