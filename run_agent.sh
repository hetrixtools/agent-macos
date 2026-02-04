#!/bin/bash
# Wrapper: launch agent in background and exit immediately
# AbandonProcessGroup in the plist ensures the child survives
/bin/bash /opt/hetrixtools/hetrixtools_agent.sh &
