#!/usr/bin/env python3
"""
Bedrock Integration Test Script
Tests the Bedrock Claude Haiku 4.5 model with inference profile
Run this locally before deploying to Fargate
"""

import json
import boto3
import sys
from tenacity import retry, wait_exponential, stop_after_attempt, retry_if_exception_type

# Configuration
AWS_REGION = "us-east-1"
BEDROCK_MODEL_ID = "arn:aws:bedrock:us-east-1:176843580427:application-inference-profile/4ok0qdr5zqg8"  # Inference profile ARN for Haiku 4.5

# Initialize Bedrock client
bedrock_client = boto3.client('bedrock-runtime', region_name=AWS_REGION)

@retry(wait=wait_exponential(min=1, max=10), stop=stop_after_attempt(3), retry=retry_if_exception_type(Exception))
def call_bedrock(prompt: str) -> str:
    """Test Bedrock invocation"""
    try:
        print(f'\n>>> BEDROCK CALL START')
        print(f'>>> Model ID (Inference Profile ARN): {BEDROCK_MODEL_ID}')
        print(f'>>> Region: {AWS_REGION}')
        print(f'>>> Prompt length: {len(prompt)} chars')
        
        # Build request body with or without anthropic_version
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 512,
            "messages": [
                {
                    "role": "user",
                    "content": [{"type": "text", "text": prompt}]
                }
            ]
        }
        
        # Remove the old code that added anthropic_version conditionally
        print(f'>>> Request body keys: {list(request_body.keys())}')
        print(f'>>> Request body: {json.dumps(request_body, indent=2)[:200]}...')
        
        response = bedrock_client.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            contentType='application/json',
            accept='application/json',
            body=json.dumps(request_body)
        )
        
        print(f'>>> Response received, status code: {response.get("ResponseMetadata", {}).get("HTTPStatusCode", "unknown")}')
        
        response_body = json.loads(response['body'].read())
        print(f'>>> Response body keys: {list(response_body.keys())}')
        
        if 'content' in response_body:
            result = response_body['content'][0].get('text', 'No text in response')
            print(f'>>> SUCCESS: Got {len(result)} chars from Bedrock')
            return result
        else:
            print(f'>>> ERROR: No content key in response')
            return str(response_body)
            
    except Exception as e:
        print(f'\n>>> BEDROCK ERROR OCCURRED')
        print(f'>>> Exception Type: {type(e).__name__}')
        print(f'>>> Exception Message: {str(e)}')
        
        # Extract the real error if it's wrapped in RetryError
        error_msg = str(e)
        try:
            if hasattr(e, 'last_attempt'):
                attempt = e.last_attempt
                if hasattr(attempt, 'exception'):
                    exc_method = attempt.exception
                    if callable(exc_method):
                        inner_exc = exc_method()
                        error_msg = f'{type(inner_exc).__name__}: {str(inner_exc)}'
                        print(f'>>> Extracted inner error: {error_msg}')
        except Exception as extract_err:
            print(f'>>> Failed to extract inner error: {extract_err}')
        
        return f'BEDROCK_ERROR: {error_msg}'


def test_basic_prompt():
    """Test with a basic prompt"""
    print("\n" + "="*60)
    print("TEST 1: Basic Prompt")
    print("="*60)
    prompt = "Hello! What is 2+2?"
    result = call_bedrock(prompt)
    print(f"\nResult:\n{result}\n")
    return "BEDROCK_ERROR" not in str(result)


def test_summarization_prompt():
    """Test with a summarization prompt like the app uses"""
    print("\n" + "="*60)
    print("TEST 2: Summarization Prompt (like the app)")
    print("="*60)
    context = """
    Canada is a North American country with 10 provinces and 3 territories.
    It is the second-largest country by land area. The capital is Ottawa.
    Canada is known for Niagara Falls, Rocky Mountains, and the Great Lakes.
    The population is approximately 40 million people.
    Official languages are English and French.
    """
    prompt = f"Topic: Canada\n\nContext:\n{context}\n\nProvide a concise summary (2-3 sentences)."
    result = call_bedrock(prompt)
    print(f"\nResult:\n{result}\n")
    return "BEDROCK_ERROR" not in str(result)


def test_error_handling():
    """Test error handling with an invalid prompt"""
    print("\n" + "="*60)
    print("TEST 3: Empty Prompt (Error Handling)")
    print("="*60)
    prompt = ""  # Empty prompt should cause an error
    result = call_bedrock(prompt)
    print(f"\nResult:\n{result}\n")
    # This test passes if we got an error (as expected)
    return "BEDROCK_ERROR" in str(result)


def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("AWS Bedrock Integration Test Suite")
    print("="*60)
    print(f"Model ID: {BEDROCK_MODEL_ID}")
    print(f"Region: {AWS_REGION}")
    
    tests = [
        ("Basic Prompt", test_basic_prompt),
        ("Summarization Prompt", test_summarization_prompt),
        ("Error Handling", test_error_handling),
    ]
    
    results = {}
    for test_name, test_func in tests:
        try:
            passed = test_func()
            results[test_name] = "PASSED" if passed else "FAILED"
        except Exception as e:
            print(f"\nTEST FAILED WITH EXCEPTION: {type(e).__name__}: {str(e)}")
            results[test_name] = f"FAILED: {str(e)}"
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    for test_name, result in results.items():
        print(f"{test_name}: {result}")
    
    passed_count = sum(1 for r in results.values() if "PASSED" in r)
    total_count = len(results)
    print(f"\nTotal: {passed_count}/{total_count} tests passed")
    
    if passed_count == total_count:
        print("\n[SUCCESS] All tests passed! Ready to deploy to Fargate.")
        sys.exit(0)
    else:
        print("\n[FAILED] Some tests failed. Fix issues before deploying to Fargate.")
        sys.exit(1)


if __name__ == "__main__":
    main()
