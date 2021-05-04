import json
import logging
import boto3
from github import Github
import os
import re
import ast
import collections.abc
import inspect

log = logging.getLogger(__name__)
ssm = boto3.client('ssm')
cb = boto3.client('codebuild')
def lambda_handler(event, context):
    payload_body = json.loads(event['requestPayload']['body'])
    try:
        valid = validate_payload(
            payload_body,
            event['requestPayload']['headers']['X-GitHub-Event']
        )
    except Exception as e:
        raise LambdaException(json.dumps(
            {
                "type": e.__class__.__name__,
                "message": str(e)
            }
        ))

    print('Starting CodeBuild project: ', os.environ['CODEBUILD_NAME'])
    try:
        response = cb.start_build(
            projectName = os.environ['CODEBUILD_NAME'],
            sourceLocationOverride = payload_body['repository']['html_url'],
            sourceTypeOverride = 'GITHUB'
        )
    except Exception as e:
        raise LambdaException(json.dumps(
            {
                "type": e.__class__.__name__,
                "message": str(e)
            }
        ))

    return {"message": "Request was successful"}

def validate_payload(payload, event):
    github_token = ssm.get_parameter(Name=os.environ['GITHUB_TOKEN_SSM_KEY'], WithDecryption=True)['Parameter']['Value']
    gh = Github(github_token)
    repo = gh.get_repo(payload['repository']['full_name'])
    
    with open('/opt/filter_groups.json') as f:
      #get filter groups associated with target repository
      filter_groups = json.load(f)[payload['repository']['name']]
      
    if event == "pull_request":
        valid = validate_pr(payload, event, filter_groups, repo)
    elif event == "push":
        valid = validate_push(payload, event, filter_groups, repo)
    
    if valid:
        print('Payload fulfills atleast one filter group')
        return valid
    else:
        print('Payload does not fulfill any of the filter groups requirements')
        raise ClientException(
            {
                'message': 'Payload does not fulfill trigger requirements. Skipping Codebuild testing.'
            }
        )

def validate_filter_groups(filter_groups):
    # TODO: create if https://github.com/hashicorp/terraform/pull/25088 is not merged in near future
    # PR will allow terraform level assertions for filter_groups
    pass

def validate_push(payload, event, filter_groups, repo):

    for group in filter_groups:
        for f in group:
            valid = False
            filter_type = f['type']
            if filter_type == 'file_path':
                #gets filenames of files that changed from base commit
                diff_paths = [path.filename for path in repo.compare(payload['before'], payload['after']).files]
                for filename in diff_paths:
                    if re.search(f['pattern'], filename):
                        valid = True
                        break
            elif filter_type == 'commit_message':
                valid = re.search(f['pattern'], payload['hook']['last_response']['message'])
            elif filter_type == 'base_ref':
                valid = re.search(f['pattern'], payload['ref'])
            elif filter_type == 'actor_account_id':
                valid = re.search(f['pattern'], payload['sender']['id'])
            elif filter_type == 'event':
                if event in f['pattern'].split(','):
                    valid = True
            else:
                raise ServerException(f'invalid filter type: {filter_type}')
            #stops checking the rest of filters within group
            if not valid:
                break
    return valid

def validate_pr(payload, event, filter_groups, repo):
    
    for group in filter_groups:
        for f in group:
            valid = False
            filter_type = f['type']
            if filter_type == 'file_path':
                diff_paths = [path.filename for path in repo.compare(
                    payload['pull_request']['base']['sha'], 
                    payload['pull_request']['head']['sha']
                )]
                for path in diff_paths:
                    if re.search(f['pattern'], path):
                        valid = True
                        break
            elif filter_type == 'commit_message':
                valid = re.search(f['pattern'], payload['hook']['last_response']['message'])
            elif filter_type == 'base_ref':
                valid = re.search(f['pattern'], payload['pull_request']['base']['ref'])
            elif filter_type == 'head_ref':
                valid = re.search(f['pattern'], payload['pull_request']['head']['ref'])
            elif filter_type == 'actor_account_id':
                valid = re.search(f['pattern'], payload['sender']['id'])
            elif filter_type == 'event':
                if event in f['pattern'].split(','):
                    valid = True
            else:
                raise ServerException(f'invalid filter type: {filter_type}')
            #stops checking the rest of filters within group
            if not valid:
                break
    return valid

class LambdaException(Exception):
    pass

class ClientException(Exception):
    pass

class ServerException(Exception):
    pass
