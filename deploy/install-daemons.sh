#!/bin/bash

# This script runs as the admin user, which has sudo privileges

# Expect a string with one or more names in it; each should correspond to a
# command or component as used in the deployment script `push.sh`
COMMAND_OR_COMPONENTS=$1

OTHOME=/home/opentree

add_web2py_session_sweeper()
{
    WEB2PY_APP_DIRNAME=$1
    SESSION_CLEANER_INIT_SCRIPT=cleanup-sessions-${WEB2PY_APP_DIRNAME}
    sudo cp "$OTHOME"/setup/cleanup-sessions-WEB2PYAPPNAME.lsb-template /etc/init.d/$SESSION_CLEANER_INIT_SCRIPT
    # N.B. there's also a generic linux init.d script that doesn't rely on LSB:
    # cp "$OTHOME"/setup/cleanup-sessions-WEB2PYAPPNAME.generic-template /etc/init.d/$SESSION_CLEANER_INIT_SCRIPT
    pushd .
        cd /etc/init.d
        # TODO: Set owner and permissions for this script?
        ##sudo chown ...
        ##sudo chmod 755 $SESSION_CLEANER_INIT_SCRIPT
        # Give it the proper directory name for this web2py app
        sudo sed -i -e "s+WEB2PY_APP_DIRNAME+$WEB2PY_APP_DIRNAME+g" $SESSION_CLEANER_INIT_SCRIPT
        # TODO: Customize its DAEMONOPTS?
        # Register this daemon with init.d and start it now
        sudo /usr/sbin/update-rc.d $SESSION_CLEANER_INIT_SCRIPT defaults
        # N.B. This should start automatically upon installation, BUT if
        # there's an older version already running, force systemd to restart.
        sudo service $SESSION_CLEANER_INIT_SCRIPT stop
        sudo service $SESSION_CLEANER_INIT_SCRIPT start
    popd
}

add_neo4j_service()
{
    # Each neo4j instance needs its own service (use the name provided)
    # Based on these how-tos:
    #   https://neo4j.com/docs/operations-manual/current/installation/linux/systemd/
    #   https://www.graphgrid.com/systemd-neo4j-ubuntu/
    NEO4J_INSTANCE_NAME=neo4j-$1
    NEO4J_INSTANCE_HOME="$OTHOME"/$NEO4J_INSTANCE_NAME
    NEO4J_COMMAND="$NEO4J_INSTANCE_HOME"/bin/neo4j
    NEO4J_INIT_SCRIPT="/etc/init.d/$NEO4J_INSTANCE_NAME"
    SYSTEMD_CONFIG_FILE="/lib/systemd/system/${NEO4J_INSTANCE_NAME}.service"
    # Symlink its controlling script
    sudo ln --symbolic --force "$NEO4J_INSTANCE_HOME/bin/neo4j" $NEO4J_INIT_SCRIPT
    # Create (and customize) its systemd config file from template
    sudo cp "$OTHOME"/setup/neo4j-service.systemd-template $SYSTEMD_CONFIG_FILE
    sudo sed -i -e "s+NEO4J_INSTANCE_NAME+$NEO4J_INSTANCE_NAME+g" $SYSTEMD_CONFIG_FILE
    sudo sed -i -e "s+NEO4J_INSTANCE_HOME+$NEO4J_INSTANCE_HOME+g" $SYSTEMD_CONFIG_FILE
    sudo sed -i -e "s+NEO4J_COMMAND+$NEO4J_COMMAND+g" $SYSTEMD_CONFIG_FILE
    # TODO: Set owner and permissions for this?
    # Load the new configuration and enable this service (starts after reboot)
    sudo systemctl daemon-reload
    sudo systemctl enable ${NEO4J_INSTANCE_NAME}.service
    # (re)start it now, using the new configuration
    sudo systemctl reload-or-restart ${NEO4J_INSTANCE_NAME}.service
}

for TEST_NAME in $COMMAND_OR_COMPONENTS; do
    echo "  testing this command or component for daemons: [$TEST_NAME]"
    # Some components and commands will deploy services that need daemons for
    # monitoring, to hand reboots, etc.
    case $TEST_NAME in
        # Commands that require daemons
        push-db | pushdb)
            ## push_neo4j_db $*
            # TODO: Monitor and restart neo4j? which one?
            ;;
        install-db)
            ## if [ $# = 2 ]; then
            ##     install_neo4j_db $*
            ##     # restart apache to clear the RAM cache (stale results)
            ##     restart_apache=yes
            ## else
            ##     err "Wrong number of arguments to install-db" $*
            ## fi
            # TODO: Monitor and restart neo4j? which one?
            ;;
        # Commands that don't need daemons (or already install them)
        apache | index  | indexoti | index-db | echo | none)
            echo "    No daemons required for command [$TEST_NAME]"
            ;;

        # Components that require daemons
        opentree)
            ## Customize the web2py session-cleanup template for this webapp
            echo "    Adding daemon to remove old web2py sessions [$TEST_NAME]..."
            add_web2py_session_sweeper opentree  # for main synth-tree viewer
            add_web2py_session_sweeper curator  # for study curation app
            echo "    Daemons added for apps opentree and curator! [$TEST_NAME]"
            ;;
        phylesystem-api | api)
            ## Customize the web2py session-cleanup template for this webapp
            echo "    Adding daemon to remove old web2py sessions [$TEST_NAME]..."
            add_web2py_session_sweeper phylesystem  # for APIs 'phylesystem-api'
            echo "    Daemon added for app phylesystem! [$TEST_NAME]"
            ;;
        oti)
            ## push_neo4j oti
            echo "    Adding daemon to manage neo4j instance [$TEST_NAME]..."
            add_neo4j_service oti
            echo "    Daemon added for this instance! [$TEST_NAME]"
            ;;
        treemachine)
            echo "    Adding daemon to manage neo4j instance [$TEST_NAME]..."
            add_neo4j_service treemachine
            echo "    Daemon added for this instance! [$TEST_NAME]"
            ;;
        taxomachine)
            echo "    Adding daemon to manage neo4j instance [$TEST_NAME]..."
            add_neo4j_service taxomachine
            echo "    Daemon added for this instance! [$TEST_NAME]"
            ;;
        # Components that don't need daemons (or already install them)
        smasher | otcetera | push_otcetera)
            echo "    No daemons required for component [$TEST_NAME]"
            ;;

        *)
            echo "    Name not found in script '$0'! [$TEST_NAME]"
            ;;
    esac
done   # end of TEST_NAME loop

echo "done installing daemons!"

# Salvaged from original implementation:
## # One of these commands hangs after printing "(Re)starting web2py session sweeper..."
## # so for now I'm going to disable this code.  See
## # https://github.com/OpenTreeOfLife/opentree/issues/845
##
## echo "(Re)starting web2py session sweeper..."
## # The sessions2trash.py utility script runs in the background, deleting expired
## # sessions every 5 minutes. See documentation at
## #   http://web2py.com/books/default/chapter/29/13/deployment-recipes#Cleaning-up-sessions
## # Find and kill any sweepers that are already running
## sudo pkill -f sessions2trash
## # Now run a fresh instance in the background for each webapp
## sudo nohup python $OPENTREE_HOME/web2py/web2py.py -S opentree -M -R $OPENTREE_HOME/web2py/scripts/sessions2trash.py &
## # NOTE that we allow up to 24 hrs(!) before study-curation sessions will expire
## sudo nohup python $OPENTREE_HOME/web2py/web2py.py -S curator -M -R $OPENTREE_HOME/web2py/scripts/sessions2trash.py --expiration=86400 &