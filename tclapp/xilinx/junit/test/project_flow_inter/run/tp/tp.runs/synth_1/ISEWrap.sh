#!/bin/sh

#
#  Vivado(TM)
#  ISEWrap.sh: Vivado Runs Script for UNIX
#  Copyright 1986-1999, 2001-2013 Xilinx, Inc. All Rights Reserved. 
#

HD_LOG=$1
shift

# CHECK for a STOP FILE
if [ -f .stop.rst ]
then
echo ""                                        >> $HD_LOG
echo "*** Halting run - EA reset detected ***" >> $HD_LOG
echo ""                                        >> $HD_LOG
exit 1
fi

ISE_STEP=$1
shift

# WRITE STEP HEADER to LOG
echo ""                      >> $HD_LOG
echo "*** Running $ISE_STEP" >> $HD_LOG
echo "    with args $@"      >> $HD_LOG
echo ""                      >> $HD_LOG

# LAUNCH!
$ISE_STEP "$@" >> $HD_LOG 2>&1 &

# BEGIN file creation
ISE_PID=$!
if [ X != X$HOSTNAME ]
then
ISE_HOST=$HOSTNAME #bash
else
ISE_HOST=$HOST     #csh
fi
ISE_USER=$USER
ISE_BEGINFILE=.$ISE_STEP.begin.rst
/bin/touch $ISE_BEGINFILE
echo "<?xml version=\"1.0\"?>"                                                                     >> $ISE_BEGINFILE
echo "<ProcessHandle Version=\"1\" Minor=\"0\">"                                                   >> $ISE_BEGINFILE
echo "    <Process Command=\"$ISE_STEP\" Owner=\"$ISE_USER\" Host=\"$ISE_HOST\" Pid=\"$ISE_PID\">" >> $ISE_BEGINFILE
echo "    </Process>"                                                                              >> $ISE_BEGINFILE
echo "</ProcessHandle>"                                                                            >> $ISE_BEGINFILE

# WAIT for ISEStep to finish
wait $ISE_PID

# END/ERROR file creation
RETVAL=$?
if [ $RETVAL -eq 0 ]
then
    /bin/touch .$ISE_STEP.end.rst
else
    /bin/touch .$ISE_STEP.error.rst
fi

exit $RETVAL
