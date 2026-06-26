#!/bin/sh

#  NotificationView.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
# Basic notification
./MacSetupBuddy -notification

# Custom notification (not fully implemented in parser, but structure exists)
./MacSetupBuddy -notification \
  -background blur \
  -notificationTitle "Security Update Required" \
  -notificationMessage "Critical security patches are available" \
  -notificationIcon "exclamationmark.shield.fill" \
  -notificationButtons "Update Now,Remind Later"
