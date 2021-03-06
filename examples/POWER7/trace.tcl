#
# (C) Copyright IBM Corporation 2011, 2016
#

#
# Amester example file for using TPMD trace buffer
#
# This example file shows how to configure and download traces
# of AMESTER sensors and parameters.  On multi-node POWER7 systems,
# it will configure each trace (with identical names, e.g. trace1ms)
# the same way and download.
#
# This example also shows how to run a remote command
# and turn on the tracing only for during command execution.
#

package require job


#
# Globals
#
::amesterdebug::set tb 1
::amesterdebug::set trace 1

# Set machine to trace
set ::fsp_address arlz222.austin.ibm.com
set ::fsp_passwd FipSdev
set ::partition_address arlz224.austin.ibm.com
set ::partition_userid root
set ::command "ls"


# Set where the output goes.
set ::filename_prefix ""
set ::job_output_filename "myjobout.txt"

# Set the sensors/scoms to view

# Valid sockets on a 4 socket system are {0 1 2 3}
set ::socket_list {0}
# The sensor list has pairs of sensor name and field.
# Valid fields are value,min,max,acc,updates,test,rcnt
# rcnt is a 1ms timer in the TPMD.
set ::traceitems(trace1ms,sensor_list) {{PWR1MS rcnt} {PWR1MS value} {PWR32MS value} } 
set ::traceitems(trace32ms,sensor_list) {{PWR1MS rcnt} {PWR1MS value} {PWR32MS value} } 
#Parameter list
set ::traceitems(trace1ms,parm_list) {} 
set ::traceitems(trace32ms,parm_list) {}

# List of SCOM addresses to gather. (No longer supported)
set ::scom_list {}


#
# Helper functions
#

proc my_stop {{job {}}} {
    #stop recording
    foreach amec [myfsp get ameclist] {
	$amec trace_stop
    }

    if {$job ne {}} {
	set jobresults [$job cget -output]

	if {[catch {set file [open $::job_output_filename w]}]} {
	    puts stderr "Cannot open file $::job_output_filename"
	    return
	}

	puts $file $jobresults
	close $file
    }
    

    puts "dumping..."
    #Turn on debugging output for tracebuffer to see something is happening
    ::amesterdebug::set tb 1
    foreach amec [myfsp get ameclist] {
	foreach t [$amec get traces] {
	    set tname [$t cget -tracename]
	    if {![info exists ::traceitems(${tname},sensor_list)]} {
		puts "missing variable ::traceitems(${tname},sensor_list).  Skipping download of $t"
		continue
	    }
	    if {![info exists ::traceitems(${tname},parm_list)]} {
		puts "missing variable ::traceitems(${tname},parm_list).  Skipping download of $t"
		continue
	    }
	    set filename "${::filename_prefix}[${t} cget -objname].csv"
	    my_dump $t $filename $::traceitems(${tname},sensor_list) $::traceitems(${tname},parm_list) {} {}
	}
    }
    #Turn off debugging output for tracebuffer
    ::amesterdebug::set tb 0
    puts "done"

}

# Write tracebuffer to a comma-separated-value file
proc my_dump {tb filename sensors parms scoms sockets} {
    #
    # Open file
    #
    if {[catch {set file [open $filename w]}]} {
	puts stderr "Cannot open file $filename"
	return
    }

    #
    # Print a header line
    #
    set head {}
    foreach s $sensors {
	foreach {name field} $s {
	    lappend head "${name}_${field}"
	}
    }

    foreach s $parms {
	lappend head $s
    }


    foreach s $scoms {
	foreach sock $sockets {
	    lappend head "${s}_#${sock}"
	}
    }

    puts $file [join $head ","]

    #
    # Dump the data
    #
    set entries [$tb get_all_entries]
    foreach e $entries {
	puts $file [join $e ","]
    }
    close $file
    puts "Finished writing to file $filename"
}


#
# Main
#


# Connect to fsp
netc myfsp -addr $::fsp_address -passwd $::fsp_passwd

::amesterdebug::set ipmi 1
# Configure and start recording in the trace buffer
puts "configuring..."
foreach amec [myfsp get ameclist] {
    #Some versions of TPMD firmware require tb_enable parameter to be set 1 for tracing to work
    if {[find object ${amec}_tb_enable] ne {}} {
	set tbenable [${amec}_tb_enable read]
	${amec}_tb_enable write 1
    }

    #Configure what the traces collect
    foreach t [$amec get traces] {
	set tname [$t cget -tracename]
	puts "Found trace $tname on $amec"
	if {![info exists ::traceitems(${tname},sensor_list)]} {
	    puts "Variable ::traceitems(${tname},sensor_list) not defined.  Skipping configuration of $t"
	    continue
	}
	if {![info exists ::traceitems(${tname},parm_list)]} {
	    puts "Variable ::traceitems(${tname},parm_list) not defined.  Skipping configuration of $t"
	    continue
	}
	$t set_config $::traceitems(${tname},sensor_list) $::traceitems(${tname},parm_list) {} {}
    }
}
puts "recording..."
foreach amec [myfsp get ameclist] {
    $amec trace_start
}

###########################################
# Choose one of the following methods.
# By default, we use method 1.
##########################################

#
# Method 1: Record for fixed amount of time.
# For example, 3000 ms.
#
after 3000
my_stop


#
# Method 2: Record during a workload run.
# This method assumes you have passwordless ssh setup.
#
# Make a job
# job_ssh myjob $::partition_address $::command -userid $::partition_userid
#
# What do to when job is over
# myjob add_isdone_callback my_stop
#
# Start running the job
# myjob run
#
# When job is done, my_stop is triggered to stop recording


# The following line tells Amester to explicitly quit when --nogui 
# commandline option is used.
# Otherwise, it keeps running because it uses an event-loop style program.
if {!$::options(gui)} {exit_application}
