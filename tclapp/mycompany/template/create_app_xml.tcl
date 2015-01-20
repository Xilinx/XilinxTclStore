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

# ==========================================

if {0} {
  # Update the app's XML (app.xml)
  # Prerequisite: the app.xml file must already exist
  tclapp::update_app_catalog ${COMPANY}::${NAME} ${REVISION_HISTORY}
}

if {1} {
  # Create the inital app's XML (app.xml)
  # Prerequisite: the app.xml does not exist
  # Load the app catalog (app.xml)
  tclapp::open_app_catalog ${COMPANY}::${NAME}
  # Add some properties to the app
  tclapp::add_app_property {name} $NAME
  tclapp::add_app_property {display} $DISPLAY
  tclapp::add_app_property {company} $COMPANY
  tclapp::add_app_property {company_display} $COMPANY_DISPLAY
  tclapp::add_app_property {summary} $SUMMARY
  tclapp::add_app_property {author} $AUTHOR
  tclapp::add_app_property {pkg_require} "Vivado $VIVADO_VERSION"
  tclapp::add_app_property {revision} $REVISION
  tclapp::add_app_property {revision_history} $REVISION_HISTORY
  # Save the app catalog
  tclapp::save_app_catalog
}
