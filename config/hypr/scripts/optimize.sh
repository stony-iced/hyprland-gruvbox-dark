#!/bin/bash

# Hyprland Performance Optimization Script
# Save as ~/.config/hypr/scripts/optimize.sh
# Run: bash ~/.config/hypr/scripts/optimize.sh

set -e

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Hyprland Gruvbox Performance Optimizer ===${NC}\n"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# 1. Check GPU
echo -e "${BLUE}[1/8]${NC} Checking GPU..."
if lspci | grep -i "nvidia" >/dev/null; then
    echo "  NVIDIA GPU detected"
    if command_exists nvidia-smi; then
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
        print_status 0 "NVIDIA drivers installed"
    else
        print_status 1 "NVIDIA drivers not found - install nvidia-dkms"
    fi
elif lspci | grep -i "amd" >/dev/null; then
    echo "  AMD GPU detected"
    print_status 0 "AMD GPU found"
else
    echo "  Intel/Other GPU detected"
    print_status 0 "Integrated GPU found"
fi

# 2. Check CPU Governor
echo -e "\n${BLUE}[2/8]${NC} Checking CPU Governor..."
GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")
echo "  Current Governor: $GOVERNOR"
if [ "$GOVERNOR" = "performance" ] || [ "$GOVERNOR" = "schedutil" ]; then
    print_status 0 "Good governor for performance"
else
    echo "  Consider setting to 'performance' or 'schedutil'"
    echo "  Run: echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
fi

# 3. Check Swap
echo -e "\n${BLUE}[3/8]${NC} Checking Swap Configuration..."
SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
SWAPPINESS=$(cat /proc/sys/vm/swappiness)
echo "  Swap: $SWAP_USED / $SWAP_TOTAL"
echo "  Swappiness: $SWAPPINESS"
if [ "$SWAPPINESS" -le 10 ]; then
    print_status 0 "Low swappiness is good for performance"
else
    echo "  Consider lowering swappiness: echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf"
fi

# 4. Check Running Services
echo -e "\n${BLUE}[4/8]${NC} Checking Essential Services..."
services=("Hyprland" "waybar" "dunst" "hypridle")
for service in "${services[@]}"; do
    if pgrep -x "$service" >/dev/null; then
        print_status 0 "$service is running"
    else
        print_status 1 "$service is not running"
    fi
done

# 5. Check Memory Usage
echo -e "\n${BLUE}[5/8]${NC} Checking Memory Usage..."
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
echo "  Memory: $MEM_USED / $MEM_TOTAL ($MEM_PERCENT%)"
if [ "$MEM_PERCENT" -lt 80 ]; then
    print_status 0 "Memory usage is healthy"
else
    print_status 1 "High memory usage - consider closing some applications"
fi

# 6. Check Display Server
echo -e "\n${BLUE}[6/8]${NC} Checking Display Configuration..."
if [ -n "$WAYLAND_DISPLAY" ]; then
    print_status 0 "Running on Wayland"
    echo "  Display: $WAYLAND_DISPLAY"
else
    print_status 1 "Not running on Wayland"
fi

# Check for XWayland
if command_exists Xwayland; then
    if pgrep -x "Xwayland" >/dev/null; then
        print_status 0 "XWayland is available for legacy apps"
    fi
fi

# 7. Optimize Hyprland Config
echo -e "\n${BLUE}[7/8]${NC} Checking Hyprland Optimizations..."
CONFIG="$HOME/.config/hypr/hyprland.conf"
if [ -f "$CONFIG" ]; then
    print_status 0 "Hyprland config found"

    # Check for VRR
    if grep -q "vrr = 1" "$CONFIG" || grep -q "vrr = 2" "$CONFIG"; then
        print_status 0 "VRR (Variable Refresh Rate) enabled"
    else
        echo "  Consider enabling VRR: vrr = 1 in misc section"
    fi

    # Check for VFR
    if grep -q "vfr = true" "$CONFIG"; then
        print_status 0 "VFR (Variable Frame Rate) enabled"
    else
        echo "  Consider enabling VFR: vfr = true in misc section"
    fi
