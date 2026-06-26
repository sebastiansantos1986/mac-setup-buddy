#!/bin/sh

#  SuccessView.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
# Basic success view
./MacSetupBuddy -user_info

# Success with email (limited customization in current parser)
./MacSetupBuddy -user-info \
  -email "user@company.com"
