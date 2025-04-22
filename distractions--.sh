#!/bin/bash

# Title: Distractions --  (anIrreversible Distraction Blocker)
# Description: Blocks distracting websites with no ability to reverse until timer ends
# Author: moron 6554 - https://github.com/moron6554/distractions--

# Initialize variables for cleanup tracking
HOSTS_MODIFIED=false
HOSTS_IMMUTABLE=false
SERVICES_CREATED=false

# Signal handler for clean exit on CTRL+C or other interruptions
cleanup() {
    echo -e "\n[!] Script interrupted. Cleaning up..."
    
    # Remove immutable attribute if we added it
    if [ "$HOSTS_IMMUTABLE" = true ]; then
        echo "[*] Removing immutable attribute from hosts file..."
        chattr -i /etc/hosts 2>/dev/null
    fi
    
    # Restore original hosts file if we modified it
    if [ "$HOSTS_MODIFIED" = true ]; then
        echo "[*] Restoring original hosts file..."
        if [ -f "/etc/hosts.hardblock.bak" ]; then
            cp /etc/hosts.hardblock.bak /etc/hosts
        else
            # Fallback: remove our block entries
            sed -i '/# HARDBLOCK START/,/# HARDBLOCK END/d' /etc/hosts
        fi
    fi
    
    # Clean up systemd services if we created them
    if [ "$SERVICES_CREATED" = true ]; then
        echo "[*] Removing systemd services..."
        systemctl stop hardblock-unblock.timer 2>/dev/null
        systemctl disable hardblock-unblock.timer 2>/dev/null
        systemctl stop hardblock-unblock.service 2>/dev/null
        systemctl stop hardblock-countdown.service 2>/dev/null
        rm -f /etc/systemd/system/hardblock-unblock.service 2>/dev/null
        rm -f /etc/systemd/system/hardblock-unblock.timer 2>/dev/null
        rm -f /etc/systemd/system/hardblock-countdown.service 2>/dev/null
        systemctl daemon-reload 2>/dev/null
    fi
    
    # Remove lock files
    rm -f "$LOCK_DIR/block_active" 2>/dev/null
    rm -f "$LOCK_DIR/end_time" 2>/dev/null
    
    echo "[*] Cleanup complete. Exiting."
    
    # Show GUI notification of cancellation if zenity is available
    if [ -n "$DISPLAY" ] && command -v zenity &>/dev/null; then
        zenity --info --title="Operation Canceled" --text="Website blocking was interrupted and canceled.\nYour system has been restored to its previous state." 2>/dev/null
    fi
    
    exit 1
}

# Set up trap for signals
trap cleanup SIGINT SIGTERM SIGHUP

# Force script to run as root
if [ "$EUID" -ne 0 ]; then
  zenity --error --title="Root Access Required" --text="This script must be run with sudo privileges.\n\nPlease run:\nsudo .$0"
  exit 1
fi

# Create lock directory to store block data that persists through reboots
LOCK_DIR="/var/lib/hardblock"
mkdir -p "$LOCK_DIR"

# Ensure dependencies are installed
DEPENDENCIES=(zenity at chattr systemd-run date)
MISSING_DEPS=()

for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    zenity --error --title="Missing Dependencies" \
           --text="The following required tools are not installed:\n\n$(printf "• %s\n" "${MISSING_DEPS[@]}")\n\nPlease install them with:\nsudo apt install ${MISSING_DEPS[*]}"
    exit 1
fi

