"""
Since your phone's Health Connect data is native to the Android device, a python script running on your PC cannot directly query Health Connect unless the phone acts as an ADB server for a debug app, or the data is explicitly exported from your device.

However, since our Flutter app (Nudge) uses Hive to store all fetched health data locally on your device, we can query that! 

If you download the `gym_box.hive` file from your device (typically under Android/data/com.example.nudge/files/ or using ADB), you can use this script to read the raw health history that the Nudge app parsed from Health Connect.

Instructions to get the file via ADB:
1. Connect your phone via USB
2. Run in terminal: adb shell run-as com.example.nudge cp files/gym_box.hive /sdcard/Download/
3. Run in terminal: adb pull /sdcard/Download/gym_box.hive .
"""

# Note: Python cannot natively read .hive files out-of-the-box easily without an adapter.
# It's highly recommended to just add a debug print / export to CSV directly within the Flutter app.

print("Please run the in-app CSV exporter instead for the easiest access to this data.")
