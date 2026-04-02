"""
Test script for Enhanced Pain Scale in GastroGuard Enhanced v3.0
Demonstrates the detailed pain scale with functional impact and symptoms
"""

from gastroguard_enhanced_v3 import SYMPTOM_SCALES, generate_smart_remedy_suggestions
from datetime import datetime
import pandas as pd

def test_enhanced_pain_scale():
    """Test the enhanced pain scale structure and content"""
    print("=== TESTING ENHANCED PAIN SCALE ===")
    
    pain_scale = SYMPTOM_SCALES["pain_level"]
    print(f"Scale Name: {pain_scale['name']}")
    print(f"Description: {pain_scale['description']}")
    print(f"Medical Context: {pain_scale['medical_context']}")
    
    print("\nEnhanced Pain Scale with Detailed Descriptions:")
    print("=" * 80)
    
    for value in range(11):
        if value in pain_scale['detailed_descriptions']:
            detail = pain_scale['detailed_descriptions'][value]
            print(f"\nScore {value}: {detail['label']}")
            print(f"  Functional Impact: {detail['functional_impact']}")
            print(f"  Common Qualities: {detail['common_qualities']}")
            print(f"  Additional Symptoms: {detail['additional_symptoms']}")
            print("-" * 60)

def test_pain_scale_suggestions():
    """Test smart suggestions with different pain levels"""
    print("\n=== TESTING PAIN SCALE SUGGESTIONS ===")
    
    # Create sample data
    sample_data = pd.DataFrame({
        'Time': [datetime.now().strftime("%Y-%m-%d %H:%M:%S")],
        'Remedy': ['Ginger tea'],
        'Pain Level': [5]
    })
    
    # Test different pain levels
    test_pain_levels = [0, 2, 4, 6, 8, 10]
    
    for pain_level in test_pain_levels:
        print(f"\nPain Level {pain_level} Suggestions:")
        print("-" * 40)
        
        suggestions = generate_smart_remedy_suggestions(
            sample_data, 
            current_pain=pain_level, 
            current_stress=5, 
            time_of_day=datetime.now(), 
            condition_type="gastritis"
        )
        
        # Filter pain-specific suggestions
        pain_suggestions = [s for s in suggestions if any(keyword in s.lower() 
                            for keyword in ['immediate', 'consider', 'excellent', 'monitor', 'emergency'])]
        
        for i, suggestion in enumerate(pain_suggestions[:3], 1):
            print(f"  {i}. {suggestion}")

def test_pain_scale_categories():
    """Test pain scale categorization"""
    print("\n=== TESTING PAIN SCALE CATEGORIES ===")
    
    pain_scale = SYMPTOM_SCALES["pain_level"]
    
    # Categorize pain levels
    categories = {
        "No Pain": [0],
        "Mild Pain": [1, 2, 3],
        "Moderate Pain": [4, 5, 6],
        "Severe Pain": [7, 8],
        "Emergency Pain": [9, 10]
    }
    
    for category, levels in categories.items():
        print(f"\n{category} (Levels {levels}):")
        for level in levels:
            if level in pain_scale['detailed_descriptions']:
                detail = pain_scale['detailed_descriptions'][level]
                print(f"  {level}: {detail['label']} - {detail['functional_impact']}")

def test_pain_scale_medical_guidance():
    """Test medical guidance based on pain levels"""
    print("\n=== TESTING MEDICAL GUIDANCE ===")
    
    pain_scale = SYMPTOM_SCALES["pain_level"]
    
    print("Medical Guidance by Pain Level:")
    print("=" * 50)
    
    for value in range(11):
        if value in pain_scale['detailed_descriptions']:
            detail = pain_scale['detailed_descriptions'][value]
            
            # Determine medical guidance
            if value >= 9:
                guidance = "🚨 EMERGENCY - Call doctor or go to ER immediately"
            elif value >= 7:
                guidance = "⚠️ URGENT - Contact healthcare provider today"
            elif value >= 5:
                guidance = "📞 Consider calling healthcare provider"
            elif value >= 3:
                guidance = "👀 Monitor closely, consider OTC remedies"
            elif value >= 1:
                guidance = "✅ Manage with lifestyle changes"
            else:
                guidance = "🎉 Continue current management strategy"
            
            print(f"Level {value} ({detail['label']}): {guidance}")

def test_pain_scale_functional_impact():
    """Test functional impact descriptions"""
    print("\n=== TESTING FUNCTIONAL IMPACT DESCRIPTIONS ===")
    
    pain_scale = SYMPTOM_SCALES["pain_level"]
    
    print("Functional Impact Analysis:")
    print("=" * 40)
    
    for value in range(11):
        if value in pain_scale['detailed_descriptions']:
            detail = pain_scale['detailed_descriptions'][value]
            impact = detail['functional_impact']
            
            # Categorize functional impact
            if "emergency" in impact.lower() or "cannot talk" in impact.lower():
                impact_level = "CRITICAL"
            elif "unable to work" in impact.lower() or "doubled over" in impact.lower():
                impact_level = "SEVERE"
            elif "interferes" in impact.lower() or "disrupts" in impact.lower():
                impact_level = "MODERATE"
            elif "affects focus" in impact.lower() or "distracting" in impact.lower():
                impact_level = "MILD"
            else:
                impact_level = "MINIMAL"
            
            print(f"Level {value}: {impact_level} - {impact}")

def test_pain_scale_symptom_patterns():
    """Test symptom patterns in the pain scale"""
    print("\n=== TESTING SYMPTOM PATTERNS ===")
    
    pain_scale = SYMPTOM_SCALES["pain_level"]
    
    # Collect all symptoms mentioned
    all_symptoms = set()
    for value in range(11):
        if value in pain_scale['detailed_descriptions']:
            detail = pain_scale['detailed_descriptions'][value]
            symptoms = detail['additional_symptoms'].lower()
            if symptoms != "none":
                # Split by common delimiters
                symptom_list = [s.strip() for s in symptoms.replace(',', ';').split(';')]
                all_symptoms.update(symptom_list)
    
    print("All symptoms mentioned in pain scale:")
    for symptom in sorted(all_symptoms):
        if symptom.strip():
            print(f"  • {symptom.strip()}")

def main():
    """Run all enhanced pain scale tests"""
    print("GastroGuard Enhanced v3.0 - Enhanced Pain Scale Testing")
    print("=" * 70)
    
    test_enhanced_pain_scale()
    test_pain_scale_suggestions()
    test_pain_scale_categories()
    test_pain_scale_medical_guidance()
    test_pain_scale_functional_impact()
    test_pain_scale_symptom_patterns()
    
    print("\n" + "=" * 70)
    print("All enhanced pain scale tests completed!")
    print("\nEnhanced Pain Scale Features:")
    print("✅ Detailed functional impact descriptions")
    print("✅ Common pain qualities for each level")
    print("✅ Additional symptoms for each level")
    print("✅ Medical guidance based on pain severity")
    print("✅ Smart suggestions adapted to pain levels")
    print("✅ Quick reference tooltip in GUI")
    print("✅ Comprehensive scale display with scrollable interface")
    print("✅ Emergency-level pain identification")
    print("✅ Functional impact categorization")

if __name__ == "__main__":
    main()