# Function to convert human-readable duration to seconds
duration_to_seconds() {
    local duration="$1"
    local seconds=0
    local days=0
    local hours=0
    local minutes=0
    
    # Extract days if present
    if [[ $duration =~ ([0-9]+)\ *d ]]; then
        days=${BASH_REMATCH[1]}
        seconds=$((seconds + days * 86400))
    fi
    
    # Extract hours if present
    if [[ $duration =~ ([0-9]+)\ *h ]]; then
        hours=${BASH_REMATCH[1]}
        seconds=$((seconds + hours * 3600))
    fi
    
    # Extract minutes if present
    if [[ $duration =~ ([0-9]+)\ *m ]]; then
        minutes=${BASH_REMATCH[1]}
        seconds=$((seconds + minutes * 60))
    fi
    
    # Extract seconds if present
    if [[ $duration =~ ([0-9]+)\ *s ]]; then
        seconds=$((seconds + BASH_REMATCH[1]))
    fi
    
    # If no units specified, parse as minutes or hours based on value
    if [ $seconds -eq 0 ]; then
        if [[ $duration =~ ^([0-9]+)$ ]]; then
            value=${BASH_REMATCH[1]}
            # If single value, assume hours if <= 24, otherwise minutes
            if [ $value -le 24 ]; then
                seconds=$((value * 3600))
            else
                seconds=$((value * 60))
            fi
        elif [[ $duration =~ ([0-9]+)\ *hour ]]; then
            hours=${BASH_REMATCH[1]}
            seconds=$((hours * 3600))
        elif [[ $duration =~ ([0-9]+)\ *minute ]]; then
            minutes=${BASH_REMATCH[1]}
            seconds=$((minutes * 60))
        elif [[ $duration =~ ([0-9]+)\ *day ]]; then
            days=${BASH_REMATCH[1]}
            seconds=$((days * 86400))
        fi
    fi
    
    echo $seconds
}

# Check if a block is already in progress
if [ -f "$LOCK_DIR/block_active" ] && [ -f "$LOCK_DIR/end_time" ]; then
    END_TIME=$(cat "$LOCK_DIR/end_time" 2>/dev/null || echo "0")
    CURRENT_TIME=$(date +%s)
    
    if [ "$END_TIME" != "0" ] && [ "$CURRENT_TIME" -lt "$END_TIME" ]; then
        REMAINING=$((END_TIME - CURRENT_TIME))
        HOURS=$((REMAINING / 3600))
        MINUTES=$(((REMAINING % 3600) / 60))
        
        zenity --error --title="Block Already Active" \
               --text="A website block is already in progress!\n\nTime remaining: ${HOURS}h ${MINUTES}m\n\nThis block CANNOT be lifted until the timer expires."
        exit 1
    else
        # Clean up expired block
        rm -f "$LOCK_DIR/block_active" "$LOCK_DIR/end_time"
    fi
fi

# Default block list with categories
DEFAULT_BLOCKS=(
    # Social Media
    "facebook.com www.facebook.com"
    "instagram.com www.instagram.com"
    "twitter.com www.twitter.com x.com www.x.com"
    "reddit.com www.reddit.com old.reddit.com"
    "tiktok.com www.tiktok.com"
    
    # Adult Content
    "pornhub.com www.pornhub.com"
    "xvideos.com www.xvideos.com"
    "xnxx.com www.xnxx.com"
    "redtube.com www.redtube.com"
    "rule34.xxx www.rule34.xxx"
    "spankbang.com www.spankbang.com"
    
    # Time Wasters
    "youtube.com www.youtube.com"
    "netflix.com www.netflix.com"
    "twitch.tv www.twitch.tv"
    "hulu.com www.hulu.com"
)

# Show GUI for configuration
CONFIG=$(zenity --forms --title="HardBlock Configuration" \
    --text="<span color='red'><b>⚠️ WARNING: This block CANNOT be reversed until the timer ends!</b></span>" \
    --add-combo="Block Duration:" --combo-values="30 minutes|1 hour|2 hours|4 hours|8 hours|Custom..." \
    --add-entry="Custom Duration (e.g., 3 hours, 90 minutes):" \
    --add-entry="Additional websites to block (space-separated):" \
    --add-combo="Block Preset:" --combo-values="All|Social Media Only|Adult Content Only|Time Wasters Only|None" \
    --width=500 --height=350)

# Exit if canceled
if [ $? -ne 0 ]; then
    zenity --info --title="Operation Canceled" --text="Website blocking canceled."
    exit 0
fi

# Parse the form input
DURATION_CHOICE=$(echo "$CONFIG" | cut -d'|' -f1)
CUSTOM_DURATION=$(echo "$CONFIG" | cut -d'|' -f2)
ADDITIONAL_SITES=$(echo "$CONFIG" | cut -d'|' -f3)
PRESET_CHOICE=$(echo "$CONFIG" | cut -d'|' -f4)

# Determine final duration
if [ "$DURATION_CHOICE" = "Custom..." ]; then
    if [ -z "$CUSTOM_DURATION" ]; then
        zenity --error --title="Invalid Duration" --text="No custom duration specified. Please try again."
        exit 1
    fi
    DURATION="$CUSTOM_DURATION"
