import tkinter as tk
from tkinter import ttk, messagebox
from datetime import datetime, timedelta
import pandas as pd
import matplotlib.pyplot as plt
from scipy.integrate import solve_ivp
import numpy as np
from tkcalendar import DateEntry
import calendar

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

# DataFrame to store logs
log_data = pd.DataFrame(columns=["Time", "Time_of_Ingestion", "Meal", "Pain Level", "Stress Level", "Remedy"])

# Global variables for filtering
filtered_data = None
current_filter = "All"


# Submit log entry
def submit_data():
    global log_data
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Get time of ingestion from the time picker
    ingestion_time = ingestion_time_entry.get()
    if not ingestion_time:
        ingestion_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    meal = meal_entry.get()
    pain = pain_scale.get()
    stress = stress_scale.get()
    remedy = remedy_entry.get()

    new_entry = {
        "Time": current_time,
        "Time_of_Ingestion": ingestion_time,
        "Meal": meal,
        "Pain Level": pain,
        "Stress Level": stress,
        "Remedy": remedy
    }
    log_data = log_data.append(new_entry, ignore_index=True)
    status_label.config(text="Data logged successfully!")
    update_filter_display()


# Retroactive logging function
def retroactive_log():
    """Allow users to log entries for past dates"""
    global log_data
    
    # Create retroactive logging window
    retro_window = tk.Toplevel(root)
    retro_window.title("Retroactive Log Entry")
    retro_window.geometry("400x500")
    
    # Date picker for retroactive entry
    tk.Label(retro_window, text="Select Date for Entry:", font=("Arial", 12, "bold")).pack(pady=10)
    retro_date = DateEntry(retro_window, width=20, background='darkblue', foreground='white', borderwidth=2)
    retro_date.pack(pady=5)
    
    # Time picker for ingestion
    tk.Label(retro_window, text="Time of Ingestion:").pack(pady=5)
    time_frame = ttk.Frame(retro_window)
    time_frame.pack(pady=5)
    
    hour_var = tk.StringVar(value="12")
    minute_var = tk.StringVar(value="00")
    
    tk.Label(time_frame, text="Hour:").pack(side=tk.LEFT)
    hour_spin = tk.Spinbox(time_frame, from_=0, to=23, width=5, textvariable=hour_var)
    hour_spin.pack(side=tk.LEFT, padx=5)
    
    tk.Label(time_frame, text="Minute:").pack(side=tk.LEFT)
    minute_spin = tk.Spinbox(time_frame, from_=0, to=59, width=5, textvariable=minute_var)
    minute_spin.pack(side=tk.LEFT, padx=5)
    
    # Input fields
    tk.Label(retro_window, text="Meal/Food Consumed:").pack(pady=5)
    retro_meal = tk.Entry(retro_window, width=30)
    retro_meal.pack(pady=5)
    
    tk.Label(retro_window, text="Pain Level (0-10):").pack(pady=5)
    retro_pain = tk.Scale(retro_window, from_=0, to=10, orient="horizontal")
    retro_pain.pack(pady=5)
    
    tk.Label(retro_window, text="Stress Level (0-10):").pack(pady=5)
    retro_stress = tk.Scale(retro_window, from_=0, to=10, orient="horizontal")
    retro_stress.pack(pady=5)
    
    tk.Label(retro_window, text="Remedy Used:").pack(pady=5)
    retro_remedy = tk.Entry(retro_window, width=30)
    retro_remedy.pack(pady=5)
    
    def submit_retro_entry():
        selected_date = retro_date.get_date()
        hour = int(hour_var.get())
        minute = int(minute_var.get())
        
        # Create datetime for ingestion time
        ingestion_datetime = datetime.combine(selected_date, datetime.min.time().replace(hour=hour, minute=minute))
        ingestion_time_str = ingestion_datetime.strftime("%Y-%m-%d %H:%M:%S")
        
        # Current time for logging
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        new_entry = {
            "Time": current_time,
            "Time_of_Ingestion": ingestion_time_str,
            "Meal": retro_meal.get(),
            "Pain Level": retro_pain.get(),
            "Stress Level": retro_stress.get(),
            "Remedy": retro_remedy.get()
        }
        
        log_data = log_data.append(new_entry, ignore_index=True)
        status_label.config(text=f"Retroactive entry logged for {selected_date.strftime('%Y-%m-%d')}!")
        update_filter_display()
        retro_window.destroy()
    
    tk.Button(retro_window, text="Submit Retroactive Entry", command=submit_retro_entry, 
              bg='orange', fg='white', font=("Arial", 10, "bold")).pack(pady=20)


# Filter data based on time period
def filter_data(period="All"):
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
        # Start of current week (Monday)
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
    elif period == "Custom Range":
        # This will be handled by the custom date picker
        return

    current_filter = period
    update_filter_display()


