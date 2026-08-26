import os
import sys
import json
import joblib
import pandas as pd
import numpy as np
import shap

# Get current script directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Feature Explanations Mapping
FEATURE_EXPLANATIONS = {
    'R': "Your high interest in practical, hands-on activities (Realistic) strongly matches the requirements of this course.",
    'I': "Your strong analytical, problem-solving, and scientific thinking (Investigative) aligns perfectly with this field.",
    'A': "Your preference for creative expression, design, and innovation (Artistic) matches the core aspects of this course.",
    'S': "Your natural inclination toward communication, helping others, and social interaction (Social) makes this a great fit.",
    'E': "Your potential for leadership, entrepreneurship, and persuasive communication (Enterprising) is highly valuable here.",
    'C': "Your detail-oriented, organized, and structured approach to tasks (Conventional) is highly suited for this program.",
    'RSES': "Your positive self-esteem and confidence in your academic capabilities support your readiness to excel in this field.",
    'CDSES': "Your career decision self-efficacy indicates high confidence in successfully navigating major and career selection.",
    'Strand': "Your senior high school academic strand provides a highly compatible foundation for this college program."
}

def main():
    try:
        # Load models and encoders
        model_path = os.path.join(BASE_DIR, 'coursealign_model.joblib')
        le_path = os.path.join(BASE_DIR, 'label_encoder.joblib')
        se_path = os.path.join(BASE_DIR, 'strand_encoder.joblib')

        model = joblib.load(model_path)
        le = joblib.load(le_path)
        se = joblib.load(se_path)

        # Parse command line input
        if len(sys.argv) < 2:
            print(json.dumps({"status": "error", "message": "No input payload provided."}))
            return

        input_data = json.loads(sys.argv[1])
        
        # Format input values
        r = float(input_data.get('R', 0))
        i_feat = float(input_data.get('I', 0))
        a = float(input_data.get('A', 0))
        s = float(input_data.get('S', 0))
        e = float(input_data.get('E', 0))
        c = float(input_data.get('C', 0))
        rses = float(input_data.get('RSES', 0))
        cdses = float(input_data.get('CDSES', 0))
        strand_str = str(input_data.get('Strand', 'STEM')).strip().upper()

        # Handle Strand mapping and encoding
        # LabelEncoder of strand has: ['ABM', 'HUMSS', 'STEM']
        valid_strands = list(se.classes_)
        if strand_str not in valid_strands:
            # Fallback mapping
            if 'STEM' in strand_str or 'TECH' in strand_str or 'ICT' in strand_str:
                strand_str = 'STEM'
            elif 'ABM' in strand_str or 'GAS' in strand_str or 'BPP' in strand_str:
                strand_str = 'ABM'
            else:
                strand_str = 'HUMSS'
                
        strand_encoded = int(se.transform([strand_str])[0])

        # Create input dataframe
        feature_names = ['R', 'I', 'A', 'S', 'E', 'C', 'RSES', 'CDSES', 'Strand']
        input_df = pd.DataFrame([[r, i_feat, a, s, e, c, rses, cdses, strand_encoded]], columns=feature_names)

        # Predict probabilities
        probs = model.predict_proba(input_df)[0]
        
        # Get top 3 indices
        top3_idx = np.argsort(probs)[::-1][:3]

        # Calculate SHAP values
        explainer = shap.TreeExplainer(model)
        shap_values = explainer(input_df)

        recommendations = []
        for rank, idx in enumerate(top3_idx, 1):
            class_name = le.inverse_transform([idx])[0]
            probability = float(probs[idx])
            
            # Map labels to DB course codes
            CLASS_TO_COURSE_CODE = {
                'BA Communication': 'BAComm',
                'BS Accountancy': 'BSA-Acc',
                'BS Agriculture': 'BSA',
                'BS Architecture': 'BSArch',
                'BS Biology': 'BSBio',
                'BS Business Administration': 'BSBA',
                'BS Civil Engineering': 'BSCE',
                'BS Computer Science': 'BSCS',
                'BS Criminology': 'BSCrim',
                'BS Education': 'BSEd',
                'BS Hospitality Management': 'BSHM',
                'BS Industrial Technology': 'BSIT-Tech',
                'BS Information Systems': 'BSIS',
                'BS Information Technology': 'BSIT',
                'BS Marketing Management': 'BSMktg',
                'BS Mechanical Engineering': 'BSME',
                'BS Nursing': 'BSN',
                'BS Psychology': 'BSPsych',
                'BS Tourism Management': 'BSTM',
                'Bachelor of Fine Arts': 'BFA'
            }
            course_code = CLASS_TO_COURSE_CODE.get(class_name, 'BSCS')

            # Extract SHAP explanations for this class
            class_shap = shap_values.values[0][:, idx]
            
            # Find positive contributors sorted
            sorted_feat_idx = np.argsort(class_shap)[::-1]
            top_features = [feature_names[f_idx] for f_idx in sorted_feat_idx if class_shap[f_idx] > 0][:3]
            
            explanations = [FEATURE_EXPLANATIONS[feat] for feat in top_features]
            explanation_text = " ".join(explanations)
            if not explanation_text:
                explanation_text = f"This course aligns with your general academic strand and interest profile."

            recommendations.append({
                "rank": rank,
                "course_code": course_code,
                "probability": probability,
                "explanation": explanation_text
            })

        print(json.dumps({
            "status": "success",
            "recommendations": recommendations
        }))

    except Exception as e:
        print(json.dumps({
            "status": "error",
            "message": str(e)
        }))

if __name__ == '__main__':
    main()
