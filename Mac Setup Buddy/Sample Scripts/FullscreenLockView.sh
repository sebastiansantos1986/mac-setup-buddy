#!/bin/sh

#  FullscreenLockView.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
# This view isn't directly mapped in CommandLineParser
# but could be invoked with custom flags:
./MacSetupBuddy -fullscreen-lock \
  -background blur \
  -title "Security Compliance Check" \
  -message "Verifying device compliance..."