# Custom date range filter
def custom_date_filter():
    global filtered_data, current_filter

    if log_data.empty:
        messagebox.showwarning("No Data", "No data available to filter.")
        return

    # Create custom date picker window
    date_window = tk.Toplevel(root)
    date_window.title("Select Date Range")
    date_window.geometry("300x200")

    tk.Label(date_window, text="Start Date:").pack(pady=5)
    start_date = DateEntry(date_window, width=20, background='darkblue', foreground='white', borderwidth=2)
    start_date.pack(pady=5)

    tk.Label(date_window, text="End Date:").pack(pady=5)
    end_date = DateEntry(date_window, width=20, background='darkblue', foreground='white', borderwidth=2)
    end_date.pack(pady=5)

    def apply_custom_filter():
        start = start_date.get_date()
        end = end_date.get_date() + timedelta(days=1)  # Include the entire end date

        if not pd.api.types.is_datetime64_any_dtype(log_data["Time"]):
            log_data["Time"] = pd.to_datetime(log_data["Time"])

        filtered_data = log_data[
            (log_data["Time"].dt.date >= start) &
            (log_data["Time"].dt.date < end)
            ]

        global current_filter
        current_filter = f"Custom: {start.strftime('%Y-%m-%d')} to {end.strftime('%Y-%m-%d')}"
        update_filter_display()
        date_window.destroy()

    tk.Button(date_window, text="Apply Filter", command=apply_custom_filter).pack(pady=10)


# Update the filter display label
def update_filter_display():
    if filtered_data is not None and not filtered_data.empty:
        filter_info = f"Filter: {current_filter} | Records: {len(filtered_data)}"
    else:
        filter_info = f"Filter: {current_filter} | No data in selected period"

    filter_label.config(text=filter_info)


# Show pain and stress trend graph with filtering
def show_graph():
    data_to_plot = filtered_data if filtered_data is not None and not filtered_data.empty else log_data

    if data_to_plot.empty:
        status_label.config(text="No data to plot.")
        return

    # Ensure Time column is datetime
    if not pd.api.types.is_datetime64_any_dtype(data_to_plot["Time"]):
        data_to_plot["Time"] = pd.to_datetime(data_to_plot["Time"])

    # Create figure with subplots
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))

    # Pain and stress levels over time (using time of ingestion)
    if "Time_of_Ingestion" in data_to_plot.columns:
        # Ensure Time_of_Ingestion is datetime
        if not pd.api.types.is_datetime64_any_dtype(data_to_plot["Time_of_Ingestion"]):
            data_to_plot["Time_of_Ingestion"] = pd.to_datetime(data_to_plot["Time_of_Ingestion"])
        
        data_to_plot.plot(x="Time_of_Ingestion", y=["Pain Level", "Stress Level"], kind="line", marker='o', ax=ax1)
        ax1.set_title(f"Pain & Stress Levels Over Time of Ingestion ({current_filter})")
        ax1.set_ylabel("Level")
        ax1.set_xlabel("Time of Ingestion")
    else:
        # Fallback to original Time column
        data_to_plot.plot(x="Time", y=["Pain Level", "Stress Level"], kind="line", marker='o', ax=ax1)
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

    plt.tight_layout()
    plt.show()


