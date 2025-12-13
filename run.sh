#!/bin/bash
set -e

# --- Configuration ---
TOOL_REPO_URL="git+https://github.com/bordumb/jnkn.git@dev-simplify0.0.1Launch"

echo "🔧 Configuring Golden Demo Repository..."

# --- 1. Git Prep (Moved to Top) ---
# We do this FIRST to ensure we are on the right branch before writing files
echo "💾 Preparing Git State..."

if [ ! -d ".git" ]; then
  git init
  git branch -M main
fi

# Force switch to main. 
# If it fails (branch doesn't exist), create it.
# -f ensures we switch even if you have local changes from a previous failed run.
git checkout -f main 2>/dev/null || git checkout -b main

# Clean directory to ensure V1 is pure
git clean -fd

# --- 2. Setup V1 (Safe State) ---
echo "📄 Writing baseline infrastructure (V1)..."
mkdir -p terraform src .github/workflows

# Add CODEOWNERS
cat > CODEOWNERS << 'EOF'
terraform/  @infra-team
src/        @backend-team
EOF

cat > terraform/main.tf << 'EOF'
resource "aws_db_instance" "payment_db" {
  identifier = "payment-db-prod"
  instance_class = "db.t3.micro"
  engine = "postgres"
  username = "dbadmin"
  password = var.db_password
}

# V1 OUTPUT (Safe)
output "payment_db_host" {
  value = aws_db_instance.payment_db.address
  description = "The endpoint for the payment database"
}
EOF

cat > src/app.py << 'EOF'
import os
# Expects payment_db_host from Terraform
DB_HOST = os.getenv("PAYMENT_DB_HOST")

def connect():
    if not DB_HOST:
        raise ValueError("Database host not configured!")
    print(f"Connecting to {DB_HOST}...")
EOF

# --- 3. Setup GitHub Workflow ---
echo "🤖 Configuring GitHub Actions..."
cat > .github/workflows/jnkn-analysis.yml <<EOF
name: Jnkn Gate
on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write 

jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Install Jnkn
        run: pip install "${TOOL_REPO_URL}"

      - name: Initialize
        run: jnkn init --force --no-telemetry

      - name: Run Jnkn Gate
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
        run: |
          jnkn action \\
            --token "\$GITHUB_TOKEN" \\
            --base "origin/\${{ github.base_ref }}" \\
            --head "HEAD" \\
            --fail-on critical
EOF

# --- 4. Commit V1 Baseline ---
echo "💾 Committing Safe State to 'main'..."
git add .
git commit -m "Reset: Safe Baseline (V1) with CODEOWNERS" --allow-empty

# --- 5. Create Feature Branch & Breaking Change ---
echo "🌿 Switching to feature branch 'feature/breaking-change'..."
# -B forces the branch to be reset to the current HEAD (V1)
git checkout -B feature/breaking-change

echo "💥 Introducing Breaking Change (V2)..."
cat > terraform/main.tf << 'EOF'
resource "aws_db_instance" "payment_db" {
  identifier = "payment-db-prod"
  instance_class = "db.t3.micro"
  engine = "postgres"
  username = "dbadmin"
  password = var.db_password
}

# BREAKING CHANGE: Renamed output. App will break because it expects 'payment_db_host'
output "payment_database_endpoint" {
  value = aws_db_instance.payment_db.address
  description = "The endpoint for the payment database"
}
EOF

git add terraform/main.tf
git commit -m "Refactor: Rename database output (Breaking)"

echo ""
echo "✅ Golden Demo Ready!"
echo "--------------------------------------------------------"
echo "To trigger the PR:"
echo "1. Create a new repo on GitHub"
echo "2. git remote add origin <your-new-repo-url>"
echo "3. git push -u origin main --force"
echo "4. git push -u origin feature/breaking-change --force"
echo "5. Open a Pull Request from 'feature/breaking-change' to 'main'"
echo ""
echo "🎉 SUCCESS CRITERIA:"
echo "   - The GitHub Action should run."
echo "   - It should POST a comment analyzing the impact."
echo "   - It should FAIL the build (preventing the merge) because"
echo "     we intentionally broke the Terraform output."
echo "--------------------------------------------------------"
