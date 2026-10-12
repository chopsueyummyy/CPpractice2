import os
import joblib
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.metrics import accuracy_score, top_k_accuracy_score, classification_report, confusion_matrix, f1_score

# -----------------------------------------------------------------------------
# Setup Paths & Output Directory
# -----------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "backend", "current_model", "current_coursealign_model.joblib")
LABEL_ENC_PATH = os.path.join(BASE_DIR, "backend", "current_model", "current_label_encoder.joblib")
DATA_PATH = os.path.join(BASE_DIR, "couldbethefinalmodel", "Final1_D.csv")

OUTPUT_DIR = os.path.join(BASE_DIR, "tool_reports")
os.makedirs(OUTPUT_DIR, exist_ok=True)

print("Loading dataset and model...")
df = pd.read_csv(DATA_PATH)
model = joblib.load(MODEL_PATH)
label_encoder = joblib.load(LABEL_ENC_PATH)

features = ['Realistic_Score', 'Investigative_Score', 'Artistic_Score', 'Social_Score', 'Enterprising_Score', 'Conventional_Score']
target = 'Course Cluster'

X = df[features]
y = label_encoder.transform(df[target])
class_names = label_encoder.classes_

# Replicate exact stratified train/test split (80/20, random_state=42)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# Predictions on holdout test set
y_pred = model.predict(X_test)
y_prob = model.predict_proba(X_test)

# Calculate core metrics
top1_acc = accuracy_score(y_test, y_pred) * 100
top3_acc = top_k_accuracy_score(y_test, y_prob, k=3) * 100
weighted_f1 = f1_score(y_test, y_pred, average='weighted')
macro_f1 = f1_score(y_test, y_pred, average='macro')

# 5-Fold Cross Validation Top-1 Accuracy
skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
cv_scores = cross_val_score(model, X, y, cv=skf, scoring='accuracy') * 100
cv_mean = cv_scores.mean()
cv_std = cv_scores.std()

# Short labels for clusters to keep charts readable
short_names = [
    "Agri & Environment",
    "Business & Finance",
    "Media & Arts",
    "Education & Psych",
    "Engineering & Tech",
    "Health Sciences",
    "Law & Public Service",
    "Science & Research"
]

# Set Seaborn styling
sns.set_theme(style="whitegrid", font="sans-serif")

# =============================================================================
# CHART 1: Core Performance Overview Bar Chart
# =============================================================================
fig, ax = plt.subplots(figsize=(10, 6), dpi=300)

metrics = [
    "Top-3 Recommendation\nAccuracy",
    "5-Fold Cross-Validation\nTop-1 Accuracy",
    "Holdout Top-1\nAccuracy",
    "Weighted F1-Score\n(Scaled %)",
    "Macro F1-Score\n(Scaled %)"
]
values = [top3_acc, cv_mean, top1_acc, weighted_f1 * 100, macro_f1 * 100]
colors = ["#2E7D32", "#1976D2", "#0288D1", "#7B1FA2", "#F57C00"]

bars = ax.bar(metrics, values, color=colors, width=0.55, edgecolor="#333333", linewidth=1.2)

# Value annotations on top of bars
for bar, val in zip(bars, values):
    height = bar.get_height()
    if bar == bars[1]:  # CV score with std deviation
        label_text = f"{val:.2f}% (±{cv_std:.2f}%)"
    else:
        label_text = f"{val:.2f}%"
    ax.annotate(
        label_text,
        xy=(bar.get_x() + bar.get_width() / 2, height),
        xytext=(0, 5),
        textcoords="offset points",
        ha='center', va='bottom',
        fontsize=11, fontweight='bold', color="#111111"
    )

ax.set_ylim(0, 115)
ax.set_ylabel("Score / Percentage (%)", fontsize=12, fontweight='bold')
ax.set_title("CourseAlign Recommendation Model - Performance Evaluation Metrics\n(Active Model: XGBoost Holland RIASEC)", fontsize=14, fontweight='bold', pad=15)
ax.axhline(90, color='gray', linestyle='--', linewidth=0.8, alpha=0.7)
ax.text(4.4, 91, '90% Benchmark', color='gray', fontsize=9, style='italic', ha='right')

plt.tight_layout()
chart1_path = os.path.join(OUTPUT_DIR, "model_performance_overview.png")
plt.savefig(chart1_path)
plt.close()
print(f"Saved: {chart1_path}")

# =============================================================================
# CHART 2: Confusion Matrix Heatmap
# =============================================================================
cm = confusion_matrix(y_test, y_pred)

fig, ax = plt.subplots(figsize=(11, 8.5), dpi=300)
sns.heatmap(
    cm,
    annot=True,
    fmt='d',
    cmap='Blues',
    xticklabels=short_names,
    yticklabels=short_names,
    cbar=True,
    linewidths=0.8,
    linecolor='#E0E0E0',
    ax=ax
)

ax.set_title("CourseAlign Evaluation - Confusion Matrix (Holdout Test Set N=50)", fontsize=14, fontweight='bold', pad=15)
ax.set_xlabel("Predicted Course Cluster", fontsize=12, fontweight='bold', labelpad=10)
ax.set_ylabel("Actual (Ground Truth) Cluster", fontsize=12, fontweight='bold', labelpad=10)
plt.xticks(rotation=30, ha='right', fontsize=10)
plt.yticks(rotation=0, fontsize=10)

plt.tight_layout()
chart2_path = os.path.join(OUTPUT_DIR, "confusion_matrix_heatmap.png")
plt.savefig(chart2_path)
plt.close()
print(f"Saved: {chart2_path}")

# =============================================================================
# CHART 3: Per-Cluster Precision, Recall, and F1 Breakdown
# =============================================================================
report = classification_report(y_test, y_pred, target_names=short_names, output_dict=True)
report_df = pd.DataFrame(report).transpose()
cluster_df = report_df.loc[short_names, ['precision', 'recall', 'f1-score']] * 100

fig, ax = plt.subplots(figsize=(12, 7), dpi=300)
cluster_df.plot(
    kind='barh',
    ax=ax,
    color=['#42A5F5', '#66BB6A', '#FFA726'],
    width=0.75,
    edgecolor='#333333',
    linewidth=0.8
)

ax.set_title("Performance Breakdown Across 8 Course Clusters (Precision, Recall, F1)", fontsize=14, fontweight='bold', pad=15)
ax.set_xlabel("Percentage (%)", fontsize=12, fontweight='bold')
ax.set_ylabel("Course Cluster", fontsize=12, fontweight='bold')
ax.set_xlim(0, 115)
ax.legend(["Precision", "Recall", "F1-Score"], loc='lower right', frameon=True, fontsize=10)
ax.grid(axis='x', linestyle='--', alpha=0.7)

plt.tight_layout()
chart3_path = os.path.join(OUTPUT_DIR, "per_cluster_performance.png")
plt.savefig(chart3_path)
plt.close()
print(f"Saved: {chart3_path}")

print("All charts generated successfully in:", OUTPUT_DIR)