# Timeline function for time of ingestion vs stress and pain levels
def show_timeline():
    """Show timeline plot of time of ingestion vs stress and pain levels"""
    data_to_plot = filtered_data if filtered_data is not None and not filtered_data.empty else log_data

    if data_to_plot.empty:
        status_label.config(text="No data to plot timeline.")
        return

    # Ensure Time_of_Ingestion column is datetime
    if not pd.api.types.is_datetime64_any_dtype(data_to_plot["Time_of_Ingestion"]):
        data_to_plot["Time_of_Ingestion"] = pd.to_datetime(data_to_plot["Time_of_Ingestion"])

    # Create timeline window
    timeline_window = tk.Toplevel(root)
    timeline_window.title("Timeline Analysis")
    timeline_window.geometry("800x600")

    # Time period selection
    period_frame = ttk.Frame(timeline_window)
    period_frame.pack(fill=tk.X, padx=10, pady=10)

    tk.Label(period_frame, text="Timeline Period:", font=("Arial", 12, "bold")).pack(side=tk.LEFT, padx=5)
    
    period_var = tk.StringVar(value="Daily")
    periods = ["Daily", "Weekly", "Monthly", "All"]
    
    for period in periods:
        tk.Radiobutton(period_frame, text=period, variable=period_var, value=period).pack(side=tk.LEFT, padx=5)

    def update_timeline():
        selected_period = period_var.get()
        
        # Filter data based on selected period
        now = datetime.now()
        
        if selected_period == "Daily":
            # Last 24 hours
            start_time = now - timedelta(days=1)
            filtered_timeline = data_to_plot[data_to_plot["Time_of_Ingestion"] >= start_time]
            title_suffix = " (Last 24 Hours)"
        elif selected_period == "Weekly":
            # Last 7 days
            start_time = now - timedelta(days=7)
            filtered_timeline = data_to_plot[data_to_plot["Time_of_Ingestion"] >= start_time]
            title_suffix = " (Last 7 Days)"
        elif selected_period == "Monthly":
            # Last 30 days
            start_time = now - timedelta(days=30)
            filtered_timeline = data_to_plot[data_to_plot["Time_of_Ingestion"] >= start_time]
            title_suffix = " (Last 30 Days)"
        else:  # All
            filtered_timeline = data_to_plot
            title_suffix = " (All Time)"

        if filtered_timeline.empty:
            messagebox.showwarning("No Data", f"No data available for {selected_period} timeline.")
            return

        # Create timeline plot
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))

        # Plot 1: Time of ingestion vs Pain Level
        ax1.scatter(filtered_timeline["Time_of_Ingestion"], filtered_timeline["Pain Level"], 
                   c=filtered_timeline["Pain Level"], cmap='Reds', s=100, alpha=0.7)
        ax1.set_title(f"Time of Ingestion vs Pain Level{title_suffix}")
        ax1.set_ylabel("Pain Level")
        ax1.set_xlabel("Time of Ingestion")
        ax1.grid(True, alpha=0.3)
        
        # Add trend line for pain
        if len(filtered_timeline) > 1:
            z = np.polyfit(range(len(filtered_timeline)), filtered_timeline["Pain Level"], 1)
            p = np.poly1d(z)
            ax1.plot(filtered_timeline["Time_of_Ingestion"], p(range(len(filtered_timeline))), 
                    "r--", alpha=0.8, linewidth=2)

        # Plot 2: Time of ingestion vs Stress Level
        ax2.scatter(filtered_timeline["Time_of_Ingestion"], filtered_timeline["Stress Level"], 
                   c=filtered_timeline["Stress Level"], cmap='Blues', s=100, alpha=0.7)
        ax2.set_title(f"Time of Ingestion vs Stress Level{title_suffix}")
        ax2.set_ylabel("Stress Level")
        ax2.set_xlabel("Time of Ingestion")
        ax2.grid(True, alpha=0.3)
        
        # Add trend line for stress
        if len(filtered_timeline) > 1:
            z = np.polyfit(range(len(filtered_timeline)), filtered_timeline["Stress Level"], 1)
            p = np.poly1d(z)
            ax2.plot(filtered_timeline["Time_of_Ingestion"], p(range(len(filtered_timeline))), 
                    "b--", alpha=0.8, linewidth=2)

        plt.tight_layout()
        plt.show()

        # Show statistics
        avg_pain = filtered_timeline["Pain Level"].mean()
        avg_stress = filtered_timeline["Stress Level"].mean()
        total_entries = len(filtered_timeline)
        
        stats_text = f"""
Timeline Statistics for {selected_period}:
Total Entries: {total_entries}
Average Pain Level: {avg_pain:.1f}/10
Average Stress Level: {avg_stress:.1f}/10

Peak Pain Time: {filtered_timeline.loc[filtered_timeline['Pain Level'].idxmax(), 'Time_of_Ingestion'].strftime('%Y-%m-%d %H:%M')}
Peak Stress Time: {filtered_timeline.loc[filtered_timeline['Stress Level'].idxmax(), 'Time_of_Ingestion'].strftime('%Y-%m-%d %H:%M')}
"""
        messagebox.showinfo("Timeline Statistics", stats_text)

    # Update button
    tk.Button(timeline_window, text="Update Timeline", command=update_timeline, 
              bg='blue', fg='white', font=("Arial", 10, "bold")).pack(pady=10)

    # Initial timeline
    update_timeline()


