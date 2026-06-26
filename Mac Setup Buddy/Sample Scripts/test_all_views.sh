#!/bin/sh

#  test_all_views.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
#!/bin/bash

echo "Testing Mac Setup Buddy Views..."

# Test each view for 5 seconds
views=(
    "-welcome-screen"
    "-email-prompt"
    "-jamf-policy"
    "-aad-progress"
    "-completion"
    "-notification"
    "-user-info"
)

for view in "${views[@]}"; do
    echo "Testing: $view"
    timeout 5 ./MacSetupBuddy $view -background blur &
    sleep 6
done

echo "All views tested!"
