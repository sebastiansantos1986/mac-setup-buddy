#!/bin/sh

#  CompletionView.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
# Basic completion screen
./MacSetupBuddy -completion

# Full completion with user/device info
./MacSetupBuddy -completion \
  -background blur \
  -message "Your device has been successfully configured" \
  -userName "John Smith" \
  -email "john.smith@example.com" \
  -department "Engineering" \
  -title "Senior Developer" \
  -assetTag "FP-2024-001" \
  -deviceName "MBP-JS2024" \
  -deviceModel "MacBookPro18,3" \
  -serialNumber "C02XW123H7JY" \
  -osVersion "14.5" \
  -banner "/path/to/success-banner.png" \
  -width 950 \
  -height 700
