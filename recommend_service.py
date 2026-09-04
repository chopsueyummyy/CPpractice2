import os
import json
import joblib
import pandas as pd
import numpy as np
import shap
from http.server import HTTPServer, BaseHTTPRequestHandler

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
model_path = os.path.join(BASE_DIR, 'coursealign_model.joblib')
le_path = os.path.join(BASE_DIR, 'label_encoder.joblib')
se_path = os.path.join(BASE_DIR, 'strand_encoder.joblib')

# Load models once during server startup
print("Loading model and encoders...")
model = joblib.load(model_path)
le = joblib.load(le_path)
se = joblib.load(se_path)
explainer = shap.TreeExplainer(model)
print("Models loaded successfully!")

FEATURE_EXPLANATIONS = {
    'R': "Your high interest in practical, hands-on activities (Realistic) strongly matches the requirements of this course.",
    'I': "Your strong analytical, problem-solving, and scientific thinking (Investigative) aligns perfectly with this field.",
    'A': "Your preference for creative expression, design, and innovation (Artistic) matches the core aspects of this course.",
    'S': "Your natural inclination toward communication, helping others, and social interaction (Social) makes this a great fit.",
    'E': "Your potential for leadership, entrepreneurship, and persuasive communication (Enterprising) is highly valuable here.",
    'C': "Your detail-oriented, organized, and structured approach to tasks (Conventional) is highly suited for this program.",
    'RSES': "Your positive self-esteem and confidence in your academic capabilities support your readiness to excel in this field.",
    'CDSES': "Your career decision self-efficacy indicates high confidence in successfully navigating major and career selection.",
    'Strand': "Your senior high school academic strand provides a highly compatible foundation for this program."
}

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

def normalize_strand(strand_str, valid_strands):
    if strand_str in valid_strands:
        return strand_str
    if 'STEM' in strand_str or 'TECH' in strand_str or 'ICT' in strand_str:
        return 'STEM'
    if 'ABM' in strand_str or 'GAS' in strand_str or 'BPP' in strand_str:
        return 'ABM'
    return 'HUMSS'

def generate_recommendations(top3_idx, probs, shap_values, feature_names):
    recommendations = []
    for rank, idx in enumerate(top3_idx, 1):
        class_name = le.inverse_transform([idx])[0]
        probability = float(probs[idx])
        course_code = CLASS_TO_COURSE_CODE.get(class_name, 'BSCS')

        class_shap = shap_values.values[0][:, idx]
        sorted_feat_idx = np.argsort(class_shap)[::-1]
        top_features = [feature_names[f_idx] for f_idx in sorted_feat_idx if class_shap[f_idx] > 0][:3]

        explanations = [FEATURE_EXPLANATIONS[feat] for feat in top_features]
        explanation_text = " ".join(explanations)
        if not explanation_text:
            explanation_text = "This course aligns with your general academic strand and interest profile."

        shap_weights = {feature_names[i]: float(class_shap[i]) for i in range(len(feature_names))}

        recommendations.append({
            "rank": rank,
            "course_code": course_code,
            "probability": probability,
            "explanation": explanation_text,
            "shap_weights": shap_weights
        })
    return recommendations

class RecommendationHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/recommend':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                input_data = json.loads(post_data.decode('utf-8'))
                
                # Format inputs
                r = float(input_data.get('R', 0))
                i_feat = float(input_data.get('I', 0))
                a = float(input_data.get('A', 0))
                s = float(input_data.get('S', 0))
                e = float(input_data.get('E', 0))
                c = float(input_data.get('C', 0))
                rses = float(input_data.get('RSES', 0))
                cdses = float(input_data.get('CDSES', 0))
                raw_strand = str(input_data.get('Strand', 'STEM')).strip().upper()

                strand_str = normalize_strand(raw_strand, list(se.classes_))
                strand_encoded = int(se.transform([strand_str])[0])

                # Create input dataframe
                feature_names = ['R', 'I', 'A', 'S', 'E', 'C', 'RSES', 'CDSES', 'Strand']
                input_df = pd.DataFrame([[r, i_feat, a, s, e, c, rses, cdses, strand_encoded]], columns=feature_names)

                # Predict
                probs = model.predict_proba(input_df)[0]
                top3_idx = np.argsort(probs)[::-1][:3]
                
                # Compute SHAP
                shap_values = explainer(input_df)
                recommendations = generate_recommendations(top3_idx, probs, shap_values, feature_names)

                response_body = json.dumps({
                    "status": "success",
                    "recommendations": recommendations
                })
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(response_body.encode('utf-8'))
            except Exception as e:
                response_body = json.dumps({
                    "status": "error",
                    "message": str(e)
                })
                self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(response_body.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def run(server_class=HTTPServer, handler_class=RecommendationHandler, port=8001):
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"Starting recommendation microservice on port {port}...")
    httpd.serve_forever()

if __name__ == '__main__':
    run()
