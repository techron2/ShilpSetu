import os
import sys
import random
import numpy as np
import pandas as pd

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.ensemble import RandomForestRegressor
from sklearn.pipeline import Pipeline
from sklearn.metrics import r2_score, mean_absolute_error
import joblib

# Set random seeds for reproducibility
random.seed(42)
np.random.seed(42)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(DATA_DIR, exist_ok=True)
CSV_PATH = os.path.join(DATA_DIR, "handicraft_pricing_data.csv")
MODEL_DIR = os.path.join(BASE_DIR, "services")
os.makedirs(MODEL_DIR, exist_ok=True)
MODEL_PATH = os.path.join(MODEL_DIR, "price_model.pkl")

# Realistic Indian handicraft pricing configurations
CRAFT_PROFILES = {
    "Pottery": {
        "cost_range": (30, 380),
        "markup_range": (3.2, 4.3),
        "regions": ["Uttar Pradesh", "Rajasthan", "West Bengal", "Delhi", "Tamil Nadu"],
        "heritage_bonus": 50
    },
    "Textiles": {
        "cost_range": (140, 1100),
        "markup_range": (2.4, 3.2),
        "regions": ["Rajasthan", "Gujarat", "Uttar Pradesh", "West Bengal", "Assam"],
        "heritage_bonus": 70
    },
    "Painting": {
        "cost_range": (70, 850),
        "markup_range": (3.8, 5.5),
        "regions": ["Bihar", "Odisha", "Maharashtra", "Madhya Pradesh", "Rajasthan"],
        "heritage_bonus": 120
    },
    "Metal Craft": {
        "cost_range": (250, 2100),
        "markup_range": (2.5, 3.5),
        "regions": ["Chhattisgarh", "Odisha", "Uttar Pradesh", "West Bengal", "Kerala"],
        "heritage_bonus": 100
    },
    "Wood Craft": {
        "cost_range": (110, 1300),
        "markup_range": (2.6, 3.4),
        "regions": ["Karnataka", "Uttar Pradesh", "Rajasthan", "Kerala", "Jammu and Kashmir"],
        "heritage_bonus": 80
    },
    "Jewellery": {
        "cost_range": (60, 1400),
        "markup_range": (3.0, 4.6),
        "regions": ["Rajasthan", "Odisha", "Gujarat", "West Bengal", "Delhi"],
        "heritage_bonus": 60
    },
    "Accessories": {
        "cost_range": (50, 650),
        "markup_range": (2.2, 3.1),
        "regions": ["Rajasthan", "Gujarat", "Uttar Pradesh", "Delhi"],
        "heritage_bonus": 40
    }
}

SIZE_MULTIPLIERS = {
    "small": 0.90,
    "medium": 1.30,
    "large": 2.10
}


def generate_synthetic_dataset(num_samples: int = 280) -> pd.DataFrame:
    """Generates synthetic Indian handicraft dataset with realistic pricing dynamics."""
    records = []
    categories = list(CRAFT_PROFILES.keys())

    for i in range(num_samples):
        cat = random.choice(categories)
        profile = CRAFT_PROFILES[cat]

        # Material cost in Rupees
        min_c, max_c = profile["cost_range"]
        material_cost = round(random.uniform(min_c, max_c), 1)

        # Size
        size = random.choice(["small", "medium", "large"])
        size_mult = SIZE_MULTIPLIERS[size]

        # Region
        region = random.choice(profile["regions"])

        # Base labor & craft markup
        min_m, max_m = profile["markup_range"]
        markup = random.uniform(min_m, max_m)

        # Baseline raw price
        raw_price = material_cost * markup * size_mult

        # Heritage bonus for recognized craft regions
        heritage_bonus = profile["heritage_bonus"] if region in ["Bihar", "Rajasthan", "Uttar Pradesh", "Chhattisgarh", "Odisha"] else 20

        # Market fluctuation noise (±7%)
        noise = random.gauss(0, raw_price * 0.05)

        final_price = raw_price + heritage_bonus + noise

        # Floor and round to realistic rupee value (nearest 10)
        final_price = max(material_cost * 1.3, final_price)
        final_price = round(final_price / 10.0) * 10.0

        records.append({
            "category": cat,
            "material_cost": material_cost,
            "size": size,
            "region": region,
            "price": int(final_price)
        })

    df = pd.DataFrame(records)
    return df


def train_and_export_model(df: pd.DataFrame):
    """Trains a regression pipeline on the handicraft dataset and exports price_model.pkl."""
    X = df[["category", "material_cost", "size", "region"]]
    y = df["price"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    cat_cols = ["category", "size", "region"]
    num_cols = ["material_cost"]

    preprocessor = ColumnTransformer(
        transformers=[
            ("num", StandardScaler(), num_cols),
            ("cat", OneHotEncoder(handle_unknown="ignore"), cat_cols)
        ]
    )

    pipeline = Pipeline(steps=[
        ("preprocessor", preprocessor),
        ("regressor", RandomForestRegressor(n_estimators=120, max_depth=12, random_state=42))
    ])

    pipeline.fit(X_train, y_train)

    # Evaluation
    preds = pipeline.predict(X_test)
    r2 = r2_score(y_test, preds)
    mae = mean_absolute_error(y_test, preds)

    print(f"Model Training Complete:")
    print(f" - Train Samples: {len(X_train)}")
    print(f" - Test Samples:  {len(X_test)}")
    print(f" - R² Score:      {r2:.4f}")
    print(f" - Mean Abs Error (MAE): ₹{mae:.2f}")

    joblib.dump(pipeline, MODEL_PATH)
    print(f"Exported model to: {MODEL_PATH}")

    return pipeline


if __name__ == "__main__":
    print("Generating synthetic Indian handicraft dataset...")
    df = generate_synthetic_dataset(num_samples=280)
    df.to_csv(CSV_PATH, index=False)
    print(f"Saved dataset ({len(df)} rows) to: {CSV_PATH}")
    print("\nSample Rows:")
    print(df.head())

    print("\nTraining Price Regression Model...")
    train_and_export_model(df)
