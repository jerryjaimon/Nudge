import requests
import json
import os

url = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
try:
    response = requests.get(url)
    data = response.json()

    # Generate Dart file
    dart_content = "class ExerciseDetailData {\n"
    dart_content += "  static const Map<String, Map<String, dynamic>> detailedData = {\n"
    
    for item in data:
        name = (item.get('name', 'unknown')).lower().replace("'", "\\'")
        instr_list = item.get('instructions', [])
        if not instr_list: instr_list = []
        instructions = " ".join(instr_list).replace("'", "\\'").replace("\n", " ")
        
        category = (item.get('category', '') or '').replace("'", "\\'")
        equipment = (item.get('equipment', '') or '').replace("'", "\\'")
        
        muscles = item.get('primaryMuscles', [])
        if not muscles: muscles = []
        primary = ", ".join(muscles).replace("'", "\\'")
        
        dart_content += f"    '{name}': {{\n"
        dart_content += f"      'instructions': r'''{instructions}''',\n"
        dart_content += f"      'category': '{category}',\n"
        dart_content += f"      'equipment': '{equipment}',\n"
        dart_content += f"      'primaryMuscles': '{primary}',\n"
        dart_content += "    },\n"
        
    dart_content += "  };\n\n"
    dart_content += "  static Map<String, dynamic>? getDetails(String name) {\n"
    dart_content += "    return detailedData[name.toLowerCase()];\n"
    dart_content += "  }\n"
    dart_content += "}\n"

    output_path = "f:/Development/Nudge/lib/screens/gym/exercise_data.dart"
    with open(output_path, 'w') as f:
        f.write(dart_content)

    print(f"Generated Dart data for {len(data)} exercises to {output_path}")
except Exception as e:
    import traceback
    traceback.print_exc()
    print(f"Error: {e}")
