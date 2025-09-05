"""
GastroGuard Enhanced v3.0 - Comprehensive Chronic Stomach Condition Management System

MISSION STATEMENT:
GastroGuard is a comprehensive digital health assistant designed to help individuals
manage chronic stomach conditions including gastritis, GERD, IBS, dyspepsia, and
food sensitivities. Our mission is to empower users with data-driven insights,
personalized tracking, and evidence-based recommendations to improve their quality
of life through better understanding of their condition patterns and effective
management strategies.

PURPOSE:
- Track and analyze symptoms, triggers, and remedies across multiple chronic conditions
- Provide personalized insights based on individual data patterns
- Support evidence-based decision making for condition management
- Enable healthcare provider collaboration through comprehensive data export
- Promote proactive health management through predictive analytics

TARGET CONDITIONS:
- Gastritis (acute and chronic)
- Gastroesophageal Reflux Disease (GERD)
- Irritable Bowel Syndrome (IBS)
- Functional Dyspepsia
- Food Sensitivities and Intolerances
- Inflammatory Bowel Disease (IBD) support
"""

import tkinter as tk
from tkinter import ttk, messagebox
from datetime import datetime, timedelta
import pandas as pd
import matplotlib.pyplot as plt
from scipy.integrate import solve_ivp
import numpy as np
from tkcalendar import DateEntry
import calendar
import json
import os

# Streamlit imports (for web dashboard)
try:
    import streamlit as st
    import plotly.express as px
    import plotly.graph_objects as go
    from plotly.subplots import make_subplots
    import io
    import base64

    STREAMLIT_AVAILABLE = True
except ImportError:
    STREAMLIT_AVAILABLE = False

# ============================================================================
# SYMPTOM SCALES AND DEFINITIONS
# ============================================================================

SYMPTOM_SCALES = {
    "pain_level": {
        "name": "Pain Level Scale",
        "description": "Standardized 0-10 pain assessment scale",
        "scale": {
            0: "No pain - Complete comfort",
            1: "Minimal pain - Barely noticeable",
            2: "Mild pain - Noticeable but not bothersome",
            3: "Mild pain - Slightly bothersome",
            4: "Moderate pain - Bothersome but manageable",
            5: "Moderate pain - Distracting, affects daily activities",
            6: "Moderate-severe pain - Difficult to ignore, limits activities",
            7: "Severe pain - Dominates senses, limits concentration",
            8: "Intense pain - Physical activity severely limited",
            9: "Excruciating pain - Unable to speak, bedridden",
            10: "Unbearable pain - Emergency medical attention needed"
        },
        "medical_context": "Based on WHO pain ladder and clinical pain assessment tools"
    },

    "stress_level": {
        "name": "Stress Level Scale",
        "description": "Perceived stress scale for gastrointestinal symptom correlation",
        "scale": {
            0: "No stress - Completely relaxed",
            1: "Minimal stress - Slightly tense",
            2: "Mild stress - Noticeable tension",
            3: "Mild stress - Some worry or anxiety",
            4: "Moderate stress - Feeling pressured",
            5: "Moderate stress - Significant worry affecting mood",
            6: "Moderate-severe stress - Difficulty concentrating",
            7: "Severe stress - Feeling overwhelmed",
            8: "Intense stress - Panic or extreme anxiety",
            9: "Extreme stress - Unable to function normally",
            10: "Crisis stress - Immediate intervention needed"
        },
        "medical_context": "Correlates with cortisol levels and GI symptom exacerbation"
    },

    "symptom_severity": {
        "name": "Symptom Severity Scale",
        "description": "Comprehensive symptom assessment for chronic GI conditions",
        "scale": {
            0: "No symptoms - Normal function",
            1: "Minimal symptoms - Barely noticeable",
            2: "Mild symptoms - Slight discomfort",
            3: "Mild symptoms - Noticeable but manageable",
            4: "Moderate symptoms - Affects daily activities",
            5: "Moderate symptoms - Significant impact on quality of life",
            6: "Moderate-severe symptoms - Frequent disruption",
            7: "Severe symptoms - Major lifestyle limitations",
            8: "Intense symptoms - Constant discomfort",
            9: "Extreme symptoms - Debilitating",
            10: "Critical symptoms - Emergency care needed"
        },
        "medical_context": "Adapted from Rome IV criteria for functional GI disorders"
    }
}

# ============================================================================
# CONDITION DEFINITIONS AND SYMPTOM TYPES
# ============================================================================

CONDITION_DEFINITIONS = {
    "gastritis": {
        "name": "Gastritis",
        "description": "Inflammation of the stomach lining",
        "common_symptoms": ["stomach_pain", "nausea", "vomiting", "bloating", "loss_of_appetite"],
        "triggers": ["spicy_foods", "alcohol", "stress", "medications", "infections"],
        "typical_patterns": "Pain often occurs 30-60 minutes after eating"
    },

    "gerd": {
        "name": "Gastroesophageal Reflux Disease (GERD)",
        "description": "Chronic acid reflux affecting the esophagus",
        "common_symptoms": ["heartburn", "regurgitation", "chest_pain", "difficulty_swallowing", "chronic_cough"],
        "triggers": ["large_meals", "lying_down_after_eating", "certain_foods", "obesity", "smoking"],
        "typical_patterns": "Symptoms worsen when lying down or bending over"
    },

    "ibs": {
        "name": "Irritable Bowel Syndrome (IBS)",
        "description": "Functional disorder affecting the large intestine",
        "common_symptoms": ["abdominal_pain", "bloating", "diarrhea", "constipation", "gas"],
        "triggers": ["stress", "certain_foods", "hormonal_changes", "gut_microbiome_imbalance"],
        "typical_patterns": "Symptoms often improve after bowel movements"
    },

    "dyspepsia": {
        "name": "Functional Dyspepsia",
        "description": "Chronic indigestion without obvious cause",
        "common_symptoms": ["upper_abdominal_pain", "early_satiety", "bloating", "nausea", "belching"],
        "triggers": ["stress", "irregular_meals", "certain_foods", "smoking", "alcohol"],
        "typical_patterns": "Symptoms often occur during or after meals"
    },

    "food_sensitivity": {
        "name": "Food Sensitivity/Intolerance",
        "description": "Adverse reactions to specific foods",
        "common_symptoms": ["bloating", "gas", "diarrhea", "stomach_pain", "nausea"],
        "triggers": ["specific_foods", "food_additives", "lactose", "gluten", "fructose"],
        "typical_patterns": "Symptoms occur 2-6 hours after consuming trigger foods"
    }
}

SYMPTOM_TYPES = {
    "stomach_pain": "Pain or discomfort in the stomach area",
    "heartburn": "Burning sensation in chest/throat",
    "nausea": "Feeling of sickness with inclination to vomit",
    "vomiting": "Forceful expulsion of stomach contents",
    "bloating": "Feeling of fullness or swelling in abdomen",
    "gas": "Excessive flatulence or belching",
    "diarrhea": "Loose, watery stools",
    "constipation": "Difficulty or infrequent bowel movements",
    "loss_of_appetite": "Reduced desire to eat",
    "early_satiety": "Feeling full quickly after starting to eat",
    "regurgitation": "Backflow of stomach contents into mouth",
    "chest_pain": "Pain or discomfort in chest area",
    "difficulty_swallowing": "Trouble moving food from mouth to stomach",
    "chronic_cough": "Persistent cough, often worse at night",
    "belching": "Expulsion of gas from stomach through mouth"
}

# ============================================================================
# REMEDY TRACKER LOGIC AND EFFECTIVENESS ALGORITHMS
# ============================================================================

REMEDY_CATEGORIES = {
    "medications": {
        "antacids": ["Tums", "Rolaids", "Mylanta", "Maalox"],
        "h2_blockers": ["Pepcid", "Zantac", "Tagamet"],
        "ppis": ["Prilosec", "Nexium", "Protonix", "Prevacid"],
        "prokinetics": ["Reglan", "Domperidone"],
        "antispasmodics": ["Bentyl", "Levsin", "Hyoscyamine"]
    },

    "natural_remedies": {
        "herbal": ["Ginger", "Peppermint", "Chamomile", "Licorice root", "Slippery elm"],
        "supplements": ["Probiotics", "Digestive enzymes", "DGL", "Aloe vera", "L-glutamine"],
        "lifestyle": ["Deep breathing", "Meditation", "Yoga", "Walking", "Heat therapy"]
    },

    "dietary_modifications": {
        "avoid": ["Spicy foods", "Acidic foods", "Large meals", "Late night eating"],
        "include": ["Small frequent meals", "Bland foods", "High fiber", "Probiotic foods"],
        "timing": ["Eat slowly", "Chew thoroughly", "Don't lie down after eating"]
    }
}