# Show detailed statistics
def show_statistics():
    data_to_analyze = filtered_data if filtered_data is not None and not filtered_data.empty else log_data

    if data_to_analyze.empty:
        messagebox.showinfo("Statistics", "No data available for analysis.")
        return

    # Calculate statistics
    avg_pain = data_to_analyze["Pain Level"].mean()
    avg_stress = data_to_analyze["Stress Level"].mean()
    total_entries = len(data_to_analyze)

    # Most common remedies
    common_remedies = data_to_analyze["Remedy"].value_counts().head(5)
    remedy_text = "\n".join([f"• {remedy}: {count} times" for remedy, count in common_remedies.items()])

    # Time-based analysis (using time of ingestion if available)
    if "Time_of_Ingestion" in data_to_analyze.columns:
        if not pd.api.types.is_datetime64_any_dtype(data_to_analyze["Time_of_Ingestion"]):
            data_to_analyze["Time_of_Ingestion"] = pd.to_datetime(data_to_analyze["Time_of_Ingestion"])
        
        data_to_analyze["Hour"] = data_to_analyze["Time_of_Ingestion"].dt.hour
        peak_hours = data_to_analyze.groupby("Hour")["Pain Level"].mean().sort_values(ascending=False).head(3)
        peak_text = "\n".join([f"• Hour {hour}: {pain:.1f} avg pain" for hour, pain in peak_hours.items()])
        
        # Add meal timing analysis
        data_to_analyze["Meal_Time"] = data_to_analyze["Time_of_Ingestion"].dt.strftime("%H:%M")
        meal_timing = data_to_analyze.groupby("Meal_Time")["Pain Level"].mean().sort_values(ascending=False).head(3)
        meal_timing_text = "\n".join([f"• {time}: {pain:.1f} avg pain" for time, pain in meal_timing.items()])
    else:
        # Fallback to original Time column
        if not pd.api.types.is_datetime64_any_dtype(data_to_analyze["Time"]):
            data_to_analyze["Time"] = pd.to_datetime(data_to_analyze["Time"])

        data_to_analyze["Hour"] = data_to_analyze["Time"].dt.hour
        peak_hours = data_to_analyze.groupby("Hour")["Pain Level"].mean().sort_values(ascending=False).head(3)
        peak_text = "\n".join([f"• Hour {hour}: {pain:.1f} avg pain" for hour, pain in peak_hours.items()])
        meal_timing_text = "Not available (no ingestion time data)"

    stats_text = f"""
Statistics for {current_filter}:

Total Entries: {total_entries}
Average Pain Level: {avg_pain:.1f}/10
Average Stress Level: {avg_stress:.1f}/10

Most Common Remedies:
{remedy_text}

Peak Pain Hours:
{peak_text}

Peak Pain Meal Times:
{meal_timing_text}
"""

    messagebox.showinfo("Detailed Statistics", stats_text)


# Export filtered data
def export_data():
    data_to_export = filtered_data if filtered_data is not None and not filtered_data.empty else log_data

    if data_to_export.empty:
        messagebox.showwarning("No Data", "No data available to export.")
        return

    try:
        filename = f"gastroguard_data_{current_filter.replace(' ', '_')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        data_to_export.to_csv(filename, index=False)
        messagebox.showinfo("Export Successful", f"Data exported to {filename}")
    except Exception as e:
        messagebox.showerror("Export Error", f"Failed to export data: {str(e)}")


