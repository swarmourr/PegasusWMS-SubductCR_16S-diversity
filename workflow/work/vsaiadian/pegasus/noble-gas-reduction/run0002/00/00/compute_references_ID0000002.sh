#!/bin/bash
set -e
pegasus_lite_version_major="5"
pegasus_lite_version_minor="1"
pegasus_lite_version_patch="3"
pegasus_lite_enforce_strict_wp_check="true"
pegasus_lite_version_allow_wp_auto_download="true"
pegasus_metrics="true"


. pegasus-lite-common.sh

pegasus_lite_init

# cleanup in case of failures
trap pegasus_lite_signal_int INT
trap pegasus_lite_signal_term TERM
trap pegasus_lite_unexpected_exit EXIT

printf "\n########################[Pegasus Lite] Setting up workdir ########################\n"  1>&2
# work dir
export pegasus_lite_work_dir=$PWD
pegasus_lite_setup_work_dir

printf "\n##############[Pegasus Lite] Figuring out the worker package to use ##############\n"  1>&2
# figure out the worker package to use
pegasus_lite_worker_package

set -e
pegasus_lite_section_start stage_in
printf "\n##################### Setting the xbit for executables staged #####################\n"  1>&2
# set the xbit for any executables staged
/bin/chmod +x compute_references

pegasus_lite_section_end stage_in

printf "\n########[Pegasus Lite] Writing out script to launch user task in container ########\n"  1>&2

cat <<EOF > compute_references_ID0000002-cont.sh
#!/bin/bash
set -e

# tmp dirs are handled by Singularity - don't use the ones from the host
unset TEMP
unset TMP
unset TMPDIR

# setting environment variables for job
HOME=/srv
export HOME

EOF
container_env /srv >> compute_references_ID0000002-cont.sh
cat <<EOF2 >> compute_references_ID0000002-cont.sh
pegasus_lite_version_major=$pegasus_lite_version_major
pegasus_lite_version_minor=$pegasus_lite_version_minor
pegasus_lite_version_patch=$pegasus_lite_version_patch
pegasus_lite_enforce_strict_wp_check=$pegasus_lite_enforce_strict_wp_check
pegasus_lite_version_allow_wp_auto_download=$pegasus_lite_version_allow_wp_auto_download
pegasus_lite_inside_container=true
export pegasus_lite_work_dir=/srv

cd /srv
. ./pegasus-lite-common.sh
pegasus_lite_init

printf "\n##############[Container] Figuring out Pegasus worker package to use ##############\n"  1>&2
# figure out the worker package to use
pegasus_lite_worker_package
printf "PATH in container is set to is set to \$PATH\n"  1>&2

printf "\n#########################[Container] Launching user task #########################\n"  1>&2

pegasus-kickstart  -n compute_references -N ID0000002 -R local  -S @$_CONDOR_SCRATCH_DIR/compute_references_ID0000002.in.lof  -s @$_CONDOR_SCRATCH_DIR/compute_references_ID0000002.out.lof  -L noble-gas-reduction -T 2026-10-09T21:41:26+00:00 ./compute_references GAS_PROCESS.xlsx
EOF2


chmod +x compute_references_ID0000002-cont.sh
if ! [ $pegasus_lite_start_dir -ef . ]; then
	cp $pegasus_lite_start_dir/pegasus-lite-common.sh . 
fi

set +e
job_ec=0
singularity_init noble-gas.sif
job_ec=$(($job_ec + $?))

$singularity_exec exec --no-home --bind $PWD:/srv --bind $_CONDOR_SCRATCH_DIR:$_CONDOR_SCRATCH_DIR noble-gas.sif /srv/compute_references_ID0000002-cont.sh
job_ec=$(($job_ec + $?))

pegasus_lite_section_start stage_out
pegasus_lite_section_end stage_out

set -e


# clear the trap, and exit cleanly
trap - EXIT
pegasus_lite_final_exit

