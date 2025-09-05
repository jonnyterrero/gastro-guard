# 🏥 GastroGuard Enhanced v3.0

[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)]()

> **Comprehensive Chronic Stomach Condition Management System**

GastroGuard Enhanced v3.0 is a powerful digital health assistant designed to help individuals manage chronic stomach conditions including gastritis, GERD, IBS, dyspepsia, and food sensitivities. Our mission is to empower users with data-driven insights, personalized tracking, and evidence-based recommendations to improve their quality of life.

## 🌟 Key Features

### 📊 **Enhanced Pain Assessment**
- **Medical-grade 0-10 pain scale** with functional impact descriptions
- **Comprehensive symptom mapping** including common qualities and additional symptoms
- **Emergency-level pain identification** with automatic medical guidance
- **Quick reference tooltip** (📋) for instant pain scale lookup

### 👤 **User Profile Management**
- **Personal Information**: Name, age, gender (inclusive options)
- **Medical History**: Known GI conditions, current medications, allergies
- **Emergency Contacts**: Healthcare provider and emergency contact information
- **Profile Persistence**: Automatic saving to `user_profile.json`

### 🍽️ **Flexible Meal Logging**
- **Optional Remedy Entry**: Log meals without requiring a remedy
- **Comprehensive Tracking**: Meal size, timing, sleep quality, exercise, weather
- **Retroactive Logging**: Log entries for past dates and times
- **Smart Placeholder Text**: Clear guidance for optional fields

### 🤖 **Smart Remedy Suggestions**
- **Adaptive Engine**: Time, stress, and history-based recommendations
- **Condition-Specific**: Tailored suggestions for GERD, IBS, gastritis, etc.
- **Medication Integration**: Uses profile data for personalized recommendations
- **Emergency Alerts**: Automatic warnings for high pain levels

### 📈 **Advanced Analytics**
- **Clear Data Mapping**: Every plot includes explanations and purpose
- **Pain Trigger Analysis**: Identifies foods that consistently cause discomfort
- **Remedy Effectiveness**: Evaluates treatment success with confidence levels
- **Timeline Analysis**: Tracks patterns over time with ingestion vs. logging time

### 🏥 **Inclusive Design**
- **Multiple Conditions**: Support for gastritis, GERD, IBS, dyspepsia, food sensitivity
- **Inclusive Gender Options**: 9 gender identity options including non-binary, transgender, etc.
- **Accessibility Features**: Clear labels, tooltips, and comprehensive documentation

## 🚀 Quick Start

### Prerequisites
- Python 3.8 or higher
- 4GB RAM recommended
- 100MB free disk space

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/gastroguard-enhanced.git
   cd gastroguard-enhanced
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements_enhanced.txt
   ```

3. **Run the application**
   ```bash
   python gastroguard_enhanced_v3.py
   ```

## 📱 Usage

### First Time Setup
1. **Create User Profile**: Click "👤 User Profile" to set up your personal information
2. **Select Condition**: Choose your primary condition (gastritis, GERD, IBS, etc.)
3. **Review Scales**: Click "View Symptom Scales" to understand the pain assessment
4. **Start Logging**: Begin tracking your meals, symptoms, and remedies

### Daily Usage
1. **Log Meals**: Enter meal details, pain/stress levels, and optional remedies
2. **Get Suggestions**: Click "Show Smart Suggestions" for personalized recommendations
3. **View Analytics**: Use "Enhanced Analytics" to understand your patterns
4. **Export Data**: Generate reports for healthcare providers

## 📊 Enhanced Pain Scale

Our medical-grade pain scale provides comprehensive assessment:

| Score | Label | Functional Impact | Common Qualities | Additional Symptoms |
|-------|-------|------------------|------------------|-------------------|
| **0** | No Pain | Complete comfort, no symptoms | None | None |
| **1** | Barely Noticeable | Very light sensation; does not interfere with any activities | Slight ache, vague tightness | None |
| **2** | Very Mild | Still ignorable, but occasionally noticeable | Dull, achy | Slight bloating or gas |
| **3** | Mild | Intermittent discomfort; aware of it but tolerable | Gnawing, bloated, light cramping | Nausea, burping, slight fullness |
| **4** | Uncomfortable | Persistent enough to be distracting | Cramping, sharp at times | Mild reflux, appetite changes |
| **5** | Moderate | Affects focus; consider stopping some tasks | Burning, twisting, tight pressure | Fullness after eating, some fatigue |
| **6** | Distressing | Requires sitting/lying down; disrupts concentration | Sharp, stabbing, waves of pain | Bloating, nausea, loose stool |
| **7** | Strong | Interferes with mobility and eating; may cry or wince | Intense cramping, burning | Diarrhea, fatigue, irritability |
| **8** | Severe | Unable to work or socialize; sweating or doubled over | Continuous sharp or burning waves | Vomiting, visible physical distress |
| **9** | Disabling | Can't sit upright; pacing or fetal position | Intense stabbing or burning pain | Radiating to back or pelvis |
| **10** | Unbearable | Emergency-level; cannot talk or move; possible ER visit | Extreme, radiating, knife-like pain | Black stool, severe vomiting, or syncope (call a doctor) |

## 🏥 Supported Conditions

### Gastritis
- **Description**: Inflammation of the stomach lining
- **Common Symptoms**: Stomach pain, nausea, vomiting, bloating, loss of appetite
- **Typical Patterns**: Pain often occurs 30-60 minutes after eating

### GERD (Gastroesophageal Reflux Disease)
- **Description**: Chronic acid reflux affecting the esophagus
- **Common Symptoms**: Heartburn, regurgitation, chest pain, difficulty swallowing
- **Typical Patterns**: Symptoms worsen when lying down or bending over

### IBS (Irritable Bowel Syndrome)
- **Description**: Functional disorder affecting the large intestine
- **Common Symptoms**: Abdominal pain, bloating, diarrhea, constipation, gas
- **Typical Patterns**: Symptoms often improve after bowel movements

### Functional Dyspepsia
- **Description**: Chronic indigestion without obvious cause
- **Common Symptoms**: Upper abdominal pain, early satiety, bloating, nausea
- **Typical Patterns**: Symptoms often occur during or after meals

### Food Sensitivity/Intolerance
- **Description**: Adverse reactions to specific foods
- **Common Symptoms**: Bloating, gas, diarrhea, stomach pain, nausea
- **Typical Patterns**: Symptoms occur 2-6 hours after consuming trigger foods

## 📁 Project Structure

```
gastroguard-enhanced/
├── gastroguard_enhanced_v3.py      # Main application
├── requirements_enhanced.txt        # Python dependencies
├── README.md                        # This file
├── README_ENHANCED_v3.md           # Detailed documentation
├── ENHANCED_FEATURES_DOCUMENTATION.md # Feature documentation
├── test_enhanced_features.py       # Feature tests
├── test_user_profile.py            # User profile tests
├── test_optional_remedy.py         # Optional remedy tests
├── test_enhanced_pain_scale.py     # Pain scale tests
└── user_profile.json               # User profile data (created on first run)
```

## 🧪 Testing

Run the comprehensive test suite to verify all features:

```bash
# Test enhanced features
python test_enhanced_features.py