# Analyze foods and remedies by pain levels
def analyze_pain_triggers():
    data_to_analyze = filtered_data if filtered_data is not None and not filtered_data.empty else log_data

    if data_to_analyze.empty:
        messagebox.showwarning("No Data", "No data available for analysis.")
        return

    # Create analysis window
    analysis_window = tk.Toplevel(root)
    analysis_window.title("Pain Trigger Analysis")
    analysis_window.geometry("800x600")

    # Create notebook for tabs
    notebook = ttk.Notebook(analysis_window)
    notebook.pack(fill='both', expand=True, padx=10, pady=10)

    # Foods analysis tab
    foods_frame = ttk.Frame(notebook)
    notebook.add(foods_frame, text="Foods Analysis")

    # Remedies analysis tab
    remedies_frame = ttk.Frame(notebook)
    notebook.add(remedies_frame, text="Remedies Analysis")

    # Summary tab
    summary_frame = ttk.Frame(notebook)
    notebook.add(summary_frame, text="Summary")

    # Analyze foods
    if not data_to_analyze.empty:
        # Group by meal and calculate average pain level
        food_analysis = data_to_analyze.groupby('Meal').agg({
            'Pain Level': ['mean', 'count', 'max', 'min'],
            'Stress Level': 'mean'
        }).round(2)

        # Flatten column names
        food_analysis.columns = ['Avg_Pain', 'Count', 'Max_Pain', 'Min_Pain', 'Avg_Stress']
        food_analysis = food_analysis.reset_index()

        # Sort by average pain level (highest to lowest)
        food_analysis = food_analysis.sort_values('Avg_Pain', ascending=False)

        # Create foods text widget
        foods_text = tk.Text(foods_frame, wrap=tk.WORD, font=("Courier", 10))
        foods_scrollbar = ttk.Scrollbar(foods_frame, orient="vertical", command=foods_text.yview)
        foods_text.configure(yscrollcommand=foods_scrollbar.set)

        foods_text.pack(side="left", fill="both", expand=True)
        foods_scrollbar.pack(side="right", fill="y")

        # Display foods analysis
        foods_text.insert(tk.END, f"FOOD PAIN ANALYSIS ({current_filter})\n")
        foods_text.insert(tk.END, "=" * 80 + "\n\n")
        foods_text.insert(tk.END,
                          f"{'Food/Meal':<30} {'Avg Pain':<10} {'Count':<8} {'Max Pain':<10} {'Min Pain':<10} {'Avg Stress':<10}\n")
        foods_text.insert(tk.END, "-" * 80 + "\n")

        for _, row in food_analysis.iterrows():
            food_name = row['Meal'][:28] + "..." if len(row['Meal']) > 28 else row['Meal']
            foods_text.insert(tk.END,
                              f"{food_name:<30} {row['Avg_Pain']:<10.1f} {row['Count']:<8} {row['Max_Pain']:<10.1f} {row['Min_Pain']:<10.1f} {row['Avg_Stress']:<10.1f}\n")

        # Color code the text
        for i, row in food_analysis.iterrows():
            if row['Avg_Pain'] >= 7:
                foods_text.tag_add("high_pain", f"{i + 4}.0", f"{i + 4}.end")
            elif row['Avg_Pain'] >= 4:
                foods_text.tag_add("medium_pain", f"{i + 4}.0", f"{i + 4}.end")
            else:
                foods_text.tag_add("low_pain", f"{i + 4}.0", f"{i + 4}.end")

        foods_text.tag_config("high_pain", background="red", foreground="white")
        foods_text.tag_config("medium_pain", background="orange")
        foods_text.tag_config("low_pain", background="green", foreground="white")

        # Analyze remedies
        remedy_analysis = data_to_analyze.groupby('Remedy').agg({
            'Pain Level': ['mean', 'count', 'max', 'min'],
            'Stress Level': 'mean'
        }).round(2)

        # Flatten column names
        remedy_analysis.columns = ['Avg_Pain', 'Count', 'Max_Pain', 'Min_Pain', 'Avg_Stress']
        remedy_analysis = remedy_analysis.reset_index()

        # Sort by average pain level (lowest to highest for remedies - lower is better)
        remedy_analysis = remedy_analysis.sort_values('Avg_Pain', ascending=True)

        # Create remedies text widget
        remedies_text = tk.Text(remedies_frame, wrap=tk.WORD, font=("Courier", 10))
        remedies_scrollbar = ttk.Scrollbar(remedies_frame, orient="vertical", command=remedies_text.yview)
        remedies_text.configure(yscrollcommand=remedies_scrollbar.set)

        remedies_text.pack(side="left", fill="both", expand=True)
        remedies_scrollbar.pack(side="right", fill="y")

        # Display remedies analysis
        remedies_text.insert(tk.END, f"REMEDY EFFECTIVENESS ANALYSIS ({current_filter})\n")
        remedies_text.insert(tk.END, "=" * 80 + "\n\n")
        remedies_text.insert(tk.END,
                             f"{'Remedy':<30} {'Avg Pain':<10} {'Count':<8} {'Max Pain':<10} {'Min Pain':<10} {'Avg Stress':<10}\n")
        remedies_text.insert(tk.END, "-" * 80 + "\n")

        for _, row in remedy_analysis.iterrows():
            remedy_name = row['Remedy'][:28] + "..." if len(row['Remedy']) > 28 else row['Remedy']
            remedies_text.insert(tk.END,
                                 f"{remedy_name:<30} {row['Avg_Pain']:<10.1f} {row['Count']:<8} {row['Max_Pain']:<10.1f} {row['Min_Pain']:<10.1f} {row['Avg_Stress']:<10.1f}\n")

        # Color code remedies (lower pain is better)
        for i, row in remedy_analysis.iterrows():
            if row['Avg_Pain'] <= 3:
                remedies_text.tag_add("effective", f"{i + 4}.0", f"{i + 4}.end")
            elif row['Avg_Pain'] <= 6:
                remedies_text.tag_add("moderate", f"{i + 4}.0", f"{i + 4}.end")
            else:
                remedies_text.tag_add("ineffective", f"{i + 4}.0", f"{i + 4}.end")

        remedies_text.tag_config("effective", background="green", foreground="white")
        remedies_text.tag_config("moderate", background="yellow")
        remedies_text.tag_config("ineffective", background="red", foreground="white")

        # Create summary
        summary_text = tk.Text(summary_frame, wrap=tk.WORD, font=("Arial", 11))
        summary_scrollbar = ttk.Scrollbar(summary_frame, orient="vertical", command=summary_text.yview)
        summary_text.configure(yscrollcommand=summary_scrollbar.set)

        summary_text.pack(side="left", fill="both", expand=True)
        summary_scrollbar.pack(side="right", fill="y")

        # Generate recommendations
        worst_foods = food_analysis.head(5)
        best_remedies = remedy_analysis.head(5)

        summary_text.insert(tk.END, f"GASTROGUARD ANALYSIS SUMMARY ({current_filter})\n")
        summary_text.insert(tk.END, "=" * 60 + "\n\n")

        summary_text.insert(tk.END, "🚨 TOP 5 PAIN-TRIGGERING FOODS:\n")
        summary_text.insert(tk.END, "-" * 40 + "\n")
        for i, (_, row) in enumerate(worst_foods.iterrows(), 1):
            summary_text.insert(tk.END, f"{i}. {row['Meal']} (Avg Pain: {row['Avg_Pain']:.1f}/10)\n")

        summary_text.insert(tk.END, "\n✅ TOP 5 MOST EFFECTIVE REMEDIES:\n")
        summary_text.insert(tk.END, "-" * 40 + "\n")
        for i, (_, row) in enumerate(best_remedies.iterrows(), 1):
            summary_text.insert(tk.END, f"{i}. {row['Remedy']} (Avg Pain: {row['Avg_Pain']:.1f}/10)\n")

        summary_text.insert(tk.END, "\n📊 OVERALL STATISTICS:\n")
        summary_text.insert(tk.END, "-" * 40 + "\n")
        summary_text.insert(tk.END, f"Total Entries Analyzed: {len(data_to_analyze)}\n")
        summary_text.insert(tk.END, f"Average Pain Level: {data_to_analyze['Pain Level'].mean():.1f}/10\n")
        summary_text.insert(tk.END, f"Average Stress Level: {data_to_analyze['Stress Level'].mean():.1f}/10\n")
        summary_text.insert(tk.END, f"Unique Foods Tracked: {len(food_analysis)}\n")
        summary_text.insert(tk.END, f"Unique Remedies Used: {len(remedy_analysis)}\n")

        # Add recommendations
        summary_text.insert(tk.END, "\n💡 RECOMMENDATIONS:\n")
        summary_text.insert(tk.END, "-" * 40 + "\n")
        if not worst_foods.empty:
            summary_text.insert(tk.END, f"• AVOID: {worst_foods.iloc[0]['Meal']} (highest pain trigger)\n")
        if not best_remedies.empty:
            summary_text.insert(tk.END, f"• USE: {best_remedies.iloc[0]['Remedy']} (most effective remedy)\n")

        if data_to_analyze['Pain Level'].mean() > 6:
            summary_text.insert(tk.END, "• Consider consulting a healthcare provider\n")
        elif data_to_analyze['Pain Level'].mean() > 4:
            summary_text.insert(tk.END, "• Monitor your diet more closely\n")
        else:
            summary_text.insert(tk.END, "• Your current management strategy appears effective\n")

    # Add export button
    export_btn = tk.Button(analysis_window, text="Export Analysis",
                           command=lambda: export_analysis(food_analysis, remedy_analysis, current_filter),
                           bg='blue', fg='white')
    export_btn.pack(pady=10)


