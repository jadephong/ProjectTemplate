#!/bin/bash
set -e

# Project Template Initialization Script
# Usage: ./scripts/init.sh

echo "🚀 Initializing project template..."

# Load config
if [ ! -f "project.config.yaml" ]; then
  echo "❌ project.config.yaml not found. Please copy and fill project.config.yaml first."
  exit 1
fi

# Parse project.config.yaml using simple grep (or use yq if available)
PROJECT_SLUG=$(grep -E "^project_slug:" project.config.yaml | cut -d':' -f2 | xargs)
GITHUB_REPO_URL=$(grep -E "^github_repo_url:" project.config.yaml | cut -d':' -f2- | xargs)
JIRA_PROJECT_KEY=$(grep -E "^jira_project_key:" project.config.yaml | cut -d':' -f2 | xargs)

# Load secrets from .env
if [ -f ".env" ]; then
  export $(cat .env | xargs)
fi

# Prompt for missing secrets
if [ -z "$SONARQUBE_TOKEN" ]; then
  read -sp "Enter SonarQube token: " SONARQUBE_TOKEN
  echo
fi

if [ -z "$SNYK_TOKEN" ]; then
  read -sp "Enter Snyk token: " SNYK_TOKEN
  echo
fi

# Inject GitHub secrets
echo "📝 Injecting GitHub secrets..."
gh secret set SONARQUBE_TOKEN --body "$SONARQUBE_TOKEN" || true
gh secret set SNYK_TOKEN --body "$SNYK_TOKEN" || true

# Set up branch protection
echo "🛡️  Setting up branch protection..."
REPO_OWNER=$(echo "$GITHUB_REPO_URL" | cut -d'/' -f4)
REPO_NAME=$(echo "$GITHUB_REPO_URL" | cut -d'/' -f5 | sed 's/.git$//')

gh api repos/"$REPO_OWNER"/"$REPO_NAME"/branches/main/protection \
  -X PUT \
  -f required_status_checks='{"strict":true,"contexts":["build","SonarCloud Code Analysis","snyk/snyk-high-priority"]}' \
  -f enforce_admins=true \
  -f dismiss_stale_reviews=false \
  -f require_code_reviews=true \
  -f required_approving_review_count=1 \
  -f restrict_who_can_push='null' \
  || echo "⚠️  Branch protection may already exist or requires additional setup"

# Create initial directories
echo "📁 Creating folder structure..."
mkdir -p src/{components,utils,lib}
mkdir -p .claude/settings
mkdir -p docs/{product-direction,retro,sprint}
mkdir -p agents
mkdir -p skills
mkdir -p .github/workflows

echo "✅ Initialization complete!"
echo ""
echo "Next steps:"
echo "1. Review .github/workflows/ for GitHub Actions configuration"
echo "2. Fill docs/product-direction/VISION.md"
echo "3. Plan your first sprint in docs/sprint/SPRINT-1.md"
echo "4. Run: git add . && git commit -m 'chore: initialize project template'"
