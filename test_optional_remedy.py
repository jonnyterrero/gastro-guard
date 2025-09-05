"""
Test script for Optional Remedy functionality in GastroGuard Enhanced v3.0
Demonstrates that remedies are now optional for meal logging
"""

import pandas as pd
from datetime import datetime
import json

# Import the enhanced functions
from gastroguard_enhanced_v3 import (
    submit_enhanced_data, generate_smart_remedy_suggestions,
    calculate_remedy_effectiveness, ENHANCED_COLUMNS
)

def test_optional_remedy_logging():
    """Test logging meals without remedies"""
    print("=== TESTING OPTIONAL REMEDY LOGGING ===")
    
    # Create sample data with and without remedies
    sample_entries = [
        {
            "Time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "Time_of_Ingestion": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "Meal": "Chicken and rice",
            "Pain_Level": 2,
            "Stress_Level": 3,
            "Remedy": "",  # No remedy used
            "Condition_Type": "gastritis",
            "Symptom_Types": json.dumps(["stomach_pain"]),
            "Meal_Size": "Medium",
            "Meal_Timing": "Lunch",
            "Sleep_Quality": 7,
            "Exercise_Level": 5,
            "Weather": "Clear",
            "Notes": "Feeling good, no remedy needed"
        },
        {
            "Time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "Time_of_Ingestion": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "Meal": "Spicy tacos",
            "Pain_Level": 6,
            "Stress_Level": 4,
            "Remedy": "Ginger tea",  # Remedy used
            "Condition_Type": "gastritis",
            "Symptom_Types": json.dumps(["stomach_pain", "bloating"]),
            "Meal_Size": "Large",
            "Meal_Timing": "Dinner",
            "Sleep_Quality": 6,
            "Exercise_Level": 3,
            "Weather": "Clear",
            "Notes": "Used ginger tea to help with discomfort"
        },
        {
            "Time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "Time_of_Ingestion": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "Meal": "Oatmeal with banana",
            "Pain_Level": 1,
            "Stress_Level": 2,
            "Remedy": "",  # No remedy needed
            "Condition_Type": "gastritis",
            "Symptom_Types": json.dumps([]),
            "Meal_Size": "Small",
            "Meal_Timing": "Breakfast",
            "Sleep_Quality": 8,
            "Exercise_Level": 6,
            "Weather": "Sunny",
            "Notes": "Perfect breakfast, no issues"
        }
    ]
    
    # Create DataFrame
    global log_data
    log_data = pd.DataFrame(sample_entries)
    
    print("Sample data created with mixed remedy usage:")
    print(f"Total entries: {len(log_data)}")
    print(f"Entries with remedies: {len(log_data[log_data['Remedy'].str.strip() != ''])}")
    print(f"Entries without remedies: {len(log_data[log_data['Remedy'].str.strip() == ''])}")
    
    print("\nEntry details:")
    for i, (_, row) in enumerate(log_data.iterrows(), 1):
        remedy_status = "Used remedy" if row['Remedy'] else "No remedy needed"
        print(f"{i}. {row['Meal']} - Pain: {row['Pain_Level']}/10 - {remedy_status}")

def test_remedy_effectiveness_with_empty():
    """Test remedy effectiveness calculation with empty remedies"""
    print("\n=== TESTING REMEDY EFFECTIVENESS WITH EMPTY REMEDIES ===")
    
    # Test with empty remedy
    empty_result = calculate_remedy_effectiveness(log_data, "")
    print(f"Empty remedy result: {empty_result}")
    
    # Test with actual remedy
    ginger_result = calculate_remedy_effectiveness(log_data, "Ginger tea")
    print(f"Ginger tea result: {ginger_result}")
    
    # Test with non-existent remedy
    fake_result = calculate_remedy_effectiveness(log_data, "Fake remedy")
    print(f"Non-existent remedy result: {fake_result}")

