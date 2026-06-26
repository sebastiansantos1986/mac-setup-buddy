#!/bin/sh

#  AADProgressView.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
# Basic Azure AD lookup
./MacSetupBuddy -aad

# Customized AAD progress
./MacSetupBuddy -aad-progress \
  -background blur \
  -message "Searching Azure Active Directory..." \
  -email "john.smith@company.com" \
  -aadIcon "magnifyingglass" \
  -progressMessage "Connecting to directory services..." \
  -cancelButton "Cancel Search" \
  -autoProgress true \
  -stepDuration 1.5 \
  -banner "/path/to/banner.png" \
  -width 650 \
  -height 700