else
    DURATION="$DURATION_CHOICE"
fi

# Convert duration to seconds for timer calculation
DURATION_SECONDS=$(duration_to_seconds "$DURATION")

# Check if we have a valid duration
if [ "$DURATION_SECONDS" -eq 0 ]; then
    zenity --error --title="Invalid Duration Format" \
           --text="The duration '$DURATION' could not be parsed.\n\nPlease use formats like:\n• 30m or 30 minutes\n• 2h or 2 hours\n• 1d or 1 day"
    exit 1
fi

# Calculate end time
CURRENT_TIME=$(date +%s)
END_TIME=$((CURRENT_TIME + DURATION_SECONDS))

# Format duration for display
format_duration() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local result=""
    
    if [ $days -gt 0 ]; then
        result="${days} day"
        [ $days -ne 1 ] && result="${result}s"
    fi
    
    if [ $hours -gt 0 ]; then
        [ -n "$result" ] && result="${result}, "
        result="${result}${hours} hour"
        [ $hours -ne 1 ] && result="${result}s"
    fi
    
    if [ $minutes -gt 0 ]; then
        [ -n "$result" ] && result="${result}, "
        result="${result}${minutes} minute"
        [ $minutes -ne 1 ] && result="${result}s"
    fi
    
    echo "$result"
}

FORMATTED_DURATION=$(format_duration $DURATION_SECONDS)

# Final confirmation with stronger warning
if ! zenity --question --title="FINAL WARNING" \
    --text="<span color='red' size='large'><b>⚠️ POINT OF NO RETURN ⚠️</b></span>\n\nYou are about to block distracting websites for: <b>$FORMATTED_DURATION</b>\n\n<b>This action CANNOT be undone!</b>\n\nEven restarting your computer will NOT remove the block.\nAre you ABSOLUTELY sure you want to proceed?" \
    --width=400; then
    zenity --info --title="Operation Canceled" --text="Website blocking canceled."
    exit 0
fi

# Build the list of domains to block based on preset
DOMAINS=()

case "$PRESET_CHOICE" in
    "All")
        for entry in "${DEFAULT_BLOCKS[@]}"; do
            for domain in $entry; do
                DOMAINS+=("$domain")
            done
        done
        ;;
    "Social Media Only")
        for ((i=0; i<5; i++)); do
            for domain in ${DEFAULT_BLOCKS[$i]}; do
                DOMAINS+=("$domain")
            done
        done
        ;;
    "Adult Content Only")
        for ((i=5; i<11; i++)); do
            for domain in ${DEFAULT_BLOCKS[$i]}; do
                DOMAINS+=("$domain")
            done
        done
        ;;
    "Time Wasters Only")
        for ((i=11; i<15; i++)); do
            for domain in ${DEFAULT_BLOCKS[$i]}; do
                DOMAINS+=("$domain")
            done
        done
        ;;
    "None")
        # No preset domains selected
        ;;
esac

# Add user's additional sites
if [ ! -z "$ADDITIONAL_SITES" ]; then
    read -ra CUSTOM_DOMAINS <<< "$ADDITIONAL_SITES"
    for domain in "${CUSTOM_DOMAINS[@]}"; do
        DOMAINS+=("$domain")
        # Also add www. version if not specified
        if [[ ! "$domain" =~ ^www\. ]]; then
            DOMAINS+=("www.$domain")
        fi
    done
fi

