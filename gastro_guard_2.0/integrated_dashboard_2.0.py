import tkinter as tk
from tkinter import ttk, messagebox
from datetime import datetime
import pandas as pd
import matplotlib.pyplot as plt
from scipy.integrate import solve_ivp
import numpy as np

# DataFrame to store logs
log_data = pd.DataFrame(columns=["Time", "Meal", "Pain Level", "Stress Level", "Remedy"])


# Submit log entry
def submit_data():
    global log_data
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    meal = meal_entry.get()
    pain = pain_scale.get()
    stress = stress_scale.get()
    remedy = remedy_entry.get()

    new_entry = {
        "Time": current_time,
        "Meal": meal,
        "Pain Level": pain,
        "Stress Level": stress,
        "Remedy": remedy
    }
    log_data = log_data.append(new_entry, ignore_index=True)
    status_label.config(text="Data logged successfully!")


# Show pain and stress trend graph
def show_graph():
    if log_data.empty:
        status_label.config(text="No data to plot.")
        return
    log_data["Time"] = pd.to_datetime(log_data["Time"])
    log_data.plot(x="Time", y=["Pain Level", "Stress Level"], kind="line", marker='o')
    plt.title("Pain & Stress Levels Over Time")
    plt.ylabel("Level")
    plt.xlabel("Time")
    plt.grid(True)
    plt.tight_layout()
    plt.show()


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
root.title("GastroGuard - Gastritis Assistant")

# Input widgets
tk.Label(root, text="Meal/Food Consumed:").grid(row=0, column=0)
meal_entry = tk.Entry(root, width=40)
meal_entry.grid(row=0, column=1)

tk.Label(root, text="Pain Level (0-10):").grid(row=1, column=0)
pain_scale = tk.Scale(root, from_=0, to=10, orient="horizontal")
pain_scale.grid(row=1, column=1)

tk.Label(root, text="Stress Level (0-10):").grid(row=2, column=0)
stress_scale = tk.Scale(root, from_=0, to=10, orient="horizontal")
stress_scale.grid(row=2, column=1)

tk.Label(root, text="Remedy Used:").grid(row=3, column=0)
remedy_entry = tk.Entry(root, width=40)
remedy_entry.grid(row=3, column=1)

# Buttons
tk.Button(root, text="Log Entry", command=submit_data).grid(row=4, column=0, columnspan=2, pady=10)
tk.Button(root, text="Show Graph", command=show_graph).grid(row=5, column=0, columnspan=2)
tk.Button(root, text="Simulate Gastritis", command=simulate_gastritis, bg='orange').grid(row=6, column=0, columnspan=2,
                                                                                         pady=10)

status_label = tk.Label(root, text="", fg="green")
status_label.grid(row=7, column=0, columnspan=2)

# Run
root.mainloop()
