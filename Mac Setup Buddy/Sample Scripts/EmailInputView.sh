#!/bin/sh

#  EmailInputView.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
# Basic email prompt
./MacSetupBuddy -email-prompt

# Email prompt with custom messaging
./MacSetupBuddy -email-prompt \
  -background solid \
  -title "User Authentication" \
  -message "Please enter your corporate email address" \
  -placeholder "username@example.com" \
  -banner "https://example.com/logo.png" \
  -width 650 \
  -height 500
