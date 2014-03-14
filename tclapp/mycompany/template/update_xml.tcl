## 
## This file is meant to be sourced to update the catalog file for the template app
##

set NAME {template}
set DISPLAY {A Prettier Name for template}
set COMPANY {mycompany}
set COMPANY_DISPLAY {MyCompany, Inc.}
set SUMMARY {Summary of app's intent. This can be a multi-line description}
set AUTHOR {'FirstName LastName' or empty string to hide it}
set REVISION 1.0
set REVISION_HISTORY {}
# set VIVADO_VERSION {2014.1}
set VIVADO_VERSION [version -short]

set infoprocs [list \
  {my_command1} {my_command1 summary. This can be a multi-line description} \
  {my_command2} {my_command2 summary. This can be a multi-line description} \
  {my_command3} {my_command3 summary. This can be a multi-line description} \
  ]

# ==========================================

if {[get_param tclapp.sharedRepoPath] != {}} {
  set WDIR [get_param tclapp.sharedRepoPath]
} elseif {[info exists env(XILINX_TCLAPP_REPO)]} {
  set WDIR $env(XILINX_TCLAPP_REPO)
} else {
  set WDIR [pwd]/XilinxTclStore
}

# Load the catalog. Vivado automatically picks up the catalog that matches the version of the tool being run
tclapp::load_catalog $WDIR
# Add the full path to the app
tclapp::add_app_path $WDIR/tclapp/${COMPANY}/${NAME}
# Add some properties to the app
tclapp::add_property ${COMPANY}::${NAME} {name} $NAME
tclapp::add_property ${COMPANY}::${NAME} {display} $DISPLAY
tclapp::add_property ${COMPANY}::${NAME} {company} $COMPANY
tclapp::add_property ${COMPANY}::${NAME} {company_display} $COMPANY_DISPLAY
tclapp::add_property ${COMPANY}::${NAME} {summary} $SUMMARY
tclapp::add_property ${COMPANY}::${NAME} {author} $AUTHOR
tclapp::add_property ${COMPANY}::${NAME} {pkg_require} "Vivado $VIVADO_VERSION"
tclapp::add_property ${COMPANY}::${NAME} {revision} $REVISION
tclapp::add_property ${COMPANY}::${NAME} {revision_history} $REVISION_HISTORY

foreach {name summary} $infoprocs {
  # Define the proc(s) exported by the app. One call per proc
  tclapp::add_proc ${COMPANY}::${NAME} $name
  # Add a summary for each proc
  tclapp::add_proc_property ${COMPANY}::${NAME} $name {summary} $summary
}

# Save the catalog directly under the correct location
tclapp::save_catalog $WDIR/catalog/catalog_${VIVADO_VERSION}.xml
