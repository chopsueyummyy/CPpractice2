import os
import sys
import json
import warnings
warnings.filterwarnings('ignore')
os.environ['PYTHONWARNINGS'] = 'ignore'

import numpy as np
import pandas as pd
import joblib
import shap

# Feature Name Humanizer Dictionary
FEATURE_MAP = {
    'strand_ohe__SHS_Strand_ABM': 'ABM Strand Background',
    'strand_ohe__SHS_Strand_HUMSS': 'HUMSS Strand Background',
    'strand_ohe__SHS_Strand_STEM': 'STEM Strand Background',
    'strand_ohe__SHS_Strand_TVL': 'TVL Strand Background',
    'strand_ohe__SHS_Strand_GAS': 'GAS Strand Background',
    'remainder__Realistic_Score': 'Realistic Practical Interest',
    'remainder__Investigative_Score': 'Investigative Analytical Interest',
    'remainder__Artistic_Score': 'Artistic Creative Interest',
    'remainder__Social_Score': 'Social Helping Interest',
    'remainder__Enterprising_Score': 'Enterprising Leadership Interest',
    'remainder__Conventional_Score': 'Conventional Detail Interest',
    'remainder__RSE_Score_Likert': 'Self-Esteem Level',
    'remainder__CDSES_Total_Score': 'Career Decision Self-Efficacy'
}

def main():
    try:
        # Determine model directory base path
        base_dir = os.path.dirname(os.path.abspath(__file__))
        possible_dirs = [
            os.path.join(base_dir, 'current_model'),
            os.path.join(base_dir, 'current model'),
            os.path.join(base_dir, '..', 'current model'),
            os.path.join(base_dir, '..', 'current_model')
        ]
        model_dir = None
        for d in possible_dirs:
            if os.path.exists(os.path.join(d, 'current_coursealign_model.joblib')):
                model_dir = d
                break

        if not model_dir:
            print(json.dumps({"status": "error", "message": f"Model directory not found in candidate paths: {possible_dirs}"}))
            sys.exit(1)

        model_path = os.path.join(model_dir, 'current_coursealign_model.joblib')
        label_enc_path = os.path.join(model_dir, 'current_label_encoder.joblib')
        strand_enc_path = os.path.join(model_dir, 'current_strand_encoder.joblib')
        catalog_path = os.path.join(base_dir, 'course_catalog.json')

        # Load models and encoders
        model = joblib.load(model_path)
        label_encoder = joblib.load(label_enc_path)
        strand_encoder = joblib.load(strand_enc_path)

        catalog = {}
        if os.path.exists(catalog_path):
            with open(catalog_path, 'r', encoding='utf-8') as f:
                catalog = json.load(f)

        # Read input data from stdin or argument
        if len(sys.argv) > 1:
            raw_input = sys.argv[1]
        else:
            raw_input = sys.stdin.read()

        data = json.loads(raw_input)

        # Build DataFrame with expected 9 feature columns
        df_input = pd.DataFrame([{
            'SHS_Strand': str(data.get('SHS_Strand', 'STEM')).upper(),
            'Realistic_Score': float(data.get('Realistic_Score', 0)),
            'Investigative_Score': float(data.get('Investigative_Score', 0)),
            'Artistic_Score': float(data.get('Artistic_Score', 0)),
            'Social_Score': float(data.get('Social_Score', 0)),
            'Enterprising_Score': float(data.get('Enterprising_Score', 0)),
            'Conventional_Score': float(data.get('Conventional_Score', 0)),
            'RSE_Score_Likert': float(data.get('RSE_Score_Likert', 25)),
            'CDSES_Total_Score': float(data.get('CDSES_Total_Score', 75))
        }])

        # Transform using strand encoder
        X_trans = strand_encoder.transform(df_input)
        feature_names = strand_encoder.get_feature_names_out()

        # Predict Probabilities
        probs = model.predict_proba(X_trans)[0]
        top3_indices = np.argsort(probs)[::-1][:3]

        # Calculate SHAP values
        explainer = shap.TreeExplainer(model)
        shap_values = explainer.shap_values(X_trans)

        recommendations = []
        for rank, class_idx in enumerate(top3_indices, 1):
            cluster_name = label_encoder.inverse_transform([class_idx])[0]
            probability = float(probs[class_idx] * 100)

            # Extract SHAP explanations for this cluster
            # shap_values shape: (1, num_features, num_classes) or list per class
            if isinstance(shap_values, list):
                cluster_shap = shap_values[class_idx][0]
            elif len(shap_values.shape) == 3:
                cluster_shap = shap_values[0, :, class_idx]
            else:
                cluster_shap = shap_values[0]

            # Pair features with SHAP scores
            feat_impacts = []
            for fname, val in zip(feature_names, cluster_shap):
                human_name = FEATURE_MAP.get(fname, fname)
                feat_impacts.append({
                    "feature": human_name,
                    "raw_feature": fname,
                    "impact_score": float(val)
                })

            # Sort by highest positive contribution first
            feat_impacts = sorted(feat_impacts, key=lambda x: x['impact_score'], reverse=True)
            top_explanations = [f for f in feat_impacts if f['impact_score'] > 0][:3]

            if not top_explanations:
                top_explanations = feat_impacts[:3]

            # Get sub-courses from catalog
            sub_courses = catalog.get(cluster_name, [])
            top_sub_courses = sub_courses[:4]  # Top 4 explore courses

            recommendations.append({
                "rank": rank,
                "cluster_name": cluster_name,
                "match_percentage": round(probability, 1),
                "shap_explanations": top_explanations,
                "explore_courses": top_sub_courses
            })

        output = {
            "status": "success",
            "student_strand": df_input['SHS_Strand'].iloc[0],
            "recommendations": recommendations
        }

        print(json.dumps(output))

    except Exception as e:
        print(json.dumps({
            "status": "error",
            "message": str(e)
        }))
        sys.exit(1)

if __name__ == '__main__':
    main()