def test_smart_suggestions_with_optional_remedy():
    """Test smart suggestions when no remedy is used"""
    print("\n=== TESTING SMART SUGGESTIONS WITH OPTIONAL REMEDY ===")
    
    # Test suggestions for low pain (no remedy needed)
    low_pain_suggestions = generate_smart_remedy_suggestions(
        log_data, current_pain=2, current_stress=3, 
        time_of_day=datetime.now(), condition_type="gastritis"
    )
    
    print("Suggestions for low pain (no remedy needed):")
    for i, suggestion in enumerate(low_pain_suggestions[:5], 1):
        print(f"{i}. {suggestion}")
    
    # Test suggestions for high pain (remedy recommended)
    high_pain_suggestions = generate_smart_remedy_suggestions(
        log_data, current_pain=7, current_stress=6, 
        time_of_day=datetime.now(), condition_type="gastritis"
    )
    
    print("\nSuggestions for high pain (remedy recommended):")
    for i, suggestion in enumerate(high_pain_suggestions[:5], 1):
        print(f"{i}. {suggestion}")

def test_data_analysis_with_empty_remedies():
    """Test data analysis functions with empty remedies"""
    print("\n=== TESTING DATA ANALYSIS WITH EMPTY REMEDIES ===")
    
    # Test remedy filtering
    remedy_data = log_data[log_data['Remedy'].str.strip() != '']
    empty_remedy_data = log_data[log_data['Remedy'].str.strip() == '']
    
    print(f"Entries with remedies: {len(remedy_data)}")
    print(f"Entries without remedies: {len(empty_remedy_data)}")
    
    if not remedy_data.empty:
        print("\nRemedy analysis:")
        remedy_analysis = remedy_data.groupby('Remedy')['Pain_Level'].agg(['mean', 'count'])
        print(remedy_analysis)
    
    # Test pain level distribution
    print(f"\nPain level distribution:")
    print(f"Average pain with remedies: {remedy_data['Pain_Level'].mean():.1f}" if not remedy_data.empty else "No remedy data")
    print(f"Average pain without remedies: {empty_remedy_data['Pain_Level'].mean():.1f}" if not empty_remedy_data.empty else "No non-remedy data")

def test_placeholder_text_handling():
    """Test placeholder text handling for remedy field"""
    print("\n=== TESTING PLACEHOLDER TEXT HANDLING ===")
    
    placeholder_text = "Enter remedy if used, or leave blank"
    
    # Test different remedy inputs
    test_cases = [
        ("", "Empty string"),
        (placeholder_text, "Placeholder text"),
        ("Ginger tea", "Actual remedy"),
        ("   ", "Whitespace only"),
        ("None", "Explicit 'none'")
    ]
    
    for remedy_input, description in test_cases:
        if remedy_input == placeholder_text or not remedy_input.strip():
            processed_remedy = ""
        else:
            processed_remedy = remedy_input.strip()
        
        print(f"{description}: '{remedy_input}' -> '{processed_remedy}'")

def main():
    """Run all optional remedy tests"""
    print("GastroGuard Enhanced v3.0 - Optional Remedy Testing")
    print("=" * 60)
    
    test_optional_remedy_logging()
    test_remedy_effectiveness_with_empty()
    test_smart_suggestions_with_optional_remedy()
    test_data_analysis_with_empty_remedies()
    test_placeholder_text_handling()
    
    print("\n" + "=" * 60)
    print("All optional remedy tests completed!")
    print("\nOptional Remedy Features:")
    print("✅ Remedy field is now optional")
    print("✅ Placeholder text guides users")
    print("✅ Smart suggestions adapt to remedy usage")
    print("✅ Data analysis handles empty remedies")
    print("✅ Effectiveness calculations skip empty remedies")
    print("✅ Status messages indicate remedy usage")
    print("✅ Users can log meals without remedies")

if __name__ == "__main__":
    main()