# Export analysis to CSV
def export_analysis(food_analysis, remedy_analysis, filter_name):
    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        # Export foods analysis
        food_filename = f"food_analysis_{filter_name.replace(' ', '_')}_{timestamp}.csv"
        food_analysis.to_csv(food_filename, index=False)

        # Export remedies analysis
        remedy_filename = f"remedy_analysis_{filter_name.replace(' ', '_')}_{timestamp}.csv"
        remedy_analysis.to_csv(remedy_filename, index=False)

        messagebox.showinfo("Export Successful",
                            f"Analysis exported to:\n{food_filename}\n{remedy_filename}")
    except Exception as e:
        messagebox.showerror("Export Error", f"Failed to export analysis: {str(e)}")


# Simulate gastritis symptoms
def simulate_gastritis():
    stress = stress_scale.get()
    last_meal_time = datetime.now()

    # Determine hours since last meal (crude, based on latest meal log)
    if log_data.empty:
        last_meal_hours = 5  # Default if no logs
    else:
        last_meal = log_data.iloc[-1]["Time"]
        last_meal = pd.to_datetime(last_meal)
        delta = datetime.now() - last_meal
        last_meal_hours = delta.total_seconds() / 3600

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

    # Plot
    plt.figure()
    plt.plot(T, S, 'r-', linewidth=2)
    plt.title("Simulated Gastritis Severity")
    plt.xlabel("Time (hours)")
    plt.ylabel("Symptom Severity (0–1)")
    plt.grid(True)
    plt.ylim([0, 1])
    plt.show()

    # Show messagebox result
    final = S[-1]
    if final < 0.3:
        message = "✅ Mild symptoms expected. Stay hydrated and rest."
    elif final < 0.6:
        message = "⚠️ Moderate symptoms. Avoid irritants like caffeine or stress."
    else:
        message = "🚨 High severity predicted. Consider medication or medical advice."

    messagebox.showinfo("Gastritis Simulation Result",
                        f"Final Severity: {final:.2f}\n\n{message}")


# GUI setup
root = tk.Tk()
root.title("GastroGuard - Gastritis Assistant with Time Filters & Timeline")
root.geometry("700x800")

# Create main frame
main_frame = ttk.Frame(root, padding="10")
main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