# Check if we have domains to block
if [ ${#DOMAINS[@]} -eq 0 ]; then
    zenity --error --title="No Domains Selected" \
           --text="You didn't select any domains or categories to block.\nPlease try again."
    exit 1
fi

# Show progress dialog
(
echo "10"; echo "# Creating backup of hosts file..."
sleep 0.5

# Backup the hosts file if we haven't already
if [ ! -f "/etc/hosts.hardblock.bak" ]; then
    cp /etc/hosts /etc/hosts.hardblock.bak
fi

echo "20"; echo "# Preparing block entries..."
sleep 0.5

# Create hosts file entries
BLOCK_ENTRIES=""
for domain in "${DOMAINS[@]}"; do
    BLOCK_ENTRIES+="127.0.0.1 $domain\n"
    BLOCK_ENTRIES+="::1 $domain\n"
done

echo "30"; echo "# Updating hosts file..."

# Remove previous blocks if they exist
if grep -q "# HARDBLOCK START" /etc/hosts; then
    sed -i '/# HARDBLOCK START/,/# HARDBLOCK END/d' /etc/hosts
fi

# Flag that we've modified the hosts file (for cleanup)
HOSTS_MODIFIED=true

# Add block entries to hosts file
echo -e "\n# HARDBLOCK START\n$BLOCK_ENTRIES# HARDBLOCK END" >> /etc/hosts

echo "40"; echo "# Setting up persistence..."

# Save end time for later retrieval
echo "$END_TIME" > "$LOCK_DIR/end_time"
touch "$LOCK_DIR/block_active"

echo "50"; echo "# Making hosts file immutable..."

# Make hosts file immutable (can't be changed even by root)
chattr +i /etc/hosts
HOSTS_IMMUTABLE=true

echo "60"; echo "# Creating unblock script..."

# Create unblock script that will be run by systemd timer
cat > "$LOCK_DIR/unblock.sh" << 'EOF'
#!/bin/bash
LOCK_DIR="/var/lib/hardblock"
END_TIME=$(cat "$LOCK_DIR/end_time" 2>/dev/null || echo "0")
CURRENT_TIME=$(date +%s)

if [ "$CURRENT_TIME" -ge "$END_TIME" ] || [ "$END_TIME" -eq "0" ]; then
    # Time's up, remove the block
    chattr -i /etc/hosts 2>/dev/null
    if [ -f "/etc/hosts.hardblock.bak" ]; then
        cp /etc/hosts.hardblock.bak /etc/hosts
    else
        # Fallback: remove the block entries
        sed -i '/# HARDBLOCK START/,/# HARDBLOCK END/d' /etc/hosts 2>/dev/null
    fi
    rm -f "$LOCK_DIR/block_active"
    rm -f "$LOCK_DIR/end_time"
    
    # Send notification
    if command -v notify-send &> /dev/null; then
        DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus notify-send -u normal "HardBlock" "Website block period has ended."
    fi
fi
EOF

chmod +x "$LOCK_DIR/unblock.sh"

echo "70"; echo "# Setting up systemd services..."

# Create a systemd service for unblocking
cat > /etc/systemd/system/hardblock-unblock.service << EOF
[Unit]
Description=HardBlock Website Unblocker
After=network.target

[Service]
Type=oneshot
ExecStart=$LOCK_DIR/unblock.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

# Create a systemd timer to check every minute
cat > /etc/systemd/system/hardblock-unblock.timer << EOF
[Unit]
Description=Run HardBlock unblock script every minute
After=network.target

[Timer]
OnBootSec=60
OnUnitActiveSec=60s
Unit=hardblock-unblock.service

[Install]
WantedBy=timers.target
EOF

# Flag that we've created systemd services (for cleanup)
SERVICES_CREATED=true

echo "80"; echo "# Enabling services..."

# Enable and start the timer
systemctl daemon-reload
systemctl enable hardblock-unblock.timer
systemctl start hardblock-unblock.timer

echo "90"; echo "# Scheduling backup unblock..."

# Schedule the unblock using at as a backup mechanism
# Use seconds to be precise
echo "$LOCK_DIR/unblock.sh" | at now + ${DURATION_SECONDS} seconds 2>/dev/null

echo "100"; echo "# Block successfully activated!"
sleep 1
) | zenity --progress \
           --title="Setting Up Website Block" \
           --text="Initializing..." \
           --percentage=0 \
           --auto-close \
           --no-cancel

# If progress dialog was canceled (unlikely due to --no-cancel),
# but handle it anyway for robustness
if [ $? -ne 0 ]; then
    cleanup
    exit 1
fi

# Format end time for display
END_TIME_FORMATTED=$(date -d "@$END_TIME" "+%a %b %d %H:%M:%S %Y")

# Create a desktop countdown timer app if user wants it
if zenity --question --title="Show Countdown" --text="Would you like to open a countdown timer window?"; then
    # Create countdown script
    COUNTDOWN_SCRIPT="$LOCK_DIR/countdown.sh"
    cat > "$COUNTDOWN_SCRIPT" << EOF
#!/bin/bash

# Countdown timer for HardBlock
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus

END_TIME=\$(cat "$LOCK_DIR/end_time" 2>/dev/null || echo "0")
WINDOW_TITLE="HardBlock Timer"

# Function to display time in a readable format
format_time() {
    local total_seconds=\$1
    local days=\$((total_seconds / 86400))
    local hours=\$(((total_seconds % 86400) / 3600))
    local minutes=\$(((total_seconds % 3600) / 60))
    local seconds=\$((total_seconds % 60))
    
    if [ \$days -gt 0 ]; then
        printf "%dd %02dh:%02dm:%02ds" \$days \$hours \$minutes \$seconds
    elif [ \$hours -gt 0 ]; then
        printf "%02dh:%02dm:%02ds" \$hours \$minutes \$seconds
    else
        printf "%02dm:%02ds" \$minutes \$seconds
    fi
}

# Create the timer window
yad --form \\
    --title="\$WINDOW_TITLE" \\
    --width=400 --height=200 \\
    --text="<span size='large'><b>⏰ Time remaining until websites unblock:</b></span>" \\
    --text-align=center \\
    --field="<span size='x-large' color='red'><b>00:00:00</b></span>":LBL \\
    --button="Close:1" \\
    --no-buttons \\
    --borders=20 \\
    --center \\
    --timeout=1 \\
    --timeout-indicator=bottom &

YAD_PID=\$!

# Update timer every second
while true; do
    NOW=\$(date +%s)
    REMAINING=\$((END_TIME - NOW))
    
    if [ "\$REMAINING" -le 0 ]; then
        # Show completion and exit
        kill \$YAD_PID 2>/dev/null
        yad --info --title="\$WINDOW_TITLE - Complete" \\
            --text="<span size='large'><b>✅ Website block has ended!</b></span>\n\nYou can now access all websites again." \\
            --button="Close:1" \\
            --center \\
            --borders=20
        exit 0
    fi
    
    # Format the remaining time
    TIME_DISPLAY=\$(format_time \$REMAINING)
    
    # Update the label
    echo "1:\$TIME_DISPLAY" > /tmp/hardblock_timer_\$\$
    yad --form-update 1 < /tmp/hardblock_timer_\$\$
    rm -f /tmp/hardblock_timer_\$\$
    
    # Check if YAD is still running
    if ! kill -0 \$YAD_PID 2>/dev/null; then
        exit 0
    fi
    
    sleep 1
done
EOF

    chmod +x "$COUNTDOWN_SCRIPT"
    
    # Make sure YAD is installed for a better GUI timer
    if ! command -v yad &>/dev/null; then
        # Try to install YAD if not available
        zenity --info --title="Installing Dependencies" --text="The timer needs YAD to display properly. Installing now..."
        apt-get update -qq && apt-get install -y yad || true
    fi
    
    # Try to run the timer
    if command -v yad &>/dev/null; then
        # Start the timer as the current user
        su $(logname) -c "$COUNTDOWN_SCRIPT" &
    else
        # Fallback to a terminal-based timer
        gnome-terminal -- bash -c "$COUNTDOWN_SCRIPT" 2>/dev/null || \
        xterm -e "$COUNTDOWN_SCRIPT" 2>/dev/null || \
        konsole -e "$COUNTDOWN_SCRIPT" 2>/dev/null &
    fi
fi

# Create a desktop notification
if command -v notify-send &>/dev/null; then
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus \
    notify-send -u critical "HardBlock Active" "Websites blocked until $(date -d "@$END_TIME" "+%H:%M:%S")" --icon=dialog-warning
fi

# Notify user of successful block
zenity --info --width=400 --title="Websites Blocked" \
    --text="<b>✅ Websites successfully blocked for $FORMATTED_DURATION</b>\n\nThe block is now <span color='red'><b>IRREVERSIBLE</b></span> until the timer ends.\n\nEven restarting your computer will not remove the block.\n\nTimer will expire at: <b>$END_TIME_FORMATTED</b>"

# Flush DNS cache to ensure blocks take effect immediately
if command -v systemd-resolve &> /dev/null; then
    systemd-resolve --flush-caches
elif command -v resolvectl &> /dev/null; then
    resolvectl flush-caches
elif [ -f /etc/init.d/dns-clean ]; then
    /etc/init.d/dns-clean start
elif command -v dscacheutil &> /dev/null; then
    dscacheutil -flushcache
fi

# We've reached the end successfully - disable the trap now
trap - SIGINT SIGTERM SIGHUP

exit 0
