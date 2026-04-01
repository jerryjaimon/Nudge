import json
import subprocess
import os
import sys

# --- Configuration ---
# User-provided ADB path
ADB_PATH = r"C:\Users\Jerry\Downloads\scrcpy-win64-v3.3.4\adb.exe"
PACKAGE_NAME = "com.example.nudge"
LOCAL_PATH = "health_dump.json"

# Filter Settings
FILTER_PKG_PREFIX = "com.sec.android.app.shealth"  # Set to None to show all sources
IGNORE_TYPES = [
    "HEART_RATE",
    # "RESTING_HEART_RATE",
    # "HEART_RATE_VARIABILITY_RMSSD",
    # Add other types to ignore here
]

def run_adb(command):
    try:
        # Use absolute path to adb
        result = subprocess.run([ADB_PATH] + command, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running ADB command: {' '.join(command)}")
        print(f"Stderr: {e.stderr}")
        return None
    except FileNotFoundError:
        print(f"ADB not found at: {ADB_PATH}")
        sys.exit(1)

def main():
    print(f"--- Samsung Health Diagnostic Tool ---")
    if FILTER_PKG_PREFIX:
        print(f"Filtering package: {FILTER_PKG_PREFIX}")
    print(f"Ignoring types: {', '.join(IGNORE_TYPES)}")
    
    devices = run_adb(["devices"])
    if not devices or len(devices.splitlines()) <= 1:
        print("No Android devices detected. Please connect your phone via USB and enable USB Debugging.")
        return

    print("Targeting device and extracting data...")

    cmd_copy = ["shell", "run-as", PACKAGE_NAME, "cat", "cache/health_dump.json"]
    raw_json = run_adb(cmd_copy)
    
    if not raw_json or raw_json.startswith("cat:"):
        print(f"Could not find health_dump.json for {PACKAGE_NAME}.")
        print("Please ensure you clicked 'Save for Python Analysis' in the Step Tracking screen of the Nudge app.")
        return

    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError:
        print("Error: Could not parse JSON data from device.")
        return

    if not data:
        print("No health data found in the dump.")
        return

    # Apply Filters
    filtered_data = []
    for p in data:
        source_name = p.get('source') or ""
        package_id = p.get('package') or ""
        
        # Filter by package prefix (check both source name and package id)
        if FILTER_PKG_PREFIX:
            if not source_name.startswith(FILTER_PKG_PREFIX) and not package_id.startswith(FILTER_PKG_PREFIX):
                continue
        
        # Filter by ignored types
        if p.get('type') in IGNORE_TYPES:
            continue
            
        filtered_data.append(p)

    output_lines = []
    output_lines.append(f"--- Samsung Health Diagnostic Results ---")
    output_lines.append(f"Found {len(data)} total points. Showing {len(filtered_data)} matching points.\n")
    header = f"{'TYPE':<20} | {'SOURCE':<25} | {'VALUE':<15} | {'FROM'}"
    output_lines.append(header)
    output_lines.append("-" * 80)

    workout_steps = 0
    total_steps = 0

    for p in filtered_data:
        p_type = p.get('type', 'Unknown')
        source = p.get('source', 'Unknown')
        package = p.get('package', '')
        val = p.get('value', {})
        val_str = ""
        
        # Prefer package ID for display if available, otherwise use source string
        display_source = package if package else source
        
        steps_val = 0
        if val.get('type') == 'numeric':
            if p_type == 'STEPS':
                steps_val = val.get('value', 0)
            val_str = f"{val.get('value'):.1f} {p.get('unit', '')}"
        elif val.get('type') == 'workout':
            steps_val = val.get('steps', 0)
            cals = val.get('calories', 0)
            if steps_val:
                val_str = f"{steps_val} (W)"
                workout_steps += 1
            else:
                val_str = f"{cals} kcal (W)"
        
        total_steps += steps_val
        line = f"{p_type[:20]:<20} | {display_source:<40} | {val_str:<15} | {p.get('from')}"
        output_lines.append(line)

    output_lines.append("\n--- Summary (Filtered) ---")
    output_lines.append(f"Total Points: {len(filtered_data)}")
    output_lines.append(f"Cumulative Steps in these points: {total_steps}")
    output_lines.append(f"Steps recorded inside Workouts: {workout_steps}")
    
    # Print to console
    for line in output_lines:
        print(line)
        
    # Save raw JSON for review
    with open(LOCAL_PATH, "w") as f:
        f.write(raw_json)
    print(f"[SUCCESS] Raw data saved to {LOCAL_PATH}")

    # Save to analysis file
    with open("health_analysis.txt", "w") as f:
        f.write("\n".join(output_lines))
    
    print("[SUCCESS] Results (filtered) saved to health_analysis.txt")

if __name__ == "__main__":
    main()