# Configure grid weights
root.columnconfigure(0, weight=1)
root.rowconfigure(0, weight=1)
main_frame.columnconfigure(1, weight=1)

# Title
title_label = tk.Label(main_frame, text="GastroGuard - Gastritis Assistant", font=("Arial", 16, "bold"))
title_label.grid(row=0, column=0, columnspan=3, pady=(0, 20))

# Filter section
filter_frame = ttk.LabelFrame(main_frame, text="Time Filters", padding="10")
filter_frame.grid(row=1, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 20))

# Filter buttons
filter_buttons = [
    ("All", 0, 0), ("Today", 0, 1), ("This Week", 0, 2),
    ("This Month", 1, 0), ("Last 7 Days", 1, 1), ("Last 30 Days", 1, 2),
    ("Custom Range", 2, 1)
]

for text, row, col in filter_buttons:
    if text == "Custom Range":
        btn = tk.Button(filter_frame, text=text, command=custom_date_filter, bg='lightblue')
    else:
        btn = tk.Button(filter_frame, text=text, command=lambda t=text: filter_data(t), bg='lightgreen')
    btn.grid(row=row, column=col, padx=5, pady=5, sticky=(tk.W, tk.E))

# Filter display
filter_label = tk.Label(filter_frame, text="Filter: All | Records: 0", font=("Arial", 10, "bold"))
filter_label.grid(row=3, column=0, columnspan=3, pady=(10, 0))

# Input section
input_frame = ttk.LabelFrame(main_frame, text="Log Entry", padding="10")
input_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 20))

# Input widgets
tk.Label(input_frame, text="Meal/Food Consumed:").grid(row=0, column=0, sticky=tk.W, pady=2)
meal_entry = tk.Entry(input_frame, width=40)
meal_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), pady=2)

# Time of ingestion field
tk.Label(input_frame, text="Time of Ingestion:").grid(row=1, column=0, sticky=tk.W, pady=2)
ingestion_time_frame = ttk.Frame(input_frame)
ingestion_time_frame.grid(row=1, column=1, sticky=(tk.W, tk.E), pady=2)

# Date picker for ingestion
ingestion_date = DateEntry(ingestion_time_frame, width=15, background='darkblue', foreground='white', borderwidth=2)
ingestion_date.pack(side=tk.LEFT, padx=(0, 5))

# Time picker for ingestion
hour_var = tk.StringVar(value=datetime.now().strftime("%H"))
minute_var = tk.StringVar(value=datetime.now().strftime("%M"))

tk.Label(ingestion_time_frame, text="Hour:").pack(side=tk.LEFT)
hour_spin = tk.Spinbox(ingestion_time_frame, from_=0, to=23, width=3, textvariable=hour_var)
hour_spin.pack(side=tk.LEFT, padx=2)

tk.Label(ingestion_time_frame, text="Min:").pack(side=tk.LEFT)
minute_spin = tk.Spinbox(ingestion_time_frame, from_=0, to=59, width=3, textvariable=minute_var)
minute_spin.pack(side=tk.LEFT, padx=2)

# Function to get ingestion time string
def get_ingestion_time():
    selected_date = ingestion_date.get_date()
    hour = int(hour_var.get())
    minute = int(minute_var.get())
    ingestion_datetime = datetime.combine(selected_date, datetime.min.time().replace(hour=hour, minute=minute))
    return ingestion_datetime.strftime("%Y-%m-%d %H:%M:%S")

# Create a hidden entry to store the ingestion time
ingestion_time_entry = tk.Entry(input_frame)
ingestion_time_entry.insert(0, get_ingestion_time())
ingestion_time_entry.grid_remove()  # Hide the entry

# Update ingestion time when date/time changes
def update_ingestion_time(*args):
    ingestion_time_entry.delete(0, tk.END)
    ingestion_time_entry.insert(0, get_ingestion_time())

hour_var.trace('w', update_ingestion_time)
minute_var.trace('w', update_ingestion_time)

tk.Label(input_frame, text="Pain Level (0-10):").grid(row=2, column=0, sticky=tk.W, pady=2)
pain_scale = tk.Scale(input_frame, from_=0, to=10, orient="horizontal")
pain_scale.grid(row=2, column=1, sticky=(tk.W, tk.E), pady=2)

tk.Label(input_frame, text="Stress Level (0-10):").grid(row=3, column=0, sticky=tk.W, pady=2)
stress_scale = tk.Scale(input_frame, from_=0, to=10, orient="horizontal")
stress_scale.grid(row=3, column=1, sticky=(tk.W, tk.E), pady=2)

tk.Label(input_frame, text="Remedy Used:").grid(row=4, column=0, sticky=tk.W, pady=2)
remedy_entry = tk.Entry(input_frame, width=40)
remedy_entry.grid(row=4, column=1, sticky=(tk.W, tk.E), pady=2)