def calculate_remedy_effectiveness(data, remedy_name):
    """
    Calculate remedy effectiveness based on pain reduction and consistency

    Algorithm:
    1. Filter data for specific remedy
    2. Calculate average pain level before and after remedy use
    3. Factor in frequency of use and consistency of results
    4. Weight recent usage more heavily
    5. Consider stress levels and other factors
    """
    remedy_data = data[data['Remedy'] == remedy_name].copy()

    if len(remedy_data) < 2:
        return {"effectiveness": 0, "confidence": "low", "recommendation": "insufficient_data"}

    # Calculate pain reduction
    avg_pain = remedy_data['Pain Level'].mean()
    pain_std = remedy_data['Pain Level'].std()

    # Calculate consistency (lower std = more consistent)
    consistency_score = max(0, 1 - (pain_std / 10))

    # Weight recent usage
    if 'Time' in remedy_data.columns:
        remedy_data['Time'] = pd.to_datetime(remedy_data['Time'])
        recent_weight = 1.2  # 20% boost for recent usage
        old_weight = 0.8  # 20% reduction for older usage

        # Apply time-based weighting
        now = datetime.now()
        remedy_data['days_ago'] = (now - remedy_data['Time']).dt.days
        remedy_data['weight'] = remedy_data['days_ago'].apply(
            lambda x: recent_weight if x <= 7 else old_weight
        )

        weighted_pain = (remedy_data['Pain Level'] * remedy_data['weight']).sum() / remedy_data['weight'].sum()
    else:
        weighted_pain = avg_pain

    # Calculate effectiveness (lower pain = higher effectiveness)
    effectiveness = max(0, (10 - weighted_pain) / 10)

    # Factor in consistency
    final_effectiveness = effectiveness * (0.7 + 0.3 * consistency_score)

    # Determine confidence level
    if len(remedy_data) >= 10:
        confidence = "high"
    elif len(remedy_data) >= 5:
        confidence = "medium"
    else:
        confidence = "low"

    # Generate recommendation
    if final_effectiveness >= 0.8:
        recommendation = "highly_effective"
    elif final_effectiveness >= 0.6:
        recommendation = "effective"
    elif final_effectiveness >= 0.4:
        recommendation = "moderately_effective"
    else:
        recommendation = "ineffective"

    return {
        "effectiveness": final_effectiveness,
        "confidence": confidence,
        "recommendation": recommendation,
        "avg_pain": avg_pain,
        "consistency": consistency_score,
        "usage_count": len(remedy_data)
    }


# ============================================================================
# SMART REMEDY SUGGESTION ENGINE
# ============================================================================

def generate_smart_remedy_suggestions(data, current_pain, current_stress, time_of_day, condition_type="gastritis"):
    """
    Generate personalized remedy suggestions based on:
    - Current symptoms
    - Time of day
    - Stress levels
    - Historical effectiveness
    - Condition-specific recommendations
    - User profile (medications, allergies, conditions)
    """
    suggestions = []

    # Check for medication interactions and allergies
    user_medications = USER_PROFILE.get("current_medications", [])
    user_allergies = USER_PROFILE.get("allergies", [])
    user_conditions = USER_PROFILE.get("known_gi_conditions", [])

    # Add user-specific warnings
    if user_allergies:
        suggestions.append(f"⚠️ Remember your allergies: {', '.join(user_allergies)}")

    if user_medications:
        suggestions.append(f"💊 Current medications: {', '.join(user_medications)} - check for interactions")

    # Use user's known conditions for better suggestions
    if user_conditions and condition_type not in user_conditions:
        suggestions.append(
            f"📋 You have multiple conditions: {', '.join([CONDITION_DEFINITIONS.get(c, {}).get('name', c) for c in user_conditions])}")

    # Time-based suggestions
    if time_of_day.hour < 10:  # Morning
        suggestions.extend([
            "Ginger tea - Gentle on morning stomach",
            "Small, bland breakfast",
            "Probiotic supplement",
            "Deep breathing exercises"
        ])
    elif time_of_day.hour < 16:  # Afternoon
        suggestions.extend([
            "Peppermint tea - Soothes afternoon discomfort",
            "Light, frequent meals",
            "Walking after meals",
            "Stress management techniques"
        ])
    else:  # Evening/Night
        suggestions.extend([
            "Chamomile tea - Calming for evening",
            "Avoid large meals",
            "Elevate head while sleeping (for GERD)",
            "Heat therapy"
        ])

    # Pain level based suggestions
    if current_pain >= 7:
        suggestions.extend([
            "Immediate: Antacid or prescribed medication",
            "Heat therapy for pain relief",
            "Small sips of water",
            "Rest in comfortable position"
        ])
    elif current_pain >= 4:
        suggestions.extend([
            "Natural remedies: Ginger or peppermint",
            "Gentle abdominal massage",
            "Stress reduction techniques",
            "Avoid trigger foods"
        ])
    else:
        suggestions.extend([
            "Preventive measures: Probiotics",
            "Maintain regular meal schedule",
            "Stay hydrated",
            "Continue current management strategy"
        ])

    # Stress level based suggestions
    if current_stress >= 7:
        suggestions.extend([
            "Priority: Stress management",
            "Meditation or deep breathing",
            "Gentle exercise",
            "Consider counseling support"
        ])

    # Condition-specific suggestions
    if condition_type == "gerd":
        suggestions.extend([
            "Avoid lying down after eating",
            "Elevate head of bed",
            "Smaller, more frequent meals",
            "Avoid trigger foods (spicy, acidic)"
        ])
    elif condition_type == "ibs":
        suggestions.extend([
            "FODMAP diet consideration",
            "Stress management is crucial",
            "Regular exercise",
            "Probiotic supplementation"
        ])

    # Historical effectiveness based suggestions
    if not data.empty:
        remedy_analysis = data.groupby('Remedy')['Pain Level'].agg(['mean', 'count']).reset_index()
        remedy_analysis = remedy_analysis[remedy_analysis['count'] >= 2]  # At least 2 uses
        effective_remedies = remedy_analysis[remedy_analysis['mean'] <= 4].sort_values('mean')

        for _, remedy in effective_remedies.head(3).iterrows():
            suggestions.append(f"Your effective remedy: {remedy['Remedy']} (avg pain: {remedy['mean']:.1f})")

    return list(set(suggestions))  # Remove duplicates


# ============================================================================
# DATA MAPPING AND VISUALIZATION EXPLANATIONS
# ============================================================================