else
    print_status 1 "Hyprland config not found at $CONFIG"
fi

# 8. Performance Recommendations
echo -e "\n${BLUE}[8/8]${NC} Performance Recommendations..."

# Create optimization suggestions file
SUGGESTIONS_FILE="/tmp/hyprland_optimizations.txt"
cat > "$SUGGESTIONS_FILE" << 'EOF'
=== Hyprland Performance Optimizations ===

1. NVIDIA Users:
   - Add to hyprland.conf:
     env = LIBVA_DRIVER_NAME,nvidia
     env = __GLX_VENDOR_LIBRARY_NAME,nvidia
     env = WLR_NO_HARDWARE_CURSORS,1

2. Gaming Performance:
   - Install: sudo pacman -S gamemode
   - Launch games with: gamemoderun %command%
   - Add immediate window rule for games

3. Reduce Motion:
   - Lower animation speeds in hyprland.conf
   - Reduce blur passes from 3 to 2
   - Disable shadows for better FPS

4. Memory Optimization:
   - Close unused applications
   - Use lighter alternatives (alacritty vs kitty)
   - Disable window swallowing if not needed

5. CPU Optimization:
   - Set CPU governor to performance:
     echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
   - Enable TLP for laptops: sudo pacman -S tlp

6. Compositor Tweaks:
   - misc { vfr = true; vrr = 1; }
   - debug { disable_logs = true; damage_tracking = 2; }
   - Reduce shadow_range and blur size

7. Startup Optimization:
   - Remove unnecessary exec-once entries
   - Use systemd services for background apps
   - Delay non-critical autostart apps

8. Monitor Setup:
   - Use native resolution
   - Match refresh rate: monitor=,preferred,auto,1
   - Enable adaptive sync if available

9. Background Processes:
   - Check systemd services: systemctl --user list-units
   - Disable unused services
   - Monitor with: btop or htop

10. Kernel Parameters:
    - Add to /etc/default/grub:
      GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=off"
    - Update grub: sudo grub-mkconfig -o /boot/grub/grub.cfg

EOF

cat "$SUGGESTIONS_FILE"
print_status 0 "Saved suggestions to $SUGGESTIONS_FILE"

# System Information Summary
echo -e "\n${YELLOW}=== System Summary ===${NC}"
echo "CPU: $(lscpu | grep "Model name" | cut -d':' -f2 | xargs)"
echo "Cores: $(nproc) cores"
echo "Memory: $MEM_TOTAL"
echo "GPU: $(lspci | grep -i 'vga\|3d' | cut -d':' -f3 | xargs)"
echo "Kernel: $(uname -r)"
echo "Hyprland Version: $(hyprctl version | head -n1 | awk '{print $2}')"

# Final Performance Score
SCORE=0
[ "$GOVERNOR" = "performance" ] && SCORE=$((SCORE + 15))
[ "$SWAPPINESS" -le 10 ] && SCORE=$((SCORE + 10))
[ "$MEM_PERCENT" -lt 80 ] && SCORE=$((SCORE + 20))
pgrep -x "Hyprland" >/dev/null && SCORE=$((SCORE + 20))
pgrep -x "waybar" >/dev/null && SCORE=$((SCORE + 10))
[ -n "$WAYLAND_DISPLAY" ] && SCORE=$((SCORE + 25))

echo -e "\n${YELLOW}=== Performance Score: $SCORE/100 ===${NC}"
if [ $SCORE -ge 80 ]; then
    echo -e "${GREEN}Excellent! Your system is well optimized.${NC}"
elif [ $SCORE -ge 60 ]; then
    echo -e "${YELLOW}Good! Consider applying some recommendations above.${NC}"
else
    echo -e "${RED}Needs improvement. Please check the recommendations.${NC}"
fi

echo -e "\n${GREEN}Optimization check complete!${NC}"
echo "Review suggestions in: $SUGGESTIONS_FILE"
