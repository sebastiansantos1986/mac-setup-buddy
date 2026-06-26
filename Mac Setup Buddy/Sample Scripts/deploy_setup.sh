#!/bin/sh

#  deploy_setup.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
#!/bin/bash

# Production deployment flow
BANNER="/Library/Company/Resources/banner.png"
USER_EMAIL=$(osascript -e 'text returned of (display dialog "Enter your email:" default answer "")')

# Step 1: Welcome
./MacSetupBuddy -welcome-screen \
  -background blur \
  -banner "$BANNER" \
  -title "Mac Setup Buddy" \
  -message "Welcome! Your device will be configured for secure access."

# Step 2: Capture email
EMAIL=$(./MacSetupBuddy -email-prompt \
  -background blur \
  -banner "$BANNER" \
  -placeholder "@example.com")

# Step 3: AAD Lookup
./MacSetupBuddy -aad-progress \
  -background blur \
  -email "$EMAIL" \
  -autoProgress true

# Step 4: JAMF Installation
./MacSetupBuddy -jamf-policy \
  -background blur \
  -enableLogMonitor true \
  -autoCloseDelay 10

# Step 5: Completion
./MacSetupBuddy -completion \
  -background blur \
  -email "$EMAIL" \
  -userName "$(id -F)" \
  -deviceName "$(scutil --get ComputerName)" \
  -osVersion "$(sw_vers -productVersion)"