PLOT_EXPLANATIONS = {
    "pain_stress_timeline": {
        "title": "Pain & Stress Levels Over Time",
        "description": "This chart shows how your pain and stress levels change over time, helping identify patterns and correlations between emotional state and physical symptoms.",
        "x_axis": "Time of ingestion or logging time",
        "y_axis": "Pain/Stress level (0-10 scale)",
        "useful_for": [
            "Identifying peak symptom times",
            "Correlating stress with pain levels",
            "Tracking improvement over time",
            "Planning medication timing"
        ]
    },

    "meal_frequency": {
        "title": "Most Common Meals/Foods",
        "description": "This bar chart shows which foods you consume most frequently, helping identify potential trigger foods through correlation with symptom patterns.",
        "x_axis": "Food/Meal names",
        "y_axis": "Frequency of consumption",
        "useful_for": [
            "Identifying frequently consumed foods",
            "Planning elimination diet trials",
            "Understanding eating patterns",
            "Correlating with pain analysis"
        ]
    },

    "pain_trigger_analysis": {
        "title": "Food Pain Analysis",
        "description": "This analysis ranks foods by their average associated pain levels, helping identify potential trigger foods that consistently cause discomfort.",
        "metrics": {
            "Avg_Pain": "Average pain level when this food was consumed",
            "Count": "Number of times this food was logged",
            "Max_Pain": "Highest pain level recorded with this food",
            "Min_Pain": "Lowest pain level recorded with this food",
            "Avg_Stress": "Average stress level when this food was consumed"
        },
        "useful_for": [
            "Identifying trigger foods to avoid",
            "Planning personalized diet modifications",
            "Understanding food-symptom relationships",
            "Making evidence-based dietary decisions"
        ]
    },

    "remedy_effectiveness": {
        "title": "Remedy Effectiveness Analysis",
        "description": "This analysis evaluates how well different remedies work for you, considering both pain reduction and consistency of results.",
        "metrics": {
            "Avg_Pain": "Average pain level after using this remedy (lower is better)",
            "Count": "Number of times this remedy was used",
            "Max_Pain": "Highest pain level recorded with this remedy",
            "Min_Pain": "Lowest pain level recorded with this remedy",
            "Avg_Stress": "Average stress level when this remedy was used"
        },
        "useful_for": [
            "Identifying most effective treatments",
            "Optimizing treatment plans",
            "Reducing trial and error",
            "Communicating with healthcare providers"
        ]
    },

    "timeline_scatter": {
        "title": "Timeline Scatter Plot",
        "description": "This scatter plot shows individual data points over time, with color intensity representing symptom severity, helping identify specific problematic times and patterns.",
        "x_axis": "Time of ingestion",
        "y_axis": "Pain or Stress level",
        "color": "Intensity of symptoms (darker = more severe)",
        "useful_for": [
            "Identifying specific problematic times",
            "Seeing individual data points clearly",
            "Detecting outliers or unusual events",
            "Understanding symptom variability"
        ]
    }
}

# ============================================================================
# USER PROFILE DATA STRUCTURE
# ============================================================================

USER_PROFILE = {
    "name": "",
    "age": "",
    "gender": "",
    "known_gi_conditions": [],
    "current_medications": [],
    "allergies": [],
    "emergency_contact": "",
    "healthcare_provider": "",
    "profile_created": "",
    "last_updated": ""
}

# Profile file path
PROFILE_FILE = "user_profile.json"

# ============================================================================
# ENHANCED DATA STRUCTURE
# ============================================================================

# Enhanced DataFrame with additional columns for comprehensive tracking
ENHANCED_COLUMNS = [
    "Time",  # When the entry was logged
    "Time_of_Ingestion",  # When the food was actually consumed
    "Meal",  # What was consumed
    "Pain_Level",  # Pain level (0-10)
    "Stress_Level",  # Stress level (0-10)
    "Remedy",  # Remedy used
    "Condition_Type",  # Primary condition being tracked
    "Symptom_Types",  # Specific symptoms experienced (JSON list)
    "Meal_Size",  # Small, Medium, Large
    "Meal_Timing",  # Breakfast, Lunch, Dinner, Snack
    "Sleep_Quality",  # Sleep quality the night before (0-10)
    "Exercise_Level",  # Exercise intensity (0-10)
    "Weather",  # Weather conditions
    "Notes"  # Additional notes
]

# Initialize enhanced log data
log_data = pd.DataFrame(columns=ENHANCED_COLUMNS)

# Global variables for filtering
filtered_data = None
current_filter = "All"
current_condition = "gastritis"  # Default condition


# ============================================================================
# USER PROFILE MANAGEMENT FUNCTIONS
# ============================================================================

