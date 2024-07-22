import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from tabulate import tabulate

log_locations = [
    "src/models/MLP_CNN/logs",
    "src/models/MLP_FNO/logs",
    "src/models/wavKAN_CNN/logs",
]

plot_names = [
    "MLP CNN",
    "MLP FNO",
    "KAN CNN",
]

model_file = [
    "src/models/MLP_CNN/logs/trained_models/model_1.bson",
    "src/models/MLP_FNO/logs/trained_models/model_1.bson",
    "src/models/wavKAN_CNN/logs/trained_models/model_1.bson",
]

# This array for params counts has been generated by sum(length, Flux.params(model)) for each model
param_counts = [5982121, 4667665, 35919]

num_repetitions = 5 

# Create an empty DataFrame to hold all results
results = pd.DataFrame(columns=["Model", "train_loss", "test_loss", "BIC", "time", "param_count"])

box_plot_train = pd.DataFrame(columns=["model", "value"])
box_plot_test = pd.DataFrame(columns=["model", "value"])
box_plot_BIC = pd.DataFrame(columns=["model", "value"])
box_plot_time = pd.DataFrame(columns=["model", "value"])

for idx, log_location in enumerate(log_locations):
    train_loss, test_loss, BIC, time = [], [], [], []
    for i in range(1, num_repetitions + 1):
        df = pd.read_csv(f"{log_location}/repetition_{i}.csv")
        if pd.isna(df["Test Loss"].iloc[-1]):
            continue
        train_loss.append(df["Train Loss"].iloc[-1])
        test_loss.append(df["Test Loss"].iloc[-1])
        BIC.append(df["BIC"].iloc[-1])
        time.append(df["Time (s)"].iloc[-1] / 60)

        box_plot_train = pd.concat([box_plot_train, pd.DataFrame({"model": [plot_names[idx]], "value": [df["Train Loss"].iloc[-1]]})])
        box_plot_test = pd.concat([box_plot_test, pd.DataFrame({"model": [plot_names[idx]], "value": [df["Test Loss"].iloc[-1]]})])
        box_plot_BIC = pd.concat([box_plot_BIC, pd.DataFrame({"model": [plot_names[idx]], "value": [df["BIC"].iloc[-1]]})])
        box_plot_time = pd.concat([box_plot_time, pd.DataFrame({"model": [plot_names[idx]], "value": [df["Time (s)"].iloc[-1] / 60]})])

    results = pd.concat([results, pd.DataFrame({
        "Model": [plot_names[idx]],
        "train_loss": [f"{np.mean(train_loss):.2f} ± {np.std(train_loss):.2f}"],
        "test_loss": [f"{np.mean(test_loss):.2f} ± {np.std(test_loss):.2f}"],
        "BIC": [f"{np.mean(BIC):.2f} ± {np.std(BIC):.2f}"],
        "time": [f"{np.mean(time):.2f} ± {np.std(time):.2f}"],
        "param_count": [param_counts[idx]]
    })])

# Create a table
header = ["Model", "Train Loss", "Test Loss", "BIC", "Time (mins)", "Param Count"]
table = tabulate(results.values, headers=header, tablefmt="grid")
print(table)

# Save the table as a text file
with open("figures/loss_table.txt", "w") as f:
    f.write(table)

def box_data(df, name):
    plt.figure(figsize=(10, 6))
    sns.boxplot(x="model", y="value", data=df)
    plt.title(name)
    plt.xlabel("Model")
    plt.ylabel(name)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(f"figures/{name}.png")
    plt.close()

box_data(box_plot_train, "Train Loss")
box_data(box_plot_test, "Test Loss")
box_data(box_plot_BIC, "BIC")
box_data(box_plot_time, "Time (mins)")