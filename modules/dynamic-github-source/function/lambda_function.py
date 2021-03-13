import json
import logging
import boto3
from github import Github
import os
import re
import collections.abc

log = logging.getLogger(__name__)
ssm = boto3.client('ssm')
cb = boto3.client('codebuild')
def lambda_handler(event, context):
    print('event')
    print(event)
    print()
    print('context')
    print(context)

    valid = validate_payload(event, filter_groups)

    if not valid:
        return {
            'statusCode': 403,
            'body': json.dumps(f'Payload does not fulfill trigger requirments: ${trigger_groups}')
        }

    try:
        start_build(cp_name, updated_source)
    except Exception:
        log.error(f'unable to start target build: {build_name}')
        return {
            "statusCode": 500,
            "body": json.dumps({'error': f'unable to update target build: ${pipeline_name}'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps('Request was successful')
    }

def validate_payload(payload, filter_groups):
    if payload['event'] == "pull_request":
        valid = validate_pr(payload, filter_groups)
    elif payload['event'] == "push":
        valid = validate_push(payload, filter_groups)
    return valid

def validate_push(payload, filter_groups):
    clone_url = payload['repository']['clone_url']
    base_sha = payload['before']
    head_sha = payload['after']
    ref = payload['ref']

    github_token = ssm.get_parameter(Name=os.environ['GITHUB_TOKEN_SSM_KEY'], WithDecryption=True)['Parameter']['Value']
    gh = Github(github_token)

    repo = gh.get_repo(repo_full_name)

    valid = False
    for group in filter_groups:
        valid = False
        for f in group:
            if f['type'] == 'file_path':
                diff_paths = [path.filename for path in repo.compare(base_sha, head_sha)]
                for path in diff_paths:
                    if re.search(path_filter, path):
                        valid = True
                        break
            elif f['type'] == 'commit_message':
                valid = re.search(f['pattern'], payload['hook']['last_response']['message'])
            elif f['type'] == 'base_ref':
                valid = re.search(f['pattern'], ref)
            elif f['type'] == 'actor_account_id'
                valid = re.search(f['pattern'], payload['sender']['id'])
            elif f['type'] == 'event'
                if payload['event'] in split(f['pattern'], ',')
                    valid = True
            else:
                log.error(f'invalid filter type: {group[k]}')
            if not valid:
                break
        if valid:
            return True

def validate_filter_groups(filter_groups):
    # TODO: create if https://github.com/hashicorp/terraform/pull/25088 is not merged in near future
    # PR will allow terraform level assertions for filter_groups
    pass

def validate_pr(payload, filter_groups):
    clone_url = payload['pull_request']['base']['repo']['clone_url']
    base_sha = payload['pull_request']['base']['sha']
    head_sha = payload['pull_request']['head']['sha']

    github_token = ssm.get_parameter(Name=os.environ['GITHUB_TOKEN_SSM_KEY'], WithDecryption=True)['Parameter']['Value']
    gh = Github(github_token)

    repo = gh.get_repo(repo_full_name)

    valid = False
    for group in filter_groups:
        valid = False
        for f in group:
            if f['type'] == 'file_path':
                diff_paths = [path.filename for path in repo.compare(base_sha, head_sha)]
                for path in diff_paths:
                    if re.search(path_filter, path):
                        valid = True
                        break
            elif f['type'] == 'commit_message':
                valid = re.search(f['pattern'], payload['hook']['last_response']['message'])
            elif f['type'] == 'base_ref':
                valid = re.search(f['pattern'], payload['pull_request']['base']['ref'])
            elif f['type'] == 'head_ref':
                valid = re.search(f['pattern'], payload['pull_request']['head']['ref'])
            elif f['type'] == 'actor_account_id'
                valid = re.search(f['pattern'], payload['sender']['id'])
            elif f['type'] == 'event'
                if payload['event'] in split(f['pattern'], ',')
                    valid = True
            else:
                log.error(f'invalid filter type: {group[k]}')
            if not valid:
                break
        if valid:
            return True

def get_user_params(job_data):
    try:
        user_parameters = job_data['actionConfiguration']['configuration']['UserParameters']
        decoded_parameters = json.loads(user_parameters)
    except Exception as e:
        log.error("UserParameters could not be decoded from JSON configuration")
    return decoded_parameters