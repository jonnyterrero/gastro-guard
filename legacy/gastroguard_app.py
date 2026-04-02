import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from scipy.integrate import solve_ivp
import numpy as np
from datetime import datetime, timedelta
import base64

# Page configuration for web deployment
st.set_page_config(
    page_title="GastroGuard - Gastritis Assistant",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={
        'Get Help': 'https://github.com/yourusername/gastroguard-dashboard',
        'Report a bug': 'https://github.com/yourusername/gastroguard-dashboard/issues',
        'About': 'GastroGuard is a comprehensive gastritis tracking and analysis dashboard.'
    }
)

# Custom CSS for better web styling
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 2rem;
        background: linear-gradient(90deg, #1f77b4, #ff7f0e);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        background-clip: text;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .success-message {
        background-color: #d4edda;
        color: #155724;
        padding: 1rem;
        border-radius: 0.5rem;
        border: 1px solid #c3e6cb;
    }
    .warning-message {
        background-color: #fff3cd;
        color: #856404;
        padding: 1rem;
        border-radius: 0.5rem;
        border: 1px solid #ffeaa7;
    }
    .stButton > button {
        border-radius: 0.5rem;
        font-weight: bold;
    }
    .stSelectbox > div > div > select {
        border-radius: 0.5rem;
    }
    .stSlider > div > div > div > div {
        border-radius: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state for data persistence - FIXED VERSION
def initialize_session_state():
    """Initialize session state with default values"""
    if 'log_data' not in st.session_state:
        st.session_state.log_data = pd.DataFrame(columns=["Time", "Meal", "Pain Level", "Stress Level", "Remedy"])
    
    if 'filtered_data' not in st.session_state:
        st.session_state.filtered_data = None
    
    if 'current_filter' not in st.session_state:
        st.session_state.current_filter = "All"

# Initialize session state immediately
initialize_session_state()

# Helper functions with caching for better performance
def submit_data(meal, pain, stress, remedy):
    """Submit a new log entry with caching"""
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    new_entry = {
        "Time": current_time,
        "Meal": meal,
        "Pain Level": pain,
        "Stress Level": stress,
        "Remedy": remedy
    }
    
    # Create new dataframe and concatenate
    new_df = pd.DataFrame([new_entry])
    st.session_state.log_data = pd.concat([st.session_state.log_data, new_df], ignore_index=True)
    
    return True

def filter_data(period="All", start_date=None, end_date=None):
    """Filter data based on time period"""
    if st.session_state.log_data.empty:
        st.session_state.filtered_data = pd.DataFrame()
        st.session_state.current_filter = period
        return
    
    # Convert Time column to datetime if not already
    if not pd.api.types.is_datetime64_any_dtype(st.session_state.log_data["Time"]):
        st.session_state.log_data["Time"] = pd.to_datetime(st.session_state.log_data["Time"])
    
    now = datetime.now()
    
    if period == "All":
        st.session_state.filtered_data = st.session_state.log_data.copy()
    elif period == "Today":
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        st.session_state.filtered_data = st.session_state.log_data[
            st.session_state.log_data["Time"] >= today_start
        ]
    elif period == "This Week":
        days_since_monday = now.weekday()
        week_start = now - timedelta(days=days_since_monday)
        week_start = week_start.replace(hour=0, minute=0, second=0, microsecond=0)
        st.session_state.filtered_data = st.session_state.log_data[
            st.session_state.log_data["Time"] >= week_start
        ]
    elif period == "This Month":
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        st.session_state.filtered_data = st.session_state.log_data[
            st.session_state.log_data["Time"] >= month_start
        ]
    elif period == "Last 7 Days":
        week_ago = now - timedelta(days=7)
        st.session_state.filtered_data = st.session_state.log_data[
            st.session_state.log_data["Time"] >= week_ago
        ]
    elif period == "Last 30 Days":
        month_ago = now - timedelta(days=30)
        st.session_state.filtered_data = st.session_state.log_data[
            st.session_state.log_data["Time"] >= month_ago
        ]
    elif period == "Custom Range" and start_date and end_date:
        end_date = end_date + timedelta(days=1)  # Include the entire end date
        st.session_state.filtered_data = st.session_state.log_data[
            (st.session_state.log_data["Time"].dt.date >= start_date) & 
            (st.session_state.log_data["Time"].dt.date < end_date)
        ]
        st.session_state.current_filter = f"Custom: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}"
        return
    
    st.session_state.current_filter = period

def get_data_to_analyze():
    """Get the appropriate dataset for analysis"""
    if (st.session_state.filtered_data is not None and 
        not st.session_state.filtered_data.empty):
        return st.session_state.filtered_data
    return st.session_state.log_data

@st.cache_data
def create_trend_chart(data):
    """Create pain and stress trend chart with caching"""
    if data.empty:
        return None
    
    # Ensure Time column is datetime
    if not pd.api.types.is_datetime64_any_dtype(data["Time"]):
        data["Time"] = pd.to_datetime(data["Time"])
    
    # Create subplot
    fig = make_subplots(
        rows=2, cols=1,
        subplot_titles=(
            f"Pain & Stress Levels Over Time ({st.session_state.current_filter})",
            "Most Common Meals/Foods"
        ),
        vertical_spacing=0.1
    )
    
    # Pain and stress levels over time
    fig.add_trace(
        go.Scatter(
            x=data["Time"], 
            y=data["Pain Level"], 
            mode='lines+markers',
            name='Pain Level',
            line=dict(color='red', width=2)
        ),
        row=1, col=1
    )
    
    fig.add_trace(
        go.Scatter(
            x=data["Time"], 
            y=data["Stress Level"], 
            mode='lines+markers',
            name='Stress Level',
            line=dict(color='blue', width=2)
        ),
        row=1, col=1
    )
    
    # Meal frequency analysis
    if not data.empty:
        meal_counts = data["Meal"].value_counts().head(10)
        fig.add_trace(
            go.Bar(
                x=meal_counts.index,
                y=meal_counts.values,
                name='Meal Frequency',
                marker_color='skyblue'
            ),
            row=2, col=1
        )
    
    fig.update_layout(
        height=600,
        showlegend=True,
        title_text="GastroGuard Analytics Dashboard",
        template="plotly_white"
    )
    
    fig.update_xaxes(title_text="Time", row=1, col=1)
    fig.update_yaxes(title_text="Level", row=1, col=1)
    fig.update_xaxes(title_text="Meals", row=2, col=1)
    fig.update_yaxes(title_text="Frequency", row=2, col=1)
    
    return fig

@st.cache_data
def analyze_pain_triggers(data):
    """Analyze pain triggers and remedy effectiveness with caching"""
    if data.empty:
        return None, None, None
    
    # Food analysis
    food_analysis = data.groupby('Meal').agg({
        'Pain Level': ['mean', 'count', 'max', 'min'],
        'Stress Level': 'mean'
    }).round(2)
    
    # Flatten column names
    food_analysis.columns = ['Avg_Pain', 'Count', 'Max_Pain', 'Min_Pain', 'Avg_Stress']
    food_analysis = food_analysis.reset_index()
    food_analysis = food_analysis.sort_values('Avg_Pain', ascending=False)
    
    # Remedy analysis
    remedy_analysis = data.groupby('Remedy').agg({
        'Pain Level': ['mean', 'count', 'max', 'min'],
        'Stress Level': 'mean'
    }).round(2)
    
    # Flatten column names
    remedy_analysis.columns = ['Avg_Pain', 'Count', 'Max_Pain', 'Min_Pain', 'Avg_Stress']
    remedy_analysis = remedy_analysis.reset_index()
    remedy_analysis = remedy_analysis.sort_values('Avg_Pain', ascending=True)
    
    return food_analysis, remedy_analysis

@st.cache_data
def simulate_gastritis(stress, last_meal_hours):
    """Simulate gastritis symptoms with caching"""
    # Parameters
    k_s = 0.08
    k_f = 0.1
    k_h = 0.05
    hunger = 1 if last_meal_hours > 4 else 0
    D = k_s * stress + k_f * hunger

    def gastritis_ode(t, S):
        return D - k_h * (1 - S)

    S0 = [0.4]
    t_span = (0, 48)
    t_eval = np.linspace(0, 48, 300)

    sol = solve_ivp(gastritis_ode, t_span, S0, t_eval=t_eval)
    T = sol.t
    S = sol.y[0]
    
    return T, S

# Main app
def main():
    st.markdown('<h1 class="main-header">🏥 GastroGuard - Gastritis Assistant</h1>', unsafe_allow_html=True)
    
    # Add a welcome message for new users - FIXED: Proper session state access
    if st.session_state.log_data.empty:
        st.info("👋 Welcome to GastroGuard! Start by logging your first entry in the '📝 Log Entry' page.")
    
    # Sidebar for navigation
    st.sidebar.title("Navigation")
    page = st.sidebar.selectbox(
        "Choose a page",
        ["📊 Dashboard", "📝 Log Entry", "📈 Analytics", "🔬 Pain Analysis", "🧪 Simulation", "📋 Data Export"]
    )
    
    # Add helpful info in sidebar
    st.sidebar.markdown("---")
    st.sidebar.markdown("### 💡 Quick Tips")
    st.sidebar.markdown("- Log entries regularly for better insights")
    st.sidebar.markdown("- Use filters to focus on specific time periods")
    st.sidebar.markdown("- Export data to share with healthcare providers")
    
    # Dashboard page
    if page == "📊 Dashboard":
        st.header("📊 Dashboard Overview")
        
        # Filter section
        st.subheader("Time Filters")
        col1, col2, col3 = st.columns(3)
        
        with col1:
            if st.button("All", use_container_width=True):
                filter_data("All")
            if st.button("Today", use_container_width=True):
                filter_data("Today")
            if st.button("This Week", use_container_width=True):
                filter_data("This Week")
        
        with col2:
            if st.button("This Month", use_container_width=True):
                filter_data("This Month")
            if st.button("Last 7 Days", use_container_width=True):
                filter_data("Last 7 Days")
            if st.button("Last 30 Days", use_container_width=True):
                filter_data("Last 30 Days")
        
        with col3:
            st.write("Custom Range:")
            start_date = st.date_input("Start Date", value=datetime.now().date())
            end_date = st.date_input("End Date", value=datetime.now().date())
            if st.button("Apply Custom Filter", use_container_width=True):
                filter_data("Custom Range", start_date, end_date)
        
        # Filter info
        data_to_show = get_data_to_analyze()
        if not data_to_show.empty:
            st.success(f"Filter: {st.session_state.current_filter} | Records: {len(data_to_show)}")
        else:
            st.warning(f"Filter: {st.session_state.current_filter} | No data in selected period")
        
        # Metrics
        if not data_to_show.empty:
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.metric("Total Entries", len(data_to_show))
            
            with col2:
                avg_pain = data_to_show["Pain Level"].mean()
                st.metric("Avg Pain Level", f"{avg_pain:.1f}/10")
            
            with col3:
                avg_stress = data_to_show["Stress Level"].mean()
                st.metric("Avg Stress Level", f"{avg_stress:.1f}/10")
            
            with col4:
                unique_foods = data_to_show["Meal"].nunique()
                st.metric("Unique Foods", unique_foods)
        
        # Charts
        if not data_to_show.empty:
            st.subheader("Trends & Analytics")
            fig = create_trend_chart(data_to_show)
            if fig:
                st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No data available to display. Please log some entries first.")
    
    # Log Entry page
    elif page == "📝 Log Entry":
        st.header("📝 Log New Entry")
        
        with st.form("log_entry_form"):
            meal = st.text_input("Meal/Food Consumed:", placeholder="e.g., Pizza, Coffee, Salad...")
            pain = st.slider("Pain Level (0-10)", 0, 10, 5, help="0 = No pain, 10 = Severe pain")
            stress = st.slider("Stress Level (0-10)", 0, 10, 5, help="0 = No stress, 10 = High stress")
            remedy = st.text_input("Remedy Used:", placeholder="e.g., Antacid, Rest, Water...")
            
            submitted = st.form_submit_button("Log Entry", type="primary")
            
            if submitted:
                if meal and remedy:
                    success = submit_data(meal, pain, stress, remedy)
                    if success:
                        st.success("✅ Data logged successfully!")
                        st.balloons()
                else:
                    st.error("Please fill in all fields.")
    
    # Analytics page
    elif page == "📈 Analytics":
        st.header("📈 Detailed Analytics")
        
        data_to_analyze = get_data_to_analyze()
        
        if data_to_analyze.empty:
            st.warning("No data available for analysis.")
            return
        
        # Statistics
        col1, col2 = st.columns(2)
        
        with col1:
            st.subheader("📊 Statistics")
            avg_pain = data_to_analyze["Pain Level"].mean()
            avg_stress = data_to_analyze["Stress Level"].mean()
            total_entries = len(data_to_analyze)
            
            st.metric("Total Entries", total_entries)
            st.metric("Average Pain Level", f"{avg_pain:.1f}/10")
            st.metric("Average Stress Level", f"{avg_stress:.1f}/10")
            
            # Most common remedies
            common_remedies = data_to_analyze["Remedy"].value_counts().head(5)
            st.write("**Most Common Remedies:**")
            for remedy, count in common_remedies.items():
                st.write(f"• {remedy}: {count} times")
        
        with col2:
            st.subheader("⏰ Time Analysis")
            # Time-based analysis
            if not pd.api.types.is_datetime64_any_dtype(data_to_analyze["Time"]):
                data_to_analyze["Time"] = pd.to_datetime(data_to_analyze["Time"])
            
            data_to_analyze["Hour"] = data_to_analyze["Time"].dt.hour
            peak_hours = data_to_analyze.groupby("Hour")["Pain Level"].mean().sort_values(ascending=False).head(3)
            
            st.write("**Peak Pain Hours:**")
            for hour, pain in peak_hours.items():
                st.write(f"• Hour {hour}: {pain:.1f} avg pain")
        
        # Pain level distribution
        st.subheader("📊 Pain Level Distribution")
        fig = px.histogram(data_to_analyze, x="Pain Level", nbins=11, 
                          title="Distribution of Pain Levels",
                          template="plotly_white")
        st.plotly_chart(fig, use_container_width=True)
    
    # Pain Analysis page
    elif page == "🔬 Pain Analysis":
        st.header("🔬 Pain Trigger Analysis")
        
        data_to_analyze = get_data_to_analyze()
        
        if data_to_analyze.empty:
            st.warning("No data available for analysis.")
            return
        
        food_analysis, remedy_analysis = analyze_pain_triggers(data_to_analyze)
        
        if food_analysis is not None:
            # Food analysis
            st.subheader("🍽️ Food Pain Analysis")
            st.dataframe(food_analysis, use_container_width=True)
            
            # Food pain chart
            fig = px.bar(food_analysis.head(10), x='Meal', y='Avg_Pain', 
                        title="Average Pain Level by Food/Meal",
                        color='Avg_Pain', color_continuous_scale='Reds',
                        template="plotly_white")
            fig.update_xaxes(tickangle=45)
            st.plotly_chart(fig, use_container_width=True)
            
            # Remedy analysis
            st.subheader("💊 Remedy Effectiveness")
            st.dataframe(remedy_analysis, use_container_width=True)
            
            # Remedy effectiveness chart
            fig = px.bar(remedy_analysis.head(10), x='Remedy', y='Avg_Pain', 
                        title="Average Pain Level by Remedy (Lower is Better)",
                        color='Avg_Pain', color_continuous_scale='Greens',
                        template="plotly_white")
            fig.update_xaxes(tickangle=45)
            st.plotly_chart(fig, use_container_width=True)
            
            # Summary
            st.subheader("📋 Analysis Summary")
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.write("**🚨 Top 5 Pain-Triggering Foods:**")
                for i, (_, row) in enumerate(food_analysis.head(5).iterrows(), 1):
                    st.write(f"{i}. {row['Meal']} (Avg Pain: {row['Avg_Pain']:.1f}/10)")
            
            with col2:
                st.write("**✅ Top 5 Most Effective Remedies:**")
                for i, (_, row) in enumerate(remedy_analysis.head(5).iterrows(), 1):
                    st.write(f"{i}. {row['Remedy']} (Avg Pain: {row['Avg_Pain']:.1f}/10)")
            
            # Recommendations
            st.subheader("💡 Recommendations")
            if not food_analysis.empty:
                worst_food = food_analysis.iloc[0]['Meal']
                st.write(f"• **AVOID:** {worst_food} (highest pain trigger)")
            
            if not remedy_analysis.empty:
                best_remedy = remedy_analysis.iloc[0]['Remedy']
                st.write(f"• **USE:** {best_remedy} (most effective remedy)")
            
            if data_to_analyze['Pain Level'].mean() > 6:
                st.write("• **Consider consulting a healthcare provider**")
            elif data_to_analyze['Pain Level'].mean() > 4:
                st.write("• **Monitor your diet more closely**")
            else:
                st.write("• **Your current management strategy appears effective**")
    
    # Simulation page
    elif page == "🧪 Simulation":
        st.header("🧪 Gastritis Simulation")
        
        st.write("This simulation predicts gastritis symptoms based on your current stress level and time since last meal.")
        
        col1, col2 = st.columns(2)
        
        with col1:
            stress = st.slider("Current Stress Level (0-10)", 0, 10, 5)
        
        with col2:
            # Determine hours since last meal
            if st.session_state.log_data.empty:
                last_meal_hours = st.number_input("Hours since last meal", 0, 24, 5)
            else:
                last_meal = st.session_state.log_data.iloc[-1]["Time"]
                last_meal = pd.to_datetime(last_meal)
                delta = datetime.now() - last_meal
                last_meal_hours = delta.total_seconds() / 3600
                st.write(f"**Hours since last meal:** {last_meal_hours:.1f}")
        
        if st.button("Run Simulation", type="primary"):
            T, S = simulate_gastritis(stress, last_meal_hours)
            
            # Plot
            fig = go.Figure()
            fig.add_trace(go.Scatter(x=T, y=S, mode='lines', name='Symptom Severity',
                                   line=dict(color='red', width=3)))
            fig.update_layout(
                title="Simulated Gastritis Severity Over Time",
                xaxis_title="Time (hours)",
                yaxis_title="Symptom Severity (0–1)",
                yaxis=dict(range=[0, 1]),
                template="plotly_white"
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Results
            final = S[-1]
            st.subheader("Simulation Results")
            
            if final < 0.3:
                st.success("✅ **Mild symptoms expected.** Stay hydrated and rest.")
            elif final < 0.6:
                st.warning("⚠️ **Moderate symptoms.** Avoid irritants like caffeine or stress.")
            else:
                st.error("🚨 **High severity predicted.** Consider medication or medical advice.")
            
            st.metric("Final Severity", f"{final:.2f}")
    
    # Data Export page
    elif page == "📋 Data Export":
        st.header("📋 Data Export")
        
        data_to_export = get_data_to_analyze()
        
        if data_to_export.empty:
            st.warning("No data available to export.")
            return
        
        st.write(f"Exporting data for filter: **{st.session_state.current_filter}**")
        st.write(f"Total records: **{len(data_to_export)}**")
        
        # Show data preview
        st.subheader("Data Preview")
        st.dataframe(data_to_export, use_container_width=True)
        
        # Export options
        col1, col2 = st.columns(2)
        
        with col1:
            st.subheader("📥 Download Data")
            csv = data_to_export.to_csv(index=False)
            st.download_button(
                label="Download CSV",
                data=csv,
                file_name=f"gastroguard_data_{st.session_state.current_filter.replace(' ', '_')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                mime="text/csv"
            )
        
        with col2:
            st.subheader("📊 Export Analysis")
            if not data_to_export.empty:
                food_analysis, remedy_analysis = analyze_pain_triggers(data_to_export)
                
                if food_analysis is not None:
                    # Create combined analysis
                    food_analysis['Type'] = 'Food'
                    remedy_analysis['Type'] = 'Remedy'
                    combined_analysis = pd.concat([food_analysis, remedy_analysis])
                    
                    csv_analysis = combined_analysis.to_csv(index=False)
                    st.download_button(
                        label="Download Analysis",
                        data=csv_analysis,
                        file_name=f"gastroguard_analysis_{st.session_state.current_filter.replace(' ', '_')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
                        mime="text/csv"
                    )

if __name__ == "__main__":
    main()
