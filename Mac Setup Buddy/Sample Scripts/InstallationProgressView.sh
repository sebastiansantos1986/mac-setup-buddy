#!/bin/sh

#  InstallationProgressView.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
# Basic JAMF installation progress
./MacSetupBuddy -jamf-policy

# Full JAMF monitoring with auto-close
./MacSetupBuddy -jamf-policy \
  -background blur \
  -title "Installing Required Software" \
  -subtitle "JAMF Policy Execution" \
  -banner "/Library/Company/banner.png" \
  -enableLogMonitor true \
  -autoCloseDelay 5 \
  -showCountdown true \
  -width 800 \
  -height 600