# Test user profile functionality
python test_user_profile.py

# Test optional remedy feature
python test_optional_remedy.py

# Test enhanced pain scale
python test_enhanced_pain_scale.py
```

## 📊 Data Export

### Healthcare Provider Reports
- **Comprehensive patient information** including profile and medical history
- **Recent symptom data** with detailed analysis
- **Summary statistics** and trend analysis
- **Export format**: Text files compatible with electronic health records

### Data Analysis Export
- **CSV format** with all enhanced data fields
- **Custom date ranges** for specific periods
- **Filtered data** based on time periods or conditions
- **Analysis reports** with food and remedy effectiveness

## 🔒 Privacy & Security

- **Local Storage**: All data stays on your device
- **No Cloud Sync**: Complete privacy and control
- **Export Control**: You decide what to share with healthcare providers
- **Secure Logging**: Optional encrypted local storage

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -m 'Add amazing feature'`
5. Push to the branch: `git push origin feature/amazing-feature`
6. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Medical Community**: For providing clinical guidance on pain assessment scales
- **User Feedback**: For helping us improve the user experience
- **Open Source Community**: For the amazing tools and libraries we use

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/gastroguard-enhanced/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/gastroguard-enhanced/discussions)
- **Documentation**: [Wiki](https://github.com/yourusername/gastroguard-enhanced/wiki)

## 🏆 Features Comparison

| Feature | Basic Version | Enhanced v3.0 |
|---------|---------------|---------------|
| Pain Tracking | Basic 0-10 scale | Medical-grade with functional impact |
| User Profiles | ❌ | ✅ Comprehensive profiles |
| Remedy Tracking | Required | ✅ Optional with smart suggestions |
| Condition Support | Gastritis only | ✅ 5+ conditions |
| Data Export | Basic CSV | ✅ Healthcare reports |
| Analytics | Simple graphs | ✅ Detailed explanations |
| Gender Options | Binary | ✅ 9 inclusive options |
| Emergency Alerts | ❌ | ✅ Automatic warnings |

## 🎯 Roadmap

- [ ] **Mobile App**: iOS and Android versions
- [ ] **Cloud Sync**: Optional encrypted cloud backup
- [ ] **AI Integration**: Machine learning for pattern recognition
- [ ] **Healthcare Integration**: Direct EHR connectivity
- [ ] **Multi-language Support**: Spanish, French, German
- [ ] **Wearable Integration**: Apple Watch, Fitbit support

---

**Made with ❤️ for the chronic stomach condition community**

*GastroGuard Enhanced v3.0 - Empowering individuals with chronic stomach conditions through comprehensive data-driven health management.*
