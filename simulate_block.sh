#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           JUNKAN VERTICAL SPIKE: LOCAL SIMULATION            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Simulate a breaking change
# We create a temporary "modified" version of the Terraform file
echo -e "${BLUE}Step 1: Simulating a breaking Terraform change...${NC}"
cp infra/rds.tf infra/rds.tf.bak

# Destructive change: Rename the resource identifier
# This breaks the fuzzy match 'payments-production-db' <-> 'PAYMENTS_DB_HOST'
sed -i.tmp 's/payments-production-db/new-payments-db-v2/g' infra/rds.tf

echo -e "${RED}  -> Changed aws_db_instance identifier to 'new-payments-db-v2'${NC}"
echo -e "${RED}  -> This breaks the implicit link to app/payment_service.py${NC}"
echo ""

# 2. Generate a fake diff file to feed Junkan
# (Since we aren't in a real git PR, we feed the file list explicitly)
echo "infra/rds.tf" > changed_files.txt

# 3. Run Junkan Check
echo -e "${BLUE}Step 2: Running Junkan Impact Gate...${NC}"
echo "   Loading Lineage: data/production_lineage.json"
echo "   Loading Policy:  policy.yaml"
echo ""

set +e # Allow failure for demonstration

# Note: We assume 'junkan' is installed in the path. 
# If running from source, replace with `uv run python -m junkan.cli.main`
junkan check \
  --diff changed_files.txt \
  --policy policy.yaml \
  --openlineage-file data/production_lineage.json \
  --fail-if-critical

EXIT_CODE=$?

# 4. Restore state
mv infra/rds.tf.bak infra/rds.tf
rm infra/rds.tf.tmp changed_files.txt 2>/dev/null

echo ""
echo -e "${BLUE}Step 3: Evaluating Result...${NC}"

if [ $EXIT_CODE -eq 1 ]; then
    echo -e "${GREEN}✅ SUCCESS: Junkan correctly BLOCKED the change (Exit Code 1).${NC}"
    echo -e "   It detected the infra change impacts the Executive Dashboard."
else
    echo -e "${RED}❌ FAILURE: Junkan failed to block the change (Exit Code $EXIT_CODE).${NC}"
fi