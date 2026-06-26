#!/bin/sh

#  debug_view.sh
#  Mac Setup Buddy
#
#  Created by Sebastian Santos on 10/4/25.
#  
#!/bin/bash

# Debug script with verbose output
VIEW=$1
shift

echo "=== DEBUG MODE ==="
echo "View: $VIEW"
echo "Arguments: $@"
echo "=================="

# Run with debug output
./MacSetupBuddy $VIEW $@ 2>&1 | tee debug_output.log

echo "Exit code: $?"
