import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
import numpy as np
from scipy.integrate import solve_ivp

# Page configuration
st.set_page_config(
    page_title="GastroGuard - Gastritis Assistant",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
<style>
    .main-header {
        color: #1f77b4;
        text-align: center;
        font-size: 2.5rem;
        margin-bottom: 2rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .stButton > button {
        width: 100%;
        border-radius: 0.5rem;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'log_data' not in st.session_state:
    st.session_state.log_data = pd.DataFrame(columns=["Time", "Time_of_Ingestion", "Meal", "Pain Level", "Stress Level", "Remedy"])

if 'filtered_data' not in st.session_state:
    st.session_state.filtered_data = None

if 'current_filter' not in st.session_state:
    st.session_state.current_filter = "All"

# Helper functions
def submit_data_streamlit(meal, pain, stress, remedy, ingestion_time=None):
    """Submit a new log entry for Streamlit"""
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Use provided ingestion time or current time
    if ingestion_time is None:
        ingestion_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    new_entry = {
        "Time": current_time,
        "Time_of_Ingestion": ingestion_time,
        "Meal": meal,
        "Pain Level": pain,
        "Stress Level": stress,
        "Remedy": remedy
    }

    st.session_state.log_data = pd.concat([
        st.session_state.log_data,
        pd.DataFrame([new_entry])
    ], ignore_index=True)

    return True

def filter_data_streamlit(period="All", start_date=None, end_date=None):
    """Filter data based on time period for Streamlit"""
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

def create_trend_chart(data):
    """Create pain and stress trend chart"""
    if data.empty:
        return None

    # Use Time_of_Ingestion if available, otherwise fall back to Time
    time_column = "Time_of_Ingestion" if "Time_of_Ingestion" in data.columns else "Time"
    
    # Ensure time column is datetime
    if not pd.api.types.is_datetime64_any_dtype(data[time_column]):
        data[time_column] = pd.to_datetime(data[time_column])

    # Create subplot
    time_label = "Time of Ingestion" if time_column == "Time_of_Ingestion" else "Time"
    fig = make_subplots(
        rows=2, cols=1,
        subplot_titles=(
            f"Pain & Stress Levels Over {time_label} ({st.session_state.current_filter})",
            "Most Common Meals/Foods"
        ),
        vertical_spacing=0.1
    )

    # Pain and stress levels over time
    fig.add_trace(
        go.Scatter(
            x=data[time_column],
            y=data["Pain Level"],
            mode='lines+markers',
            name='Pain Level',
            line=dict(color='red', width=2)
        ),
        row=1, col=1
    )

    fig.add_trace(
        go.Scatter(
            x=data[time_column],
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
        title_text="GastroGuard Analytics Dashboard"
    )

    fig.update_xaxes(title_text=time_label, row=1, col=1)
    fig.update_yaxes(title_text="Level", row=1, col=1)
    fig.update_xaxes(title_text="Meals", row=2, col=1)
    fig.update_yaxes(title_text="Frequency", row=2, col=1)

    return fig

def analyze_pain_triggers_streamlit(data):
    """Analyze pain triggers and remedy effectiveness for Streamlit"""
    if data.empty:
        return None, None

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

def simulate_gastritis_streamlit(initial_severity, stress_level, food_irritation, time_hours=24):
    """Simulate gastritis progression for Streamlit"""
    
    # Gastritis model parameters
    def gastritis_model(t, S):
        # S: symptom severity (0-1)
        # Parameters
        stress_factor = stress_level / 10.0  # Normalize stress to 0-1
        food_factor = food_irritation / 10.0  # Normalize food irritation to 0-1
        
        # Natural healing rate
        healing_rate = 0.1
        
        # Stress exacerbation
        stress_exacerbation = stress_factor * 0.2
        
        # Food irritation effect
        food_effect = food_factor * 0.3 * np.exp(-t/6)  # Peak effect at 6 hours
        
        # Rate of change
        dS_dt = -healing_rate + stress_exacerbation + food_effect
        
        return dS_dt
    
    # Solve the differential equation
    t_span = (0, time_hours)
    t_eval = np.linspace(0, time_hours, 100)
    
    solution = solve_ivp(
        gastritis_model, 
        t_span, 
        [initial_severity], 
        t_eval=t_eval,
        method='RK45'
    )
    
    S = solution.y[0]
    t = solution.t
    
    return t, S

# Main Streamlit app
def main():
    st.markdown('<h1 class="main-header">🏥 GastroGuard - Gastritis Assistant</h1>', unsafe_allow_html=True)

    # Sidebar for navigation
    st.sidebar.title("Navigation")
    page = st.sidebar.selectbox(
        "Choose a page",
        ["📊 Dashboard", "📝 Log Entry", "📈 Analytics", "⏰ Timeline", "🔬 Pain Analysis", "🧪 Simulation", "📋 Data Export"]
    )

    # Dashboard page
    if page == "📊 Dashboard":
        st.header("📊 Dashboard Overview")

        # Filter section
        st.subheader("Time Filters")
        col1, col2, col3 = st.columns(3)

        with col1:
            if st.button("All", use_container_width=True):
                filter_data_streamlit("All")
            if st.button("Today", use_container_width=True):
                filter_data_streamlit("Today")
            if st.button("This Week", use_container_width=True):
                filter_data_streamlit("This Week")

        with col2:
            if st.button("This Month", use_container_width=True):
                filter_data_streamlit("This Month")
            if st.button("Last 7 Days", use_container_width=True):
                filter_data_streamlit("Last 7 Days")
            if st.button("Last 30 Days", use_container_width=True):
                filter_data_streamlit("Last 30 Days")

        with col3:
            st.write("Custom Range:")
            start_date = st.date_input("Start Date", value=datetime.now().date())
            end_date = st.date_input("End Date", value=datetime.now().date())
            if st.button("Apply Custom Filter", use_container_width=True):
                filter_data_streamlit("Custom Range", start_date, end_date)

        # Filter info
        data_to_show = get_data_to_analyze()
        if not data_to_show.empty:
            st.info(f"Filter: {st.session_state.current_filter} | Records: {len(data_to_show)}")
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
            meal = st.text_input("Meal/Food Consumed:")
            
            # Time of ingestion
            st.subheader("⏰ Time of Ingestion")
            col1, col2 = st.columns(2)
            with col1:
                ingestion_date = st.date_input("Date", value=datetime.now().date())
            with col2:
                ingestion_time = st.time_input("Time", value=datetime.now().time())
            
            pain = st.slider("Pain Level (0-10)", 0, 10, 5)
            stress = st.slider("Stress Level (0-10)", 0, 10, 5)
            remedy = st.text_input("Remedy Used:")

            submitted = st.form_submit_button("Log Entry", type="primary")

            if submitted:
                if meal and remedy:
                    # Combine date and time for ingestion
                    ingestion_datetime = datetime.combine(ingestion_date, ingestion_time)
                    ingestion_time_str = ingestion_datetime.strftime("%Y-%m-%d %H:%M:%S")
                    
                    success = submit_data_streamlit(meal, pain, stress, remedy, ingestion_time_str)
                    if success:
                        st.success("✅ Data logged successfully!")
                        st.balloons()
                else:
                    st.error("Please fill in all fields.")
        
        # Retroactive logging section
        st.header("📅 Retroactive Log Entry")
        st.write("Log entries for past dates")
        
        with st.form("retroactive_log_form"):
            retro_meal = st.text_input("Meal/Food Consumed (Retroactive):")
            
            # Retroactive time of ingestion
            st.subheader("⏰ Retroactive Time of Ingestion")
            col1, col2 = st.columns(2)
            with col1:
                retro_date = st.date_input("Date (Retroactive)", value=datetime.now().date())
            with col2:
                retro_time = st.time_input("Time (Retroactive)", value=datetime.now().time())
            
            retro_pain = st.slider("Pain Level (0-10) (Retroactive)", 0, 10, 5)
            retro_stress = st.slider("Stress Level (0-10) (Retroactive)", 0, 10, 5)
            retro_remedy = st.text_input("Remedy Used (Retroactive):")

            retro_submitted = st.form_submit_button("Log Retroactive Entry", type="secondary")

            if retro_submitted:
                if retro_meal and retro_remedy:
                    # Combine date and time for retroactive ingestion
                    retro_ingestion_datetime = datetime.combine(retro_date, retro_time)
                    retro_ingestion_time_str = retro_ingestion_datetime.strftime("%Y-%m-%d %H:%M:%S")
                    
                    success = submit_data_streamlit(retro_meal, retro_pain, retro_stress, retro_remedy, retro_ingestion_time_str)
                    if success:
                        st.success(f"✅ Retroactive entry logged for {retro_date.strftime('%Y-%m-%d')}!")
                        st.balloons()
                else:
                    st.error("Please fill in all fields for retroactive entry.")

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
            # Time-based analysis (using time of ingestion if available)
            if "Time_of_Ingestion" in data_to_analyze.columns:
                if not pd.api.types.is_datetime64_any_dtype(data_to_analyze["Time_of_Ingestion"]):
                    data_to_analyze["Time_of_Ingestion"] = pd.to_datetime(data_to_analyze["Time_of_Ingestion"])
                
                data_to_analyze["Hour"] = data_to_analyze["Time_of_Ingestion"].dt.hour
                peak_hours = data_to_analyze.groupby("Hour")["Pain Level"].mean().sort_values(ascending=False).head(3)
                
                st.write("**Peak Pain Hours (Ingestion Time):**")
                for hour, pain in peak_hours.items():
                    st.write(f"• Hour {hour}: {pain:.1f} avg pain")
                
                # Meal timing analysis
                data_to_analyze["Meal_Time"] = data_to_analyze["Time_of_Ingestion"].dt.strftime("%H:%M")
                meal_timing = data_to_analyze.groupby("Meal_Time")["Pain Level"].mean().sort_values(ascending=False).head(3)
                st.write("**Peak Pain Meal Times:**")
                for time, pain in meal_timing.items():
                    st.write(f"• {time}: {pain:.1f} avg pain")
            else:
                # Fallback to original Time column
                if not pd.api.types.is_datetime64_any_dtype(data_to_analyze["Time"]):
                    data_to_analyze["Time"] = pd.to_datetime(data_to_analyze["Time"])

                data_to_analyze["Hour"] = data_to_analyze["Time"].dt.hour
                peak_hours = data_to_analyze.groupby("Hour")["Pain Level"].mean().sort_values(ascending=False).head(3)

                st.write("**Peak Pain Hours (Log Time):**")
                for hour, pain in peak_hours.items():
                    st.write(f"• Hour {hour}: {pain:.1f} avg pain")

        # Pain level distribution
        st.subheader("📊 Pain Level Distribution")
        fig = px.histogram(data_to_analyze, x="Pain Level", nbins=11,
                           title="Distribution of Pain Levels")
        st.plotly_chart(fig, use_container_width=True)

    # Timeline page
    elif page == "⏰ Timeline":
        st.header("⏰ Timeline Analysis")
        st.write("Analyze pain and stress levels over time of ingestion")

        data_to_analyze = get_data_to_analyze()

        if data_to_analyze.empty:
            st.warning("No data available for timeline analysis.")
            return

        # Ensure Time_of_Ingestion column exists and is datetime
        if "Time_of_Ingestion" not in data_to_analyze.columns:
            st.error("No ingestion time data available. Please log entries with time of ingestion.")
            return

        if not pd.api.types.is_datetime64_any_dtype(data_to_analyze["Time_of_Ingestion"]):
            data_to_analyze["Time_of_Ingestion"] = pd.to_datetime(data_to_analyze["Time_of_Ingestion"])

        # Timeline period selection
        st.subheader("📅 Timeline Period")
        period = st.selectbox(
            "Select timeline period:",
            ["Daily (Last 24 Hours)", "Weekly (Last 7 Days)", "Monthly (Last 30 Days)", "All Time"]
        )

        # Filter data based on selected period
        now = datetime.now()
        
        if period == "Daily (Last 24 Hours)":
            start_time = now - timedelta(days=1)
            filtered_timeline = data_to_analyze[data_to_analyze["Time_of_Ingestion"] >= start_time]
            title_suffix = " (Last 24 Hours)"
        elif period == "Weekly (Last 7 Days)":
            start_time = now - timedelta(days=7)
            filtered_timeline = data_to_analyze[data_to_analyze["Time_of_Ingestion"] >= start_time]
            title_suffix = " (Last 7 Days)"
        elif period == "Monthly (Last 30 Days)":
            start_time = now - timedelta(days=30)
            filtered_timeline = data_to_analyze[data_to_analyze["Time_of_Ingestion"] >= start_time]
            title_suffix = " (Last 30 Days)"
        else:  # All Time
            filtered_timeline = data_to_analyze
            title_suffix = " (All Time)"

        if filtered_timeline.empty:
            st.warning(f"No data available for {period} timeline.")
            return

        # Timeline statistics
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Total Entries", len(filtered_timeline))
        with col2:
            avg_pain = filtered_timeline["Pain Level"].mean()
            st.metric("Average Pain", f"{avg_pain:.1f}/10")
        with col3:
            avg_stress = filtered_timeline["Stress Level"].mean()
            st.metric("Average Stress", f"{avg_stress:.1f}/10")

        # Timeline plots
        st.subheader("📈 Timeline Plots")

        # Pain Level Timeline
        fig_pain = px.scatter(
            filtered_timeline, 
            x="Time_of_Ingestion", 
            y="Pain Level",
            color="Pain Level",
            color_continuous_scale="Reds",
            title=f"Pain Level Over Time of Ingestion{title_suffix}",
            labels={"Time_of_Ingestion": "Time of Ingestion", "Pain Level": "Pain Level"}
        )
        fig_pain.update_layout(xaxis_title="Time of Ingestion", yaxis_title="Pain Level")
        st.plotly_chart(fig_pain, use_container_width=True)

        # Stress Level Timeline
        fig_stress = px.scatter(
            filtered_timeline, 
            x="Time_of_Ingestion", 
            y="Stress Level",
            color="Stress Level",
            color_continuous_scale="Blues",
            title=f"Stress Level Over Time of Ingestion{title_suffix}",
            labels={"Time_of_Ingestion": "Time of Ingestion", "Stress Level": "Stress Level"}
        )
        fig_stress.update_layout(xaxis_title="Time of Ingestion", yaxis_title="Stress Level")
        st.plotly_chart(fig_stress, use_container_width=True)

        # Combined timeline
        st.subheader("🔄 Combined Timeline")
        fig_combined = go.Figure()
        
        fig_combined.add_trace(go.Scatter(
            x=filtered_timeline["Time_of_Ingestion"],
            y=filtered_timeline["Pain Level"],
            mode='lines+markers',
            name='Pain Level',
            line=dict(color='red', width=2),
            marker=dict(size=8, color='red')
        ))
        
        fig_combined.add_trace(go.Scatter(
            x=filtered_timeline["Time_of_Ingestion"],
            y=filtered_timeline["Stress Level"],
            mode='lines+markers',
            name='Stress Level',
            line=dict(color='blue', width=2),
            marker=dict(size=8, color='blue'),
            yaxis='y2'
        ))
        
        fig_combined.update_layout(
            title=f"Pain and Stress Levels Over Time{title_suffix}",
            xaxis_title="Time of Ingestion",
            yaxis=dict(title="Pain Level", side="left"),
            yaxis2=dict(title="Stress Level", side="right", overlaying="y"),
            hovermode='x unified'
        )
        
        st.plotly_chart(fig_combined, use_container_width=True)

        # Peak times analysis
        st.subheader("⏰ Peak Times Analysis")
        col1, col2 = st.columns(2)
        
        with col1:
            peak_pain_time = filtered_timeline.loc[filtered_timeline['Pain Level'].idxmax(), 'Time_of_Ingestion']
            st.write(f"**Peak Pain Time:** {peak_pain_time.strftime('%Y-%m-%d %H:%M')}")
            
            # Hourly pain analysis
            filtered_timeline["Hour"] = filtered_timeline["Time_of_Ingestion"].dt.hour
            hourly_pain = filtered_timeline.groupby("Hour")["Pain Level"].mean().sort_values(ascending=False)
            st.write("**Peak Pain Hours:**")
            for hour, pain in hourly_pain.head(3).items():
                st.write(f"• Hour {hour}: {pain:.1f} avg pain")
        
        with col2:
            peak_stress_time = filtered_timeline.loc[filtered_timeline['Stress Level'].idxmax(), 'Time_of_Ingestion']
            st.write(f"**Peak Stress Time:** {peak_stress_time.strftime('%Y-%m-%d %H:%M')}")
            
            # Hourly stress analysis
            hourly_stress = filtered_timeline.groupby("Hour")["Stress Level"].mean().sort_values(ascending=False)
            st.write("**Peak Stress Hours:**")
            for hour, stress in hourly_stress.head(3).items():
                st.write(f"• Hour {hour}: {stress:.1f} avg stress")

    # Pain Analysis page
    elif page == "🔬 Pain Analysis":
        st.header("🔬 Pain Trigger Analysis")

        data_to_analyze = get_data_to_analyze()

        if data_to_analyze.empty:
            st.warning("No data available for analysis.")
            return

        food_analysis, remedy_analysis = analyze_pain_triggers_streamlit(data_to_analyze)

        if food_analysis is not None:
            # Food analysis
            st.subheader("🍽️ Food Pain Analysis")
            st.dataframe(food_analysis, use_container_width=True)

            # Food pain chart
            fig = px.bar(food_analysis.head(10), x='Meal', y='Avg_Pain',
                         title="Average Pain Level by Food/Meal",
                         color='Avg_Pain', color_continuous_scale='Reds')
            fig.update_xaxes(tickangle=45)
            st.plotly_chart(fig, use_container_width=True)

            # Remedy analysis
            st.subheader("💊 Remedy Effectiveness")
            st.dataframe(remedy_analysis, use_container_width=True)

            # Remedy effectiveness chart
            fig = px.bar(remedy_analysis.head(10), x='Remedy', y='Avg_Pain',
                         title="Average Pain Level by Remedy (Lower is Better)",
                         color='Avg_Pain', color_continuous_scale='Greens')
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
                st.write("• **Your pain levels are well managed**")

    # Simulation page
    elif page == "🧪 Simulation":
        st.header("🧪 Gastritis Simulation")
        st.write("Simulate gastritis progression based on various factors")

        col1, col2 = st.columns(2)

        with col1:
            st.subheader("📊 Input Parameters")
            initial_severity = st.slider("Initial Severity (0-1)", 0.0, 1.0, 0.3, 0.1)
            stress_level = st.slider("Stress Level (0-10)", 0, 10, 5)
            food_irritation = st.slider("Food Irritation Level (0-10)", 0, 10, 3)
            time_hours = st.slider("Simulation Time (hours)", 6, 48, 24)

        with col2:
            st.subheader("📈 Simulation Results")
            
            if st.button("Run Simulation", type="primary"):
                t, S = simulate_gastritis_streamlit(initial_severity, stress_level, food_irritation, time_hours)
                
                # Create simulation plot
                fig = go.Figure()
                fig.add_trace(go.Scatter(x=t, y=S, mode='lines+markers',
                                         line=dict(color='red', width=3)))
                fig.update_layout(
                    title="Simulated Gastritis Severity Over Time",
                    xaxis_title="Time (hours)",
                    yaxis_title="Symptom Severity (0–1)",
                    yaxis=dict(range=[0, 1])
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
                food_analysis, remedy_analysis = analyze_pain_triggers_streamlit(data_to_export)

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
