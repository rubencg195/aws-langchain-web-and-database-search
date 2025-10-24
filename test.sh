#!/bin/bash

# Test script for AWS LangChain Web and Database Search API
# Run this script after the Fargate service has stabilized

set +H  # Disable history expansion to avoid "!: event not found" errors

ALB_DNS=$(aws elb describe-load-balancers --region us-east-1 --query 'LoadBalancerDescriptions[?LoadBalancerName==`langchain-web-db-search-alb`].DNSName' --output text)

if [ -z "$ALB_DNS" ]; then
  echo "Error: Could not find ALB DNS name. Make sure the infrastructure is deployed."
  exit 1
fi

echo "Testing API endpoints for: $ALB_DNS"
echo ""

# Wait for service to stabilize
echo "Waiting 90 seconds for Fargate service to stabilize..."
sleep 90

# Test health endpoint
echo "=========================================="
echo "Testing /health endpoint..."
echo "=========================================="
curl -v -s http://"$ALB_DNS"/health
echo -e "\n"

# Test summarize endpoint with database search
echo "=========================================="
echo "Testing /summarize endpoint (database search)..."
echo "=========================================="
curl -v -s -X POST http://"$ALB_DNS"/summarize \
  -H "Content-Type: application/json" \
  -d '{"topic":"Canada"}' | jq '.'
echo -e "\n"

# Test summarize endpoint with web search (if SerpAPI key is configured)
echo "=========================================="
echo "Testing /summarize endpoint (web search)..."
echo "=========================================="
curl -v -s -X POST http://"$ALB_DNS"/summarize \
  -H "Content-Type: application/json" \
  -d '{"topic":"machine learning"}' | jq '.'
echo -e "\n"

echo "=========================================="
echo "Testing complete!"
echo "=========================================="
