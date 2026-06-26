#
//  WelcomeView.sh
//  Mac Setup Buddy
//
//  Created by Sebastian Santos on 10/4/25.
//

# Basic welcome screen
./MacSetupBuddy -welcome-screen

# Welcome with blur background
./MacSetupBuddy -welcome-screen -background blur

# Fully customized welcome
./MacSetupBuddy -welcome-screen \
  -background blur \
  -title "Welcome to Mac Setup Buddy" \
  -subtitle "Enterprise Security Setup" \
  -message "Hello! Let's configure your Mac for secure access." \
  -banner "/path/to/banner.png" \
  -bannerTitle "Mac Setup Buddy" \
  -bannerSubtitle "Security. Simplified." \
  -welcomeIcon "shield.fill" \
  -buttonText "Begin Setup" \
  -timeEstimate "Setup takes 10-15 minutes" \
  -step1 "Verify user credentials" \
  -step2 "Register device with MDM" \
  -step3 "Install security agents" \
  -step4 "Configure network policies" \
  -width 900 \
  -height 700