def load_user_profile():
    """Load user profile from JSON file"""
    global USER_PROFILE
    try:
        if os.path.exists(PROFILE_FILE):
            with open(PROFILE_FILE, 'r') as f:
                USER_PROFILE = json.load(f)
        else:
            # Initialize with default values
            USER_PROFILE["profile_created"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            USER_PROFILE["last_updated"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    except Exception as e:
        print(f"Error loading profile: {e}")
        # Reset to default
        USER_PROFILE = {
            "name": "",
            "age": "",
            "gender": "",
            "known_gi_conditions": [],
            "current_medications": [],
            "allergies": [],
            "emergency_contact": "",
            "healthcare_provider": "",
            "profile_created": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }


def save_user_profile():
    """Save user profile to JSON file"""
    global USER_PROFILE
    try:
        USER_PROFILE["last_updated"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(PROFILE_FILE, 'w') as f:
            json.dump(USER_PROFILE, f, indent=2)
        return True
    except Exception as e:
        print(f"Error saving profile: {e}")
        return False


def show_user_profile():
    """Display and edit user profile in a new window"""
    profile_window = tk.Toplevel(root)
    profile_window.title("User Profile")
    profile_window.geometry("600x700")

    # Create main frame with scrollbar
    main_canvas = tk.Canvas(profile_window)
    main_scrollbar = ttk.Scrollbar(profile_window, orient="vertical", command=main_canvas.yview)
    scrollable_frame = ttk.Frame(main_canvas)

    scrollable_frame.bind(
        "<Configure>",
        lambda e: main_canvas.configure(scrollregion=main_canvas.bbox("all"))
    )

    main_canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    main_canvas.configure(yscrollcommand=main_scrollbar.set)

    # Title
    tk.Label(scrollable_frame, text="👤 User Profile", font=("Arial", 16, "bold")).pack(pady=10)

    # Profile form
    profile_frame = ttk.LabelFrame(scrollable_frame, text="Personal Information", padding="10")
    profile_frame.pack(fill='x', padx=10, pady=5)

    # Name
    tk.Label(profile_frame, text="Full Name:").grid(row=0, column=0, sticky=tk.W, pady=2)
    name_entry = tk.Entry(profile_frame, width=40)
    name_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), pady=2)
    name_entry.insert(0, USER_PROFILE.get("name", ""))

    # Age
    tk.Label(profile_frame, text="Age:").grid(row=1, column=0, sticky=tk.W, pady=2)
    age_entry = tk.Entry(profile_frame, width=40)
    age_entry.grid(row=1, column=1, sticky=(tk.W, tk.E), pady=2)
    age_entry.insert(0, USER_PROFILE.get("age", ""))

    # Gender (inclusive options)
    tk.Label(profile_frame, text="Gender:").grid(row=2, column=0, sticky=tk.W, pady=2)
    gender_var = tk.StringVar(value=USER_PROFILE.get("gender", ""))
    gender_combo = ttk.Combobox(profile_frame, textvariable=gender_var, width=37,
                                values=["Male", "Female", "Non-binary", "Transgender", "Genderqueer",
                                        "Agender", "Two-spirit", "Prefer not to say", "Other"])
    gender_combo.grid(row=2, column=1, sticky=(tk.W, tk.E), pady=2)

    # Emergency Contact
    tk.Label(profile_frame, text="Emergency Contact:").grid(row=3, column=0, sticky=tk.W, pady=2)
    emergency_entry = tk.Entry(profile_frame, width=40)
    emergency_entry.grid(row=3, column=1, sticky=(tk.W, tk.E), pady=2)
    emergency_entry.insert(0, USER_PROFILE.get("emergency_contact", ""))

    # Healthcare Provider
    tk.Label(profile_frame, text="Healthcare Provider:").grid(row=4, column=0, sticky=tk.W, pady=2)
    provider_entry = tk.Entry(profile_frame, width=40)
    provider_entry.grid(row=4, column=1, sticky=(tk.W, tk.E), pady=2)
    provider_entry.insert(0, USER_PROFILE.get("healthcare_provider", ""))

    profile_frame.columnconfigure(1, weight=1)

    # Known GI Conditions
    conditions_frame = ttk.LabelFrame(scrollable_frame, text="Known GI Conditions", padding="10")
    conditions_frame.pack(fill='x', padx=10, pady=5)

    tk.Label(conditions_frame, text="Select all that apply:").pack(anchor='w')

    condition_vars = {}
    for condition_key, condition_data in CONDITION_DEFINITIONS.items():
        var = tk.BooleanVar()
        condition_vars[condition_key] = var
        if condition_key in USER_PROFILE.get("known_gi_conditions", []):
            var.set(True)

        cb = tk.Checkbutton(conditions_frame, text=condition_data['name'], variable=var)
        cb.pack(anchor='w', padx=20)

    # Current Medications
    medications_frame = ttk.LabelFrame(scrollable_frame, text="Current Medications", padding="10")
    medications_frame.pack(fill='x', padx=10, pady=5)

    tk.Label(medications_frame, text="List your current medications (one per line):").pack(anchor='w')
    medications_text = tk.Text(medications_frame, width=50, height=4)
    medications_text.pack(fill='x', pady=5)

    # Load existing medications
    existing_meds = USER_PROFILE.get("current_medications", [])
    medications_text.insert(tk.END, "\n".join(existing_meds))

    # Allergies
    allergies_frame = ttk.LabelFrame(scrollable_frame, text="Allergies & Sensitivities", padding="10")
    allergies_frame.pack(fill='x', padx=10, pady=5)

    tk.Label(allergies_frame, text="List any allergies or sensitivities (one per line):").pack(anchor='w')
    allergies_text = tk.Text(allergies_frame, width=50, height=3)
    allergies_text.pack(fill='x', pady=5)

    # Load existing allergies
    existing_allergies = USER_PROFILE.get("allergies", [])
    allergies_text.insert(tk.END, "\n".join(existing_allergies))

    # Profile info
    info_frame = ttk.LabelFrame(scrollable_frame, text="Profile Information", padding="10")
    info_frame.pack(fill='x', padx=10, pady=5)

    created_date = USER_PROFILE.get("profile_created", "Not set")
    last_updated = USER_PROFILE.get("last_updated", "Not set")

    tk.Label(info_frame, text=f"Profile Created: {created_date}").pack(anchor='w')
    tk.Label(info_frame, text=f"Last Updated: {last_updated}").pack(anchor='w')

    # Buttons
    button_frame = ttk.Frame(scrollable_frame)
    button_frame.pack(fill='x', padx=10, pady=10)

    def save_profile():
        """Save the profile data"""
        # Get basic info
        USER_PROFILE["name"] = name_entry.get().strip()
        USER_PROFILE["age"] = age_entry.get().strip()
        USER_PROFILE["gender"] = gender_var.get()
        USER_PROFILE["emergency_contact"] = emergency_entry.get().strip()
        USER_PROFILE["healthcare_provider"] = provider_entry.get().strip()

        # Get conditions
        selected_conditions = [condition for condition, var in condition_vars.items() if var.get()]
        USER_PROFILE["known_gi_conditions"] = selected_conditions

        # Get medications
        medications = medications_text.get("1.0", tk.END).strip().split('\n')
        USER_PROFILE["current_medications"] = [med.strip() for med in medications if med.strip()]

        # Get allergies
        allergies = allergies_text.get("1.0", tk.END).strip().split('\n')
        USER_PROFILE["allergies"] = [allergy.strip() for allergy in allergies if allergy.strip()]

        # Save to file
        if save_user_profile():
            messagebox.showinfo("Success", "Profile saved successfully!")
            profile_window.destroy()
        else:
            messagebox.showerror("Error", "Failed to save profile. Please try again.")

    def clear_profile():
        """Clear all profile data"""
        if messagebox.askyesno("Confirm", "Are you sure you want to clear all profile data?"):
            name_entry.delete(0, tk.END)
            age_entry.delete(0, tk.END)
            gender_var.set("")
            emergency_entry.delete(0, tk.END)
            provider_entry.delete(0, tk.END)

            for var in condition_vars.values():
                var.set(False)

            medications_text.delete("1.0", tk.END)
            allergies_text.delete("1.0", tk.END)

    tk.Button(button_frame, text="Save Profile", command=save_profile,
              bg='green', fg='white', font=("Arial", 10, "bold")).pack(side=tk.LEFT, padx=5)

    tk.Button(button_frame, text="Clear All", command=clear_profile,
              bg='red', fg='white').pack(side=tk.LEFT, padx=5)

    tk.Button(button_frame, text="Close", command=profile_window.destroy,
              bg='gray', fg='white').pack(side=tk.RIGHT, padx=5)

    # Pack main canvas and scrollbar
    main_canvas.pack(side="left", fill="both", expand=True)
    main_scrollbar.pack(side="right", fill="y")


def show_profile_summary():
    """Show a quick profile summary"""
    if not USER_PROFILE.get("name"):
        messagebox.showinfo("Profile", "No profile information available. Please create a profile first.")
        return

    summary_window = tk.Toplevel(root)
    summary_window.title("Profile Summary")
    summary_window.geometry("500x400")

    # Title
    tk.Label(summary_window, text="👤 Profile Summary", font=("Arial", 14, "bold")).pack(pady=10)

    # Summary text
    summary_text = tk.Text(summary_window, wrap=tk.WORD, font=("Arial", 10))
    summary_scrollbar = ttk.Scrollbar(summary_window, orient="vertical", command=summary_text.yview)
    summary_text.configure(yscrollcommand=summary_scrollbar.set)

    summary_text.pack(side="left", fill="both", expand=True)
    summary_scrollbar.pack(side="right", fill="y")

    # Build summary
    summary = f"""Name: {USER_PROFILE.get('name', 'Not provided')}
Age: {USER_PROFILE.get('age', 'Not provided')}
Gender: {USER_PROFILE.get('gender', 'Not provided')}

Known GI Conditions:
"""

    conditions = USER_PROFILE.get('known_gi_conditions', [])
    if conditions:
        for condition in conditions:
            if condition in CONDITION_DEFINITIONS:
                summary += f"• {CONDITION_DEFINITIONS[condition]['name']}\n"
    else:
        summary += "None specified\n"

    summary += f"\nCurrent Medications:\n"
    medications = USER_PROFILE.get('current_medications', [])
    if medications:
        for med in medications:
            summary += f"• {med}\n"
    else:
        summary += "None specified\n"

    summary += f"\nAllergies & Sensitivities:\n"
    allergies = USER_PROFILE.get('allergies', [])
    if allergies:
        for allergy in allergies:
            summary += f"• {allergy}\n"
    else:
        summary += "None specified\n"

    summary += f"\nEmergency Contact: {USER_PROFILE.get('emergency_contact', 'Not provided')}"
    summary += f"\nHealthcare Provider: {USER_PROFILE.get('healthcare_provider', 'Not provided')}"
    summary += f"\n\nProfile Created: {USER_PROFILE.get('profile_created', 'Not available')}"
    summary += f"\nLast Updated: {USER_PROFILE.get('last_updated', 'Not available')}"

    summary_text.insert(tk.END, summary)
    summary_text.config(state=tk.DISABLED)

    tk.Button(summary_window, text="Close", command=summary_window.destroy,
              bg='blue', fg='white').pack(pady=10)


def export_profile_for_healthcare():
    """Export user profile and recent data for healthcare provider"""
    if not USER_PROFILE.get("name"):
        messagebox.showwarning("No Profile", "Please create a user profile first.")
        return

    try:
        # Create comprehensive report
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"healthcare_report_{USER_PROFILE.get('name', 'user').replace(' ', '_')}_{timestamp}.txt"

        with open(filename, 'w') as f:
            f.write("GASTROGUARD HEALTHCARE REPORT\n")
            f.write("=" * 50 + "\n\n")

            # Profile information
            f.write("PATIENT INFORMATION:\n")
            f.write("-" * 20 + "\n")
            f.write(f"Name: {USER_PROFILE.get('name', 'Not provided')}\n")
            f.write(f"Age: {USER_PROFILE.get('age', 'Not provided')}\n")
            f.write(f"Gender: {USER_PROFILE.get('gender', 'Not provided')}\n")
            f.write(f"Emergency Contact: {USER_PROFILE.get('emergency_contact', 'Not provided')}\n")
            f.write(f"Healthcare Provider: {USER_PROFILE.get('healthcare_provider', 'Not provided')}\n\n")

            # Medical information
            f.write("MEDICAL INFORMATION:\n")
            f.write("-" * 20 + "\n")

            f.write("Known GI Conditions:\n")
            conditions = USER_PROFILE.get('known_gi_conditions', [])
            if conditions:
                for condition in conditions:
                    if condition in CONDITION_DEFINITIONS:
                        f.write(
                            f"• {CONDITION_DEFINITIONS[condition]['name']}: {CONDITION_DEFINITIONS[condition]['description']}\n")
            else:
                f.write("None specified\n")

            f.write("\nCurrent Medications:\n")
            medications = USER_PROFILE.get('current_medications', [])
            if medications:
                for med in medications:
                    f.write(f"• {med}\n")
            else:
                f.write("None specified\n")

            f.write("\nAllergies & Sensitivities:\n")
            allergies = USER_PROFILE.get('allergies', [])
            if allergies:
                for allergy in allergies:
                    f.write(f"• {allergy}\n")
            else:
                f.write("None specified\n")

            # Recent data summary
            if not log_data.empty:
                f.write("\n\nRECENT SYMPTOM DATA:\n")
                f.write("-" * 20 + "\n")

                recent_data = log_data.tail(10)  # Last 10 entries
                f.write(f"Last {len(recent_data)} entries:\n\n")

                for _, row in recent_data.iterrows():
                    f.write(f"Date: {row['Time']}\n")
                    f.write(f"Meal: {row['Meal']}\n")
                    f.write(f"Pain Level: {row['Pain_Level']}/10\n")
                    f.write(f"Stress Level: {row['Stress_Level']}/10\n")
                    f.write(f"Remedy Used: {row['Remedy']}\n")
                    if row['Notes']:
                        f.write(f"Notes: {row['Notes']}\n")
                    f.write("-" * 30 + "\n")

                # Summary statistics
                f.write("\nSUMMARY STATISTICS:\n")
                f.write("-" * 20 + "\n")
                f.write(f"Total entries: {len(log_data)}\n")
                f.write(f"Average pain level: {log_data['Pain_Level'].mean():.1f}/10\n")
                f.write(f"Average stress level: {log_data['Stress_Level'].mean():.1f}/10\n")
                f.write(
                    f"Most common remedy: {log_data['Remedy'].mode().iloc[0] if not log_data['Remedy'].mode().empty else 'None'}\n")

            f.write(f"\n\nReport generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("Generated by GastroGuard Enhanced v3.0\n")

        messagebox.showinfo("Export Successful",
                            f"Healthcare report exported to {filename}\n\nThis report contains your profile information and recent symptom data for your healthcare provider.")

    except Exception as e:
        messagebox.showerror("Export Error", f"Failed to export healthcare report: {str(e)}")


# ============================================================================
# ENHANCED LOGGING FUNCTIONS
# ============================================================================

def submit_enhanced_data():
    """Submit enhanced log entry with comprehensive tracking"""
    global log_data

    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Get time of ingestion
    ingestion_time = get_ingestion_time()

    # Get basic data
    meal = meal_entry.get()
    pain = pain_scale.get()
    stress = stress_scale.get()
    remedy = remedy_entry.get()

    # Get enhanced data
    condition_type = condition_var.get()
    symptom_types = [symptom for symptom, var in symptom_vars.items() if var.get()]
    meal_size = meal_size_var.get()
    meal_timing = meal_timing_var.get()
    sleep_quality = sleep_scale.get()
    exercise_level = exercise_scale.get()
    weather = weather_var.get()
    notes = notes_entry.get("1.0", tk.END).strip()

    new_entry = {
        "Time": current_time,
        "Time_of_Ingestion": ingestion_time,
        "Meal": meal,
        "Pain_Level": pain,
        "Stress_Level": stress,
        "Remedy": remedy,
        "Condition_Type": condition_type,
        "Symptom_Types": json.dumps(symptom_types),
        "Meal_Size": meal_size,
        "Meal_Timing": meal_timing,
        "Sleep_Quality": sleep_quality,
        "Exercise_Level": exercise_level,
        "Weather": weather,
        "Notes": notes
    }

    log_data = pd.concat([log_data, pd.DataFrame([new_entry])], ignore_index=True)
    status_label.config(text="Enhanced data logged successfully!")
    update_filter_display()

    # Generate smart suggestions
    suggestions = generate_smart_remedy_suggestions(
        log_data, pain, stress, datetime.now(), condition_type
    )

    # Show suggestions in a popup
    show_smart_suggestions(suggestions)


def show_smart_suggestions(suggestions):
    """Display smart remedy suggestions in a popup window"""
    suggestion_window = tk.Toplevel(root)
    suggestion_window.title("Smart Remedy Suggestions")
    suggestion_window.geometry("500x400")

    tk.Label(suggestion_window, text="💡 Smart Remedy Suggestions",
             font=("Arial", 14, "bold")).pack(pady=10)

    # Create scrollable text widget
    text_frame = ttk.Frame(suggestion_window)
    text_frame.pack(fill='both', expand=True, padx=10, pady=10)

    suggestions_text = tk.Text(text_frame, wrap=tk.WORD, font=("Arial", 10))
    scrollbar = ttk.Scrollbar(text_frame, orient="vertical", command=suggestions_text.yview)
    suggestions_text.configure(yscrollcommand=scrollbar.set)

    suggestions_text.pack(side="left", fill="both", expand=True)
    scrollbar.pack(side="right", fill="y")

    # Add suggestions
    for i, suggestion in enumerate(suggestions[:10], 1):  # Show top 10
        suggestions_text.insert(tk.END, f"{i}. {suggestion}\n\n")

    suggestions_text.config(state=tk.DISABLED)

    tk.Button(suggestion_window, text="Close", command=suggestion_window.destroy,
              bg='blue', fg='white').pack(pady=10)


# ============================================================================
# TIME ACCURACY FIXES
# ============================================================================

def get_accurate_time():
    """Get accurate current time with timezone awareness"""
    return datetime.now()


def update_time_displays():
    """Update all time displays with accurate current time"""
    current_time = get_accurate_time()

    # Update main time display
    if 'time_display' in globals():
        time_display.config(text=f"Current Time: {current_time.strftime('%Y-%m-%d %H:%M:%S')}")

    # Update ingestion time picker
    if 'ingestion_date' in globals() and 'hour_var' in globals() and 'minute_var' in globals():
        ingestion_date.set_date(current_time.date())
        hour_var.set(current_time.strftime("%H"))
        minute_var.set(current_time.strftime("%M"))

    # Schedule next update
    root.after(1000, update_time_displays)  # Update every second


# ============================================================================
# ENHANCED GUI SETUP
# ============================================================================

def create_enhanced_gui():
    """Create the enhanced GUI with all new features"""
    global root, meal_entry, pain_scale, stress_scale, remedy_entry
    global condition_var, symptom_vars, meal_size_var, meal_timing_var
    global sleep_scale, exercise_scale, weather_var, notes_entry
    global time_display, status_label, filter_label

    root = tk.Tk()
    root.title("GastroGuard Enhanced v3.0 - Comprehensive Chronic Stomach Condition Management")
    root.geometry("900x1000")

    # Create main frame with scrollbar
    main_canvas = tk.Canvas(root)
    main_scrollbar = ttk.Scrollbar(root, orient="vertical", command=main_canvas.yview)
    scrollable_frame = ttk.Frame(main_canvas)

    scrollable_frame.bind(
        "<Configure>",
        lambda e: main_canvas.configure(scrollregion=main_canvas.bbox("all"))
    )

    main_canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    main_canvas.configure(yscrollcommand=main_scrollbar.set)

    # Configure grid weights
    root.columnconfigure(0, weight=1)
    root.rowconfigure(0, weight=1)
    scrollable_frame.columnconfigure(1, weight=1)

    # Title and Mission Statement
    title_frame = ttk.LabelFrame(scrollable_frame, text="GastroGuard Enhanced v3.0", padding="10")
    title_frame.grid(row=0, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))

    tk.Label(title_frame, text="🏥 GastroGuard - Comprehensive Chronic Stomach Condition Management",
             font=("Arial", 16, "bold")).grid(row=0, column=0, columnspan=3, pady=(0, 10))

    # Mission statement
    mission_text = """MISSION: Empowering individuals with chronic stomach conditions through data-driven insights, 
personalized tracking, and evidence-based recommendations for improved quality of life."""
    tk.Label(title_frame, text=mission_text, font=("Arial", 10), wraplength=800, justify="center").grid(row=1, column=0,
                                                                                                        columnspan=3,
                                                                                                        pady=5)

    # Current time display
    time_display = tk.Label(title_frame, text="", font=("Arial", 10, "bold"), fg="blue")
    time_display.grid(row=2, column=0, columnspan=3, pady=5)

    # Condition selection
    condition_frame = ttk.LabelFrame(scrollable_frame, text="Condition Selection", padding="10")
    condition_frame.grid(row=1, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))

    tk.Label(condition_frame, text="Primary Condition:").grid(row=0, column=0, sticky=tk.W, padx=5)
    condition_var = tk.StringVar(value="gastritis")
    condition_combo = ttk.Combobox(condition_frame, textvariable=condition_var,
                                   values=list(CONDITION_DEFINITIONS.keys()), state="readonly")
    condition_combo.grid(row=0, column=1, sticky=(tk.W, tk.E), padx=5)

    # Show condition description
    def update_condition_description(*args):
        condition = condition_var.get()
        if condition in CONDITION_DEFINITIONS:
            desc = CONDITION_DEFINITIONS[condition]['description']
            condition_desc_label.config(text=f"Description: {desc}")

    condition_var.trace('w', update_condition_description)
    condition_desc_label = tk.Label(condition_frame, text="", font=("Arial", 9), wraplength=600)
    condition_desc_label.grid(row=1, column=0, columnspan=2, pady=5)
    update_condition_description()

    # Enhanced input section
    input_frame = ttk.LabelFrame(scrollable_frame, text="Enhanced Log Entry", padding="10")
    input_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))

    # Basic inputs
    tk.Label(input_frame, text="Meal/Food Consumed:").grid(row=0, column=0, sticky=tk.W, pady=2)
    meal_entry = tk.Entry(input_frame, width=50)
    meal_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), pady=2)

    # Time of ingestion
    tk.Label(input_frame, text="Time of Ingestion:").grid(row=1, column=0, sticky=tk.W, pady=2)
    ingestion_time_frame = ttk.Frame(input_frame)
    ingestion_time_frame.grid(row=1, column=1, sticky=(tk.W, tk.E), pady=2)

    ingestion_date = DateEntry(ingestion_time_frame, width=15, background='darkblue', foreground='white', borderwidth=2)
    ingestion_date.pack(side=tk.LEFT, padx=(0, 5))

    hour_var = tk.StringVar(value=datetime.now().strftime("%H"))
    minute_var = tk.StringVar(value=datetime.now().strftime("%M"))

    tk.Label(ingestion_time_frame, text="Hour:").pack(side=tk.LEFT)
    hour_spin = tk.Spinbox(ingestion_time_frame, from_=0, to=23, width=3, textvariable=hour_var)
    hour_spin.pack(side=tk.LEFT, padx=2)

    tk.Label(ingestion_time_frame, text="Min:").pack(side=tk.LEFT)
    minute_spin = tk.Spinbox(ingestion_time_frame, from_=0, to=59, width=3, textvariable=minute_var)
    minute_spin.pack(side=tk.LEFT, padx=2)

    # Pain and stress scales with descriptions
    tk.Label(input_frame, text="Pain Level (0-10):").grid(row=2, column=0, sticky=tk.W, pady=2)
    pain_scale = tk.Scale(input_frame, from_=0, to=10, orient="horizontal", length=300)
    pain_scale.grid(row=2, column=1, sticky=(tk.W, tk.E), pady=2)

    tk.Label(input_frame, text="Stress Level (0-10):").grid(row=3, column=0, sticky=tk.W, pady=2)
    stress_scale = tk.Scale(input_frame, from_=0, to=10, orient="horizontal", length=300)
    stress_scale.grid(row=3, column=1, sticky=(tk.W, tk.E), pady=2)

    tk.Label(input_frame, text="Remedy Used:").grid(row=4, column=0, sticky=tk.W, pady=2)
    remedy_entry = tk.Entry(input_frame, width=50)
    remedy_entry.grid(row=4, column=1, sticky=(tk.W, tk.E), pady=2)

    # Enhanced inputs
    tk.Label(input_frame, text="Meal Size:").grid(row=5, column=0, sticky=tk.W, pady=2)
    meal_size_var = tk.StringVar(value="Medium")
    meal_size_combo = ttk.Combobox(input_frame, textvariable=meal_size_var,
                                   values=["Small", "Medium", "Large"], state="readonly")
    meal_size_combo.grid(row=5, column=1, sticky=(tk.W, tk.E), pady=2)

    tk.Label(input_frame, text="Meal Timing:").grid(row=6, column=0, sticky=tk.W, pady=2)
    meal_timing_var = tk.StringVar(value="Lunch")
    meal_timing_combo = ttk.Combobox(input_frame, textvariable=meal_timing_var,
                                     values=["Breakfast", "Lunch", "Dinner", "Snack"], state="readonly")
    meal_timing_combo.grid(row=6, column=1, sticky=(tk.W, tk.E), pady=2)

    tk.Label(input_frame, text="Sleep Quality (0-10):").grid(row=7, column=0, sticky=tk.W, pady=2)
    sleep_scale = tk.Scale(input_frame, from_=0, to=10, orient="horizontal", length=300)
    sleep_scale.grid(row=7, column=1, sticky=(tk.W, tk.E), pady=2)

    tk.Label(input_frame, text="Exercise Level (0-10):").grid(row=8, column=0, sticky=tk.W, pady=2)
    exercise_scale = tk.Scale(input_frame, from_=0, to=10, orient="horizontal", length=300)
    exercise_scale.grid(row=8, column=1, sticky=(tk.W, tk.E), pady=2)

    tk.Label(input_frame, text="Weather:").grid(row=9, column=0, sticky=tk.W, pady=2)
    weather_var = tk.StringVar(value="Clear")
    weather_combo = ttk.Combobox(input_frame, textvariable=weather_var,
                                 values=["Clear", "Cloudy", "Rainy", "Stormy", "Hot", "Cold"], state="readonly")
    weather_combo.grid(row=9, column=1, sticky=(tk.W, tk.E), pady=2)

    # Symptom types selection
    tk.Label(input_frame, text="Symptom Types:").grid(row=10, column=0, sticky=tk.W, pady=2)
    symptom_frame = ttk.Frame(input_frame)
    symptom_frame.grid(row=10, column=1, sticky=(tk.W, tk.E), pady=2)

    symptom_vars = {}
    symptoms = list(SYMPTOM_TYPES.keys())
    for i, symptom in enumerate(symptoms):
        var = tk.BooleanVar()
        symptom_vars[symptom] = var
        cb = tk.Checkbutton(symptom_frame, text=symptom.replace('_', ' ').title(), variable=var)
        cb.grid(row=i // 3, column=i % 3, sticky=tk.W, padx=5)

    # Notes
    tk.Label(input_frame, text="Additional Notes:").grid(row=11, column=0, sticky=tk.W, pady=2)
    notes_entry = tk.Text(input_frame, width=50, height=3)
    notes_entry.grid(row=11, column=1, sticky=(tk.W, tk.E), pady=2)

    # Configure input frame grid weights
    input_frame.columnconfigure(1, weight=1)

    # Buttons section
    button_frame = ttk.Frame(scrollable_frame)
    button_frame.grid(row=3, column=0, columnspan=3, pady=(0, 10))

    # Main buttons
    tk.Button(button_frame, text="Log Enhanced Entry", command=submit_enhanced_data,
              bg='green', fg='white', font=("Arial", 10, "bold")).grid(row=0, column=0, padx=5, pady=5)

    tk.Button(button_frame, text="Show Smart Suggestions",
              command=lambda: show_smart_suggestions(generate_smart_remedy_suggestions(
                  log_data, pain_scale.get(), stress_scale.get(), datetime.now(), condition_var.get()
              )), bg='purple', fg='white').grid(row=0, column=1, padx=5, pady=5)

    tk.Button(button_frame, text="View Symptom Scales", command=show_symptom_scales,
              bg='blue', fg='white').grid(row=0, column=2, padx=5, pady=5)

    tk.Button(button_frame, text="Enhanced Analytics", command=show_enhanced_analytics,
              bg='orange', fg='white').grid(row=0, column=3, padx=5, pady=5)

    # User Profile buttons
    tk.Button(button_frame, text="👤 User Profile", command=show_user_profile,
              bg='teal', fg='white', font=("Arial", 10, "bold")).grid(row=0, column=4, padx=5, pady=5)

    tk.Button(button_frame, text="Profile Summary", command=show_profile_summary,
              bg='darkgreen', fg='white').grid(row=0, column=5, padx=5, pady=5)

    # Status section
    status_frame = ttk.Frame(scrollable_frame)
    status_frame.grid(row=4, column=0, columnspan=3, sticky=(tk.W, tk.E))

    status_label = tk.Label(status_frame, text="Ready to log enhanced data", fg="green")
    status_label.grid(row=0, column=0, sticky=tk.W)

    # Pack main canvas and scrollbar
    main_canvas.pack(side="left", fill="both", expand=True)
    main_scrollbar.pack(side="right", fill="y")

    # Start time updates
    update_time_displays()

    return root


def show_symptom_scales():
    """Display detailed symptom scales and definitions"""
    scale_window = tk.Toplevel(root)
    scale_window.title("Symptom Scales & Definitions")
    scale_window.geometry("800x600")

    # Create notebook for different scales
    notebook = ttk.Notebook(scale_window)
    notebook.pack(fill='both', expand=True, padx=10, pady=10)

    for scale_name, scale_data in SYMPTOM_SCALES.items():
        frame = ttk.Frame(notebook)
        notebook.add(frame, text=scale_data['name'])

        # Title
        tk.Label(frame, text=scale_data['name'], font=("Arial", 14, "bold")).pack(pady=10)

        # Description
        tk.Label(frame, text=scale_data['description'], font=("Arial", 10), wraplength=700).pack(pady=5)

        # Medical context
        tk.Label(frame, text=f"Medical Context: {scale_data['medical_context']}",
                 font=("Arial", 9, "italic"), wraplength=700).pack(pady=5)

        # Scale values
        tk.Label(frame, text="Scale Values:", font=("Arial", 12, "bold")).pack(pady=(20, 5))

        for value, description in scale_data['scale'].items():
            scale_frame = ttk.Frame(frame)
            scale_frame.pack(fill='x', padx=10, pady=2)

            tk.Label(scale_frame, text=f"{value}:", font=("Arial", 10, "bold"), width=3).pack(side=tk.LEFT)
            tk.Label(scale_frame, text=description, font=("Arial", 10), wraplength=600).pack(side=tk.LEFT, padx=5)


def show_enhanced_analytics():
    """Show enhanced analytics with detailed explanations"""
    if log_data.empty:
        messagebox.showwarning("No Data", "No data available for analysis.")
        return

    analytics_window = tk.Toplevel(root)
    analytics_window.title("Enhanced Analytics with Explanations")
    analytics_window.geometry("1000x700")

    # Create notebook for different analyses
    notebook = ttk.Notebook(analytics_window)
    notebook.pack(fill='both', expand=True, padx=10, pady=10)

    # Overview tab
    overview_frame = ttk.Frame(notebook)
    notebook.add(overview_frame, text="Overview")

    # Data summary
    total_entries = len(log_data)
    avg_pain = log_data['Pain_Level'].mean()
    avg_stress = log_data['Stress_Level'].mean()

    summary_text = f"""
ENHANCED ANALYTICS OVERVIEW

Total Entries: {total_entries}
Average Pain Level: {avg_pain:.1f}/10
Average Stress Level: {avg_stress:.1f}/10
Conditions Tracked: {log_data['Condition_Type'].nunique()}
Unique Foods: {log_data['Meal'].nunique()}
Unique Remedies: {log_data['Remedy'].nunique()}

DATA QUALITY INDICATORS:
- Complete entries: {len(log_data.dropna())}/{total_entries}
- Recent entries (last 7 days): {len(log_data[pd.to_datetime(log_data['Time']) >= datetime.now() - timedelta(days=7)])}
- Symptom types logged: {sum(1 for x in log_data['Symptom_Types'] if x != '[]')}
"""

    tk.Text(overview_frame, text=summary_text, font=("Courier", 10), wrap=tk.WORD).pack(fill='both', expand=True,
                                                                                        padx=10, pady=10)

    # Plot explanations tab
    explanations_frame = ttk.Frame(notebook)
    notebook.add(explanations_frame, text="Plot Explanations")

    explanations_text = tk.Text(explanations_frame, wrap=tk.WORD, font=("Arial", 10))
    explanations_scrollbar = ttk.Scrollbar(explanations_frame, orient="vertical", command=explanations_text.yview)
    explanations_text.configure(yscrollcommand=explanations_scrollbar.set)

    explanations_text.pack(side="left", fill="both", expand=True)
    explanations_scrollbar.pack(side="right", fill="y")

    # Add plot explanations
    for plot_name, plot_info in PLOT_EXPLANATIONS.items():
        explanations_text.insert(tk.END, f"\n{plot_info['title'].upper()}\n")
        explanations_text.insert(tk.END, "=" * len(plot_info['title']) + "\n\n")
        explanations_text.insert(tk.END, f"Description: {plot_info['description']}\n\n")

        if 'x_axis' in plot_info:
            explanations_text.insert(tk.END, f"X-Axis: {plot_info['x_axis']}\n")
        if 'y_axis' in plot_info:
            explanations_text.insert(tk.END, f"Y-Axis: {plot_info['y_axis']}\n")
        if 'color' in plot_info:
            explanations_text.insert(tk.END, f"Color: {plot_info['color']}\n")

        explanations_text.insert(tk.END, "\nUseful for:\n")
        for use in plot_info['useful_for']:
            explanations_text.insert(tk.END, f"• {use}\n")

        if 'metrics' in plot_info:
            explanations_text.insert(tk.END, "\nMetrics Explained:\n")
            for metric, desc in plot_info['metrics'].items():
                explanations_text.insert(tk.END, f"• {metric}: {desc}\n")

        explanations_text.insert(tk.END, "\n" + "-" * 50 + "\n")

    explanations_text.config(state=tk.DISABLED)


# ============================================================================
# MISSING FUNCTIONS AND COMPLETIONS
# ============================================================================

def get_ingestion_time():
    """Get the ingestion time string from the date and time pickers"""
    try:
        # Check if the GUI variables exist
        if 'ingestion_date' in globals() and 'hour_var' in globals() and 'minute_var' in globals():
            selected_date = ingestion_date.get_date()
            hour = int(hour_var.get())
            minute = int(minute_var.get())
            ingestion_datetime = datetime.combine(selected_date, datetime.min.time().replace(hour=hour, minute=minute))
            return ingestion_datetime.strftime("%Y-%m-%d %H:%M:%S")
        else:
            return datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    except:
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def update_filter_display():
    """Update the filter display label with current filter information"""
    if filtered_data is not None and not filtered_data.empty:
        filter_info = f"Filter: {current_filter} | Records: {len(filtered_data)}"
    else:
        filter_info = f"Filter: {current_filter} | No data in selected period"

    if 'filter_label' in globals():
        filter_label.config(text=filter_info)


def filter_data(period="All"):
    """Filter data based on time period"""
    global filtered_data, current_filter

    if log_data.empty:
        filtered_data = pd.DataFrame()
        current_filter = period
        update_filter_display()
        return

    # Convert Time column to datetime if not already
    if not pd.api.types.is_datetime64_any_dtype(log_data["Time"]):
        log_data["Time"] = pd.to_datetime(log_data["Time"])

    now = datetime.now()

    if period == "All":
        filtered_data = log_data.copy()
    elif period == "Today":
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        filtered_data = log_data[log_data["Time"] >= today_start]
    elif period == "This Week":
        days_since_monday = now.weekday()
        week_start = now - timedelta(days=days_since_monday)
        week_start = week_start.replace(hour=0, minute=0, second=0, microsecond=0)
        filtered_data = log_data[log_data["Time"] >= week_start]
    elif period == "This Month":
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        filtered_data = log_data[log_data["Time"] >= month_start]
    elif period == "Last 7 Days":
        week_ago = now - timedelta(days=7)
        filtered_data = log_data[log_data["Time"] >= week_ago]
    elif period == "Last 30 Days":
        month_ago = now - timedelta(days=30)
        filtered_data = log_data[log_data["Time"] >= month_ago]

    current_filter = period
    update_filter_display()


def show_enhanced_graph():
    """Show enhanced graph with detailed explanations"""
    data_to_plot = filtered_data if filtered_data is not None and not filtered_data.empty else log_data

    if data_to_plot.empty:
        messagebox.showwarning("No Data", "No data to plot.")
        return

    # Ensure Time column is datetime
    if not pd.api.types.is_datetime64_any_dtype(data_to_plot["Time"]):
        data_to_plot["Time"] = pd.to_datetime(data_to_plot["Time"])

    # Create figure with subplots
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))

    # Pain and stress levels over time
    if "Time_of_Ingestion" in data_to_plot.columns:
        if not pd.api.types.is_datetime64_any_dtype(data_to_plot["Time_of_Ingestion"]):
            data_to_plot["Time_of_Ingestion"] = pd.to_datetime(data_to_plot["Time_of_Ingestion"])

        data_to_plot.plot(x="Time_of_Ingestion", y=["Pain_Level", "Stress_Level"], kind="line", marker='o', ax=ax1)
        ax1.set_title(f"Pain & Stress Levels Over Time of Ingestion ({current_filter})")
        ax1.set_ylabel("Level")
        ax1.set_xlabel("Time of Ingestion")
    else:
        data_to_plot.plot(x="Time", y=["Pain_Level", "Stress_Level"], kind="line", marker='o', ax=ax1)
        ax1.set_title(f"Pain & Stress Levels Over Time ({current_filter})")
        ax1.set_ylabel("Level")
        ax1.set_xlabel("Time")

    ax1.grid(True)

    # Meal frequency analysis
    if not data_to_plot.empty:
        meal_counts = data_to_plot["Meal"].value_counts().head(10)
        meal_counts.plot(kind='bar', ax=ax2, color='skyblue')
        ax2.set_title("Most Common Meals/Foods")
        ax2.set_ylabel("Frequency")
        ax2.tick_params(axis='x', rotation=45)

    # Condition type distribution
    if 'Condition_Type' in data_to_plot.columns:
        condition_counts = data_to_plot["Condition_Type"].value_counts()
        condition_counts.plot(kind='pie', ax=ax3, autopct='%1.1f%%')
        ax3.set_title("Condition Types Tracked")
        ax3.set_ylabel("")

    # Remedy effectiveness
    if not data_to_plot.empty:
        remedy_analysis = data_to_plot.groupby('Remedy')['Pain_Level'].mean().sort_values(ascending=True).head(10)
        remedy_analysis.plot(kind='barh', ax=ax4, color='lightgreen')
        ax4.set_title("Remedy Effectiveness (Lower Pain = Better)")
        ax4.set_xlabel("Average Pain Level")

    plt.tight_layout()
    plt.show()