# Configure input frame grid weights
input_frame.columnconfigure(1, weight=1)

# Buttons section
button_frame = ttk.Frame(main_frame)
button_frame.grid(row=3, column=0, columnspan=3, pady=(0, 20))

# Buttons
tk.Button(button_frame, text="Log Entry", command=submit_data, bg='green', fg='white').grid(row=0, column=0, padx=5,
                                                                                            pady=5)
tk.Button(button_frame, text="Retroactive Log", command=retroactive_log, bg='orange', fg='white').grid(row=0, column=1, padx=5,
                                                                                                       pady=5)
tk.Button(button_frame, text="Show Graph", command=show_graph, bg='blue', fg='white').grid(row=0, column=2, padx=5,
                                                                                           pady=5)
tk.Button(button_frame, text="Timeline", command=show_timeline, bg='cyan', fg='black').grid(row=0, column=3, padx=5,
                                                                                            pady=5)
tk.Button(button_frame, text="Statistics", command=show_statistics, bg='purple', fg='white').grid(row=1, column=0, padx=5,
                                                                                                  pady=5)
tk.Button(button_frame, text="Export Data", command=export_data, bg='orange').grid(row=1, column=1, padx=5, pady=5)
tk.Button(button_frame, text="Pain Analysis", command=analyze_pain_triggers, bg='darkred', fg='white').grid(row=2,
                                                                                                            column=0,
                                                                                                            columnspan=2,
                                                                                                            pady=10)
tk.Button(button_frame, text="Simulate Gastritis", command=simulate_gastritis, bg='red', fg='white').grid(row=2,
                                                                                                          column=2,
                                                                                                          columnspan=2,
                                                                                                          pady=10)

# Status section
status_frame = ttk.Frame(main_frame)
status_frame.grid(row=4, column=0, columnspan=3, sticky=(tk.W, tk.E))

status_label = tk.Label(status_frame, text="Ready to log data", fg="green")
status_label.grid(row=0, column=0, sticky=tk.W)

# Initialize filter
filter_data("All")

# Run
root.mainloop()


# ============================================================================
# STREAMLIT DASHBOARD FUNCTIONS
# ============================================================================

def run_streamlit_dashboard():
    """Run the Streamlit web dashboard version"""
    if not STREAMLIT_AVAILABLE:
        print("Streamlit not available. Please install with: pip install streamlit plotly")
        return

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
            font-size: 2.5rem;
            font-weight: bold;
            color: #1f77b4;
            text-align: center;
            margin-bottom: 2rem;
        }
        .metric-card {
            background-color: #f0f2f6;
            padding: 1rem;
            border-radius: 0.5rem;
            border-left: 4px solid #1f77b4;
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
    </style>
    """, unsafe_allow_html=True)

    # Initialize session state for data persistence
    if 'log_data' not in st.session_state:
        st.session_state.log_data = log_data.copy()

    if 'filtered_data' not in st.session_state:
        st.session_state.filtered_data = filtered_data

    if 'current_filter' not in st.session_state:
        st.session_state.current_filter = current_filter

    # Streamlit helper functions
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

        # Update global data
        global log_data
        log_data = st.session_state.log_data.copy()

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

    def simulate_gastritis_streamlit(stress, last_meal_hours):
        """Simulate gastritis symptoms for Streamlit"""
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

    # Main Streamlit app
    def main_streamlit():
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
                    st.write("• **Your current management strategy appears effective**")

        # Simulation page
        elif page == "🧪 Simulation":
            st.header("🧪 Gastritis Simulation")

            st.write(
                "This simulation predicts gastritis symptoms based on your current stress level and time since last meal.")

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
                T, S = simulate_gastritis_streamlit(stress, last_meal_hours)

                # Plot
                fig = go.Figure()
                fig.add_trace(go.Scatter(x=T, y=S, mode='lines', name='Symptom Severity',
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

    # Run the Streamlit app
    main_streamlit()


# Function to choose between Tkinter and Streamlit
def choose_dashboard():
    """Choose between Tkinter and Streamlit dashboard"""
    print("GastroGuard Dashboard Options:")
    print("1. Tkinter Desktop App (Default)")
    print("2. Streamlit Web Dashboard")

    choice = input("Enter your choice (1 or 2): ").strip()

    if choice == "2":
        if STREAMLIT_AVAILABLE:
            print("Starting Streamlit dashboard...")
            print("The app will open in your browser at http://localhost:8501")
            run_streamlit_dashboard()
        else:
            print("Streamlit not available. Installing required packages...")
            print("Please run: pip install streamlit plotly")
            print("Then run this script again and choose option 2.")
    else:
        print("Starting Tkinter dashboard...")
        # The Tkinter app will run by default when this script is executed

# Uncomment the line below to enable dashboard choice
# choose_dashboard()