def export_enhanced_data():
    """Export enhanced data with all new columns"""
    data_to_export = filtered_data if filtered_data is not None and not filtered_data.empty else log_data

    if data_to_export.empty:
        messagebox.showwarning("No Data", "No data available to export.")
        return

    try:
        filename = f"gastroguard_enhanced_data_{current_filter.replace(' ', '_')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        data_to_export.to_csv(filename, index=False)
        messagebox.showinfo("Export Successful", f"Enhanced data exported to {filename}")
    except Exception as e:
        messagebox.showerror("Export Error", f"Failed to export data: {str(e)}")


def show_condition_guide():
    """Show comprehensive condition guide and definitions"""
    guide_window = tk.Toplevel(root)
    guide_window.title("Condition Guide & Definitions")
    guide_window.geometry("800x600")

    # Create notebook for different conditions
    notebook = ttk.Notebook(guide_window)
    notebook.pack(fill='both', expand=True, padx=10, pady=10)

    for condition_key, condition_data in CONDITION_DEFINITIONS.items():
        frame = ttk.Frame(notebook)
        notebook.add(frame, text=condition_data['name'])

        # Title
        tk.Label(frame, text=condition_data['name'], font=("Arial", 14, "bold")).pack(pady=10)

        # Description
        tk.Label(frame, text=condition_data['description'], font=("Arial", 11), wraplength=700).pack(pady=5)

        # Common symptoms
        tk.Label(frame, text="Common Symptoms:", font=("Arial", 12, "bold")).pack(pady=(20, 5))
        for symptom in condition_data['common_symptoms']:
            symptom_desc = SYMPTOM_TYPES.get(symptom, symptom.replace('_', ' ').title())
            tk.Label(frame, text=f"• {symptom_desc}", font=("Arial", 10), wraplength=650).pack(anchor='w', padx=20)

        # Triggers
        tk.Label(frame, text="Common Triggers:", font=("Arial", 12, "bold")).pack(pady=(20, 5))
        for trigger in condition_data['triggers']:
            tk.Label(frame, text=f"• {trigger.replace('_', ' ').title()}", font=("Arial", 10), wraplength=650).pack(
                anchor='w', padx=20)

        # Typical patterns
        tk.Label(frame, text="Typical Patterns:", font=("Arial", 12, "bold")).pack(pady=(20, 5))
        tk.Label(frame, text=condition_data['typical_patterns'], font=("Arial", 10), wraplength=650).pack(pady=5)


def show_remedy_guide():
    """Show comprehensive remedy guide and categories"""
    remedy_window = tk.Toplevel(root)
    remedy_window.title("Remedy Guide & Categories")
    remedy_window.geometry("800x600")

    # Create notebook for different remedy categories
    notebook = ttk.Notebook(remedy_window)
    notebook.pack(fill='both', expand=True, padx=10, pady=10)

    for category, remedies in REMEDY_CATEGORIES.items():
        frame = ttk.Frame(notebook)
        notebook.add(frame, text=category.replace('_', ' ').title())

        # Title
        tk.Label(frame, text=category.replace('_', ' ').title(), font=("Arial", 14, "bold")).pack(pady=10)

        # Subcategories
        for subcategory, remedy_list in remedies.items():
            tk.Label(frame, text=subcategory.replace('_', ' ').title() + ":", font=("Arial", 12, "bold")).pack(
                pady=(20, 5))
            for remedy in remedy_list:
                tk.Label(frame, text=f"• {remedy}", font=("Arial", 10), wraplength=650).pack(anchor='w', padx=20)


# ============================================================================
# ENHANCED GUI COMPLETION
# ============================================================================

def add_enhanced_buttons():
    """Add enhanced buttons to the GUI"""
    # Add more buttons to the button frame
    button_frame = None
    for child in root.winfo_children():
        if isinstance(child, tk.Canvas):
            for grandchild in child.winfo_children():
                if isinstance(grandchild, ttk.Frame):
                    for great_grandchild in grandchild.winfo_children():
                        if isinstance(great_grandchild, ttk.Frame) and great_grandchild.winfo_children():
                            button_frame = great_grandchild
                            break

    if button_frame:
        # Add additional buttons
        tk.Button(button_frame, text="Enhanced Graph", command=show_enhanced_graph,
                  bg='cyan', fg='black').grid(row=1, column=0, padx=5, pady=5)

        tk.Button(button_frame, text="Export Enhanced Data", command=export_enhanced_data,
                  bg='orange', fg='white').grid(row=1, column=1, padx=5, pady=5)

        tk.Button(button_frame, text="Condition Guide", command=show_condition_guide,
                  bg='blue', fg='white').grid(row=1, column=2, padx=5, pady=5)

        tk.Button(button_frame, text="Remedy Guide", command=show_remedy_guide,
                  bg='purple', fg='white').grid(row=1, column=3, padx=5, pady=5)

        tk.Button(button_frame, text="Export for Healthcare", command=export_profile_for_healthcare,
                  bg='darkred', fg='white').grid(row=1, column=4, padx=5, pady=5)


# ============================================================================
# MAIN EXECUTION
# ============================================================================

if __name__ == "__main__":
    # Load user profile on startup
    load_user_profile()

    # Create and run the enhanced GUI
    root = create_enhanced_gui()

    # Add enhanced buttons after GUI creation
    root.after(100, add_enhanced_buttons)

    # Initialize filter
    filter_data("All")

    root.mainloop()
